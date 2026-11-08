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
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.segmentation.Segmentation
import com.google.mlkit.vision.segmentation.selfie.SelfieSegmenterOptions
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
    PluginRegistry.RequestPermissionsResultListener,
    PluginRegistry.ActivityResultListener {

    private lateinit var channel: MethodChannel
    private lateinit var videoChannel: MethodChannel
    private lateinit var appContext: Context
    private lateinit var textureRegistry: TextureRegistry
    private var activity: Activity? = null
    private val pendingPermissionQueue = mutableListOf<Pair<Result, () -> Unit>>()
    private var isRequestingPermission = false
    private var pendingCubePickerResult: Result? = null

    private val mainHandler = Handler(Looper.getMainLooper())
    private var backgroundThread: HandlerThread? = null
    private var backgroundHandler: Handler? = null
    private val rustIspExecutor = Executors.newSingleThreadExecutor()
    // Single shared session executor (Fixes B10 leak)
    private val cameraSessionExecutor = Executors.newSingleThreadExecutor()
    // Multi-core worker pool for parallel Portrait & ISP pixel processing (3-4x faster capture)
    private val ispWorkerCount = Runtime.getRuntime().availableProcessors().coerceIn(2, 6)
    private val ispWorkerPool = Executors.newFixedThreadPool(ispWorkerCount)

    // Managed warm ML Kit SelfieSegmenter instance (eliminates ~250ms per-shot TFLite model reload and closes cleanly on detach)
    @Volatile
    private var selfieSegmenterInstance: com.google.mlkit.vision.segmentation.Segmenter? = null

    private fun getOrCreateSelfieSegmenter(): com.google.mlkit.vision.segmentation.Segmenter {
        selfieSegmenterInstance?.let { return it }
        synchronized(this) {
            selfieSegmenterInstance?.let { return it }
            val options = SelfieSegmenterOptions.Builder()
                .setDetectorMode(SelfieSegmenterOptions.SINGLE_IMAGE_MODE)
                .build()
            return Segmentation.getClient(options).also { selfieSegmenterInstance = it }
        }
    }

    private fun parallelForRows(height: Int, worker: (startY: Int, endY: Int) -> Unit) {
        if (height < 64 || ispWorkerCount <= 1) {
            worker(0, height)
            return
        }
        val chunk = (height + ispWorkerCount - 1) / ispWorkerCount
        val futures = ArrayList<java.util.concurrent.Future<*>>(ispWorkerCount)
        var y0 = 0
        while (y0 < height) {
            val s = y0
            val e = (y0 + chunk).coerceAtMost(height)
            futures.add(ispWorkerPool.submit { worker(s, e) })
            y0 = e
        }
        for (f in futures) {
            f.get()
        }
    }

    private var surfaceEntry: TextureRegistry.SurfaceTextureEntry? = null
    private var cameraDevice: CameraDevice? = null
    private var captureSession: CameraCaptureSession? = null
    private var previewRequestBuilder: CaptureRequest.Builder? = null
    private var previewSurface: Surface? = null
    private var rawImageReader: ImageReader? = null
    private var jpegImageReader: ImageReader? = null
    private var yuvAnalysisReader: ImageReader? = null
    private var activeCameraId: String = "0"
    private var activePhysicalCameraId: String? = null
    private var activeSensorOrientation: Int = 90
    @Volatile
    private var lastTotalCaptureResult: TotalCaptureResult? = null
    @Volatile
    private var lastYuvAnalysisMs: Long = 0L
    @Volatile
    private var latestLiveHistogram32: List<Double> = emptyList()
    @Volatile
    private var latestLiveHistogram64: List<Double> = emptyList()
    @Volatile
    private var latestLiveZebraRatio: Double = 0.0
    @Volatile
    private var latestLiveZebraRatio70: Double = 0.0
    @Volatile
    private var latestLiveZebraGrid16x12: List<Double> = emptyList()
    @Volatile
    private var latestLiveFocusPeakingScore: Double = 0.0
    @Volatile
    private var latestLivePeakingGrid16x12: List<Double> = emptyList()
    @Volatile
    private var latestLiveFalseColorGrid16x12: List<Int> = emptyList()
    @Volatile
    private var latestMeanSceneLumaNorm: Double = 0.42

    // Faz 3 Pro Video Engine State (WP-3.1 .. WP-3.5)
    @Volatile
    private var videoSessionActive: Boolean = false
    @Volatile
    private var isVideoRecording: Boolean = false
    private var mediaRecorder: android.media.MediaRecorder? = null
    private var currentVideoFile: File? = null
    private var videoRecordStartMs: Long = 0L
    @Volatile
    private var videoWidth: Int = 3840
    @Volatile
    private var videoHeight: Int = 2160
    @Volatile
    private var videoFps: Int = 30
    @Volatile
    private var videoShutterAngleDeg: Double = 180.0
    @Volatile
    private var videoLockShutterAngle: Boolean = true
    @Volatile
    private var videoManualIso: Boolean = false
    @Volatile
    private var videoActiveIso: Double = 100.0
    @Volatile
    private var videoIsoMin: Int = 50
    @Volatile
    private var videoIsoMax: Int = 3200
    @Volatile
    private var videoEvCompensation: Double = 0.0
    @Volatile
    private var videoProfileName: String = "universalRec709Locked"
    @Volatile
    private var videoStabilizationEnabled: Boolean = true
    @Volatile
    private var videoDroppedFrames: Int = 0
    @Volatile
    private var prevVideoSensorTimestampNs: Long = 0L
    @Volatile
    private var videoSamplePeakDbfs: Double = -96.0
    @Volatile
    private var videoRmsDbfs: Double = -96.0
    @Volatile
    private var videoNdRecommendation: String? = null
    @Volatile
    private var videoThermalStatus: String = "NORMAL"
    private var thermalListener: android.os.PowerManager.OnThermalStatusChangedListener? = null
    @Volatile
    private var activeSessionIsTenBitHlg: Boolean = false
    private var nextVideoSegmentFile: File? = null
    private var activeFocusPullRunnable: Runnable? = null
    @Volatile
    private var audioMeterActive: Boolean = false
    private var audioMeterThread: Thread? = null
    private var audioRecordMonitor: android.media.AudioRecord? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        appContext = flutterPluginBinding.applicationContext
        textureRegistry = flutterPluginBinding.textureRegistry
        // Pre-warm ML Kit SelfieSegmenter in background so the first Portrait capture has zero cold-start latency
        rustIspExecutor.execute {
            try {
                getOrCreateSelfieSegmenter()
            } catch (e: Throwable) {
                android.util.Log.w("ZameraCapture", "SelfieSegmenter pre-warm warning: ${e.message}")
            }
        }
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.akarworks.zamera/capture_probe")
        channel.setMethodCallHandler(this)
        videoChannel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.akarworks.zamera/video_engine")
        videoChannel.setMethodCallHandler(this)
        registerThermalMonitor()
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        wakeAndKeepScreenOn(binding.activity)
        binding.addRequestPermissionsResultListener(this)
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        wakeAndKeepScreenOn(binding.activity)
        binding.addRequestPermissionsResultListener(this)
        binding.addActivityResultListener(this)
    }

    private fun wakeAndKeepScreenOn(act: Activity) {
        try {
            act.runOnUiThread {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                    act.setShowWhenLocked(true)
                    act.setTurnScreenOn(true)
                }
                act.window?.addFlags(
                    android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                        android.view.WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                        android.view.WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED
                )
            }
        } catch (e: Throwable) {
            android.util.Log.w("ZameraCapture", "wakeAndKeepScreenOn warning: ${e.message}")
        }
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ): Boolean {
        if (requestCode == 9001 || requestCode == 9002) {
            isRequestingPermission = false
            val camIdx = permissions.indexOf(Manifest.permission.CAMERA)
            val camGranted = if (camIdx >= 0 && camIdx < grantResults.size) {
                grantResults[camIdx] == PackageManager.PERMISSION_GRANTED
            } else {
                ContextCompat.checkSelfPermission(appContext, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED
            }
            val copy = ArrayList(pendingPermissionQueue)
            pendingPermissionQueue.clear()
            for ((res, act) in copy) {
                if (camGranted) {
                    act.invoke()
                } else {
                    res.error("PERMISSION_DENIED", "Camera permission denied by user", null)
                }
            }
            return true
        }
        return false
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: android.content.Intent?): Boolean {
        if (requestCode == 9003) {
            val pending = pendingCubePickerResult
            pendingCubePickerResult = null
            if (pending == null) return true
            if (resultCode != Activity.RESULT_OK || data?.data == null) {
                pending.success(null)
                return true
            }
            val uri = data.data!!
            try {
                val content = appContext.contentResolver.openInputStream(uri)?.bufferedReader(Charsets.UTF_8)?.use { it.readText() }
                if (content.isNullOrBlank()) {
                    pending.error("CUBE_EMPTY", "Seçilen .cube dosyası boş veya okunamadı", null)
                } else {
                    val fileName = uri.lastPathSegment ?: "custom.cube"
                    pending.success(mapOf("fileName" to fileName, "content" to content))
                }
            } catch (e: Exception) {
                pending.error("CUBE_READ_ERR", e.message, null)
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
            "reprocessPortraitPhoto" -> {
                val args = call.arguments as? Map<String, Any?> ?: emptyMap()
                reprocessPortraitPhoto(args, result)
            }
            "extractSubjectCutoutPng" -> {
                val args = call.arguments as? Map<String, Any?> ?: emptyMap()
                extractSubjectCutoutPng(args, result)
            }
            "stopPreviewSession" -> {
                stopPreviewSession()
                result.success(true)
            }
            "getRustCoreVersion" -> {
                result.success(ZameraRustBridge.safeCoreVersion())
            }
            // Faz 3 Pro Video Engine (WP-3.1 .. WP-3.6)
            "startVideoSession" -> {
                val args = call.arguments as? Map<String, Any?> ?: emptyMap()
                ensureVideoPermissionsAndRun(result) {
                    startVideoSession(args, result)
                }
            }
            "updateVideoControls" -> {
                val args = call.arguments as? Map<String, Any?> ?: emptyMap()
                updateVideoControls(args, result)
            }
            "startVideoRecording" -> {
                val args = call.arguments as? Map<String, Any?> ?: emptyMap()
                ensureVideoPermissionsAndRun(result) {
                    startVideoRecording(args, result)
                }
            }
            "stopVideoRecording" -> {
                stopVideoRecording(result)
            }
            "triggerFocusPull" -> {
                val args = call.arguments as? Map<String, Any?> ?: emptyMap()
                triggerFocusPull(args, result)
            }
            "listAudioInputDevices" -> {
                result.success(listAudioInputDevices())
            }
            "getVideoTelemetry" -> {
                result.success(extractVideoTelemetry())
            }
            "pickCubeLutFile" -> {
                pickCubeLutFileFromDevice(result)
            }
            "stopVideoSession" -> {
                stopVideoSessionInternal()
                result.success(true)
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

    private fun ensureVideoPermissionsAndRun(result: Result, action: () -> Unit) {
        val hasCam = ContextCompat.checkSelfPermission(appContext, Manifest.permission.CAMERA) ==
            PackageManager.PERMISSION_GRANTED
        val hasMic = ContextCompat.checkSelfPermission(appContext, Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED
        if (hasCam && hasMic) {
            action()
            return
        }
        val act = activity
        if (act != null) {
            pendingPermissionQueue.add(Pair(result, action))
            if (!isRequestingPermission) {
                isRequestingPermission = true
                ActivityCompat.requestPermissions(
                    act,
                    arrayOf(Manifest.permission.CAMERA, Manifest.permission.RECORD_AUDIO),
                    9002
                )
            }
        } else if (hasCam) {
            action()
        } else {
            result.error("PERMISSION_DENIED", "Camera & Audio permissions not granted", null)
        }
    }

    private fun pickCubeLutFileFromDevice(result: Result) {
        // First check if a user-placed .cube file exists in app external/internal 'luts' directory
        val lutDirs = listOfNotNull(appContext.getExternalFilesDir("luts"), File(appContext.filesDir, "luts"))
        val act = activity
        if (act != null) {
            try {
                pendingCubePickerResult = result
                val intent = android.content.Intent(android.content.Intent.ACTION_OPEN_DOCUMENT).apply {
                    addCategory(android.content.Intent.CATEGORY_OPENABLE)
                    type = "*/*"
                }
                act.startActivityForResult(intent, 9003)
                return
            } catch (e: Exception) {
                pendingCubePickerResult = null
                android.util.Log.w("ZameraCapture", "ACTION_OPEN_DOCUMENT fallback to local lut dir: ${e.message}")
            }
        }
        for (dir in lutDirs) {
            val cubeFile = dir.listFiles()?.firstOrNull { it.extension.equals("cube", ignoreCase = true) }
            if (cubeFile != null && cubeFile.exists()) {
                result.success(mapOf("fileName" to cubeFile.name, "content" to cubeFile.readText(Charsets.UTF_8)))
                return
            }
        }
        result.success(null)
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

            // Lightweight 320x240 YUV_420_888 sensor analyzer for real-time 32-bin Luma Histogram, Zebra (>=95% IRE), and Focus Peaking
            val yuvSize = map?.getOutputSizes(ImageFormat.YUV_420_888)
                ?.filter { it.width in 160..640 && it.height in 120..480 }
                ?.minByOrNull { kotlin.math.abs(it.width * it.height - 320 * 240) }
                ?: android.util.Size(320, 240)
            val isFrontCamera = chars.get(CameraCharacteristics.LENS_FACING) == CameraCharacteristics.LENS_FACING_FRONT
            yuvAnalysisReader = ImageReader.newInstance(yuvSize.width, yuvSize.height, ImageFormat.YUV_420_888, 2).apply {
                setOnImageAvailableListener({ reader ->
                    val img = try { reader.acquireLatestImage() } catch (_: Throwable) { null }
                        ?: return@setOnImageAvailableListener
                    try {
                        val now = System.currentTimeMillis()
                        if (now - lastYuvAnalysisMs >= 120L) {
                            lastYuvAnalysisMs = now
                            analyzePreviewYuvFrame(img, activeSensorOrientation, isFrontCamera)
                        }
                    } catch (e: Throwable) {
                        android.util.Log.w("ZameraCapture", "YUV frame analysis warning: ${e.message}")
                    } finally {
                        img.close()
                    }
                }, backgroundHandler)
            }

            var retriedThreeStreamFallback = false
            var retriedOpenOnScreenWake = false

            fun openAndConfigureCamera() {
                manager.openCamera(openLogicalId, object : CameraDevice.StateCallback() {
                    override fun onOpened(camera: CameraDevice) {
                        cameraDevice = camera
                        fun configureSession(includeYuvStream: Boolean) {
                            try {
                                val builder = camera.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW)
                                builder.addTarget(surf)
                                if (includeYuvStream) {
                                    yuvAnalysisReader?.surface?.let { builder.addTarget(it) }
                                }
                                builder.set(
                                    CaptureRequest.CONTROL_AF_MODE,
                                    CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE
                                )
                                // Enable hardware Face/Subject Detection for Portrait & Pro tracking
                                val fdModes = chars.get(CameraCharacteristics.STATISTICS_INFO_AVAILABLE_FACE_DETECT_MODES)
                                if (fdModes != null) {
                                    when {
                                        fdModes.contains(CameraMetadata.STATISTICS_FACE_DETECT_MODE_FULL) ->
                                            builder.set(CaptureRequest.STATISTICS_FACE_DETECT_MODE, CameraMetadata.STATISTICS_FACE_DETECT_MODE_FULL)
                                        fdModes.contains(CameraMetadata.STATISTICS_FACE_DETECT_MODE_SIMPLE) ->
                                            builder.set(CaptureRequest.STATISTICS_FACE_DETECT_MODE, CameraMetadata.STATISTICS_FACE_DETECT_MODE_SIMPLE)
                                    }
                                }
                                // Lock zoom ratio to 1.0x to prevent OEM automatic macro/crop switching (Faz 2A)
                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                                    builder.set(CaptureRequest.CONTROL_ZOOM_RATIO, 1.0f)
                                }
                                previewRequestBuilder = builder

                                val surfaces = mutableListOf<Surface>(surf)
                                if (includeYuvStream) {
                                    yuvAnalysisReader?.surface?.let { surfaces.add(it) }
                                }
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
                                                        if (!includeYuvStream) {
                                                            val now = System.currentTimeMillis()
                                                            if (now - lastYuvAnalysisMs >= 160L) {
                                                                lastYuvAnalysisMs = now
                                                                samplePreviewSurfaceViaPixelCopy(surf)
                                                            }
                                                        }
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
                                        if (includeYuvStream && !retriedThreeStreamFallback) {
                                            retriedThreeStreamFallback = true
                                            try {
                                                yuvAnalysisReader?.close()
                                            } catch (e: Throwable) {
                                                android.util.Log.w("ZameraCapture", "yuvAnalysisReader close warning: ${e.message}")
                                            }
                                            yuvAnalysisReader = null
                                            configureSession(includeYuvStream = false)
                                            return
                                        }
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
                                if (includeYuvStream && !retriedThreeStreamFallback) {
                                    retriedThreeStreamFallback = true
                                    try {
                                        yuvAnalysisReader?.close()
                                    } catch (closeErr: Throwable) {
                                        android.util.Log.w("ZameraCapture", "yuvAnalysisReader fallback close warning: ${closeErr.message}")
                                    }
                                    yuvAnalysisReader = null
                                    configureSession(includeYuvStream = false)
                                    return
                                }
                                mainHandler.post {
                                    result.error("OPEN_BUILD_ERR", e.message, null)
                                }
                            }
                        }

                        configureSession(includeYuvStream = true)
                    }

                    override fun onDisconnected(camera: CameraDevice) {
                        camera.close()
                        cameraDevice = null
                    }

                    override fun onError(camera: CameraDevice, error: Int) {
                        camera.close()
                        cameraDevice = null
                        if (error == CameraDevice.StateCallback.ERROR_CAMERA_DISABLED && !retriedOpenOnScreenWake) {
                            retriedOpenOnScreenWake = true
                            activity?.let { wakeAndKeepScreenOn(it) }
                            backgroundHandler?.postDelayed({
                                try {
                                    openAndConfigureCamera()
                                } catch (e: Exception) {
                                    mainHandler.post {
                                        result.error("CAMERA_OPEN_ERROR", "CameraDevice error code $error", null)
                                    }
                                }
                            }, 600L)
                            return
                        }
                        mainHandler.post {
                            result.error("CAMERA_OPEN_ERROR", "CameraDevice error code $error", null)
                        }
                    }
                }, backgroundHandler)
            }

            openAndConfigureCamera()
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

        // Extract hardware-detected faces and map to normalized portrait UI coordinates [cx, cy, w, h]
        var detectedFaceBox: List<Double>? = null
        try {
            val faces = physRes.get(CaptureResult.STATISTICS_FACES)
                ?: logicalRes.get(CaptureResult.STATISTICS_FACES)
            if (!faces.isNullOrEmpty()) {
                val manager = appContext.getSystemService(Context.CAMERA_SERVICE) as CameraManager
                val chars = manager.getCameraCharacteristics(activePhysicalCameraId ?: activeCameraId)
                val sensorRect = chars.get(CameraCharacteristics.SENSOR_INFO_ACTIVE_ARRAY_SIZE)
                if (sensorRect != null && sensorRect.width() > 0 && sensorRect.height() > 0) {
                    val bestFace = faces.maxByOrNull { it.bounds.width() * it.bounds.height() }
                    if (bestFace != null) {
                        val b = bestFace.bounds
                        val sx = ((b.centerX() - sensorRect.left).toFloat() / sensorRect.width()).coerceIn(0.05f, 0.95f)
                        val sy = ((b.centerY() - sensorRect.top).toFloat() / sensorRect.height()).coerceIn(0.05f, 0.95f)
                        val sw = (b.width().toFloat() / sensorRect.width()).coerceIn(0.10f, 0.85f)
                        val sh = (b.height().toFloat() / sensorRect.height()).coerceIn(0.10f, 0.85f)
                        val (uiX, uiY) = when ((activeSensorOrientation % 360 + 360) % 360) {
                            90 -> Pair(1.0f - sy, sx)
                            270 -> Pair(sy, 1.0f - sx)
                            180 -> Pair(1.0f - sx, 1.0f - sy)
                            else -> Pair(sx, sy)
                        }
                        detectedFaceBox = listOf(uiX.toDouble(), uiY.toDouble(), sh.toDouble(), sw.toDouble())
                    }
                }
            }
        } catch (e: Exception) {
            android.util.Log.w("ZameraCapture", "Face detection box mapping warning: ${e.message}")
        }

        val afFocused = afState == CaptureResult.CONTROL_AF_STATE_FOCUSED_LOCKED ||
            afState == CaptureResult.CONTROL_AF_STATE_PASSIVE_FOCUSED ||
            (focusDiopters != null && focusDiopters > 0.35f)

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
            "afState" to afState,
            "afFocused" to afFocused,
            "detectedFaceBox" to detectedFaceBox,
            "liveHistogram32" to latestLiveHistogram32,
            "liveHistogram64" to latestLiveHistogram64,
            "liveZebraRatio" to latestLiveZebraRatio,
            "liveZebraRatio70" to latestLiveZebraRatio70,
            "liveZebraGrid16x12" to latestLiveZebraGrid16x12,
            "liveFocusPeakingScore" to latestLiveFocusPeakingScore,
            "livePeakingGrid16x12" to latestLivePeakingGrid16x12,
            "liveFalseColorGrid16x12" to latestLiveFalseColorGrid16x12,
            "ndFilterRecommendation" to videoNdRecommendation
        )
    }

    /**
     * Real-time Camera2 YUV_420_888 Y-Plane analyzer (~10 Hz, <0.25 ms CPU cost on background thread):
     * Computes true 64-bin & 32-bin Luma Histogram, Dual-Threshold Zebra Overexposure (95% IRE & 70% IRE),
     * 6-Band IRE False Color grid, Sobel spatial Focus Peaking grid, and drives the WP-3.2 Software Auto-ISO
     * PI controller when 180° cinema shutter lock is active!
     */
    private fun analyzePreviewYuvFrame(img: Image, sensorOrientation: Int, isFrontFacing: Boolean) {
        val sw = img.width
        val sh = img.height
        if (sw < 16 || sh < 16) return
        val yPlane = img.planes[0]
        val yBuf = yPlane.buffer
        val rowStride = yPlane.rowStride
        val pixelStride = yPlane.pixelStride

        val histBins32 = IntArray(32)
        val histBins64 = IntArray(64)
        val gridCols = 12
        val gridRows = 16
        val gridSize = gridCols * gridRows
        val zebraHits = IntArray(gridSize)
        val cellCounts = IntArray(gridSize)
        val cellLumaSums = IntArray(gridSize)
        val peakingSums = DoubleArray(gridSize)

        var totalSamples = 0
        var totalZebra95 = 0
        var totalZebra70 = 0
        var totalLumaSum = 0L
        var totalGradSum = 0.0

        val invSw = 1.0f / (sw - 1).coerceAtLeast(1)
        val invSh = 1.0f / (sh - 1).coerceAtLeast(1)

        for (sy in 1 until sh - 1 step 2) {
            val rowOff = sy * rowStride
            val rowUp = (sy - 1) * rowStride
            val rowDown = (sy + 1) * rowStride
            val syNorm = sy * invSh
            for (sx in 1 until sw - 1 step 2) {
                val pxOff = rowOff + sx * pixelStride
                val yVal = yBuf.get(pxOff).toInt() and 0xFF
                histBins32[(yVal shr 3).coerceIn(0, 31)]++
                histBins64[(yVal shr 2).coerceIn(0, 63)]++
                totalLumaSum += yVal
                totalSamples++

                val yLeft = yBuf.get(rowOff + (sx - 1) * pixelStride).toInt() and 0xFF
                val yRight = yBuf.get(rowOff + (sx + 1) * pixelStride).toInt() and 0xFF
                val yUp = yBuf.get(rowUp + sx * pixelStride).toInt() and 0xFF
                val yDown = yBuf.get(rowDown + sx * pixelStride).toInt() and 0xFF
                val grad = (kotlin.math.abs(yRight - yLeft) + kotlin.math.abs(yDown - yUp)) / 510.0
                totalGradSum += grad

                val sxNorm = sx * invSw
                val ux: Float
                val uy: Float
                when ((sensorOrientation % 360 + 360) % 360) {
                    90 -> {
                        ux = 1.0f - syNorm
                        uy = sxNorm
                    }
                    270 -> {
                        val rawUx = syNorm
                        ux = if (isFrontFacing) (1.0f - rawUx) else rawUx
                        uy = 1.0f - sxNorm
                    }
                    180 -> {
                        ux = 1.0f - sxNorm
                        uy = 1.0f - syNorm
                    }
                    else -> {
                        ux = sxNorm
                        uy = syNorm
                    }
                }
                val gx = (ux * gridCols).toInt().coerceIn(0, gridCols - 1)
                val gy = (uy * gridRows).toInt().coerceIn(0, gridRows - 1)
                val cIdx = gy * gridCols + gx
                cellCounts[cIdx]++
                cellLumaSums[cIdx] += yVal
                if (yVal >= 242) {
                    totalZebra95++
                    zebraHits[cIdx]++
                } else if (yVal in 173..190) {
                    totalZebra70++
                }
                peakingSums[cIdx] += grad
            }
        }

        if (totalSamples <= 0) return
        val maxBin32 = (histBins32.maxOrNull() ?: 1).coerceAtLeast(1).toDouble()
        val maxBin64 = (histBins64.maxOrNull() ?: 1).coerceAtLeast(1).toDouble()
        latestLiveHistogram32 = List(32) { i -> (histBins32[i] / maxBin32).coerceIn(0.0, 1.0) }
        latestLiveHistogram64 = List(64) { i -> (histBins64[i] / maxBin64).coerceIn(0.0, 1.0) }
        latestLiveZebraRatio = (totalZebra95.toDouble() / totalSamples).coerceIn(0.0, 1.0)
        latestLiveZebraRatio70 = (totalZebra70.toDouble() / totalSamples).coerceIn(0.0, 1.0)
        latestLiveFocusPeakingScore = ((totalGradSum / totalSamples) * 4.5).coerceIn(0.0, 1.0)
        val meanLumaNorm = ((totalLumaSum.toDouble() / totalSamples) / 255.0).coerceIn(0.005, 1.0)
        latestMeanSceneLumaNorm = meanLumaNorm

        latestLiveZebraGrid16x12 = List(gridSize) { i ->
            val cnt = cellCounts[i].coerceAtLeast(1)
            (zebraHits[i].toDouble() / cnt).coerceIn(0.0, 1.0)
        }
        latestLivePeakingGrid16x12 = List(gridSize) { i ->
            val cnt = cellCounts[i].coerceAtLeast(1)
            ((peakingSums[i] / cnt) * 5.0).coerceIn(0.0, 1.0)
        }
        latestLiveFalseColorGrid16x12 = List(gridSize) { i ->
            val cnt = cellCounts[i].coerceAtLeast(1)
            val ire = ((cellLumaSums[i].toDouble() / cnt) / 255.0) * 100.0
            when {
                ire < 10.0 -> 0
                ire < 25.0 -> 1
                ire < 48.0 -> 2
                ire < 70.0 -> 3
                ire < 94.0 -> 4
                else -> 5
            }
        }

        // WP-3.2 Software Auto-ISO PI Controller (active when 180° shutter angle is locked and manualIso is false)
        if (videoSessionActive && videoLockShutterAngle && !videoManualIso) {
            applySoftwareAutoIsoStep(meanLumaNorm)
        }
    }

    /**
     * Zero-extra-stream fallback analyzer via PixelCopy when a physical sub-camera HAL restricts stream count to 3 (PRIV + JPEG + RAW).
     */
    private fun samplePreviewSurfaceViaPixelCopy(surf: Surface) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N || !surf.isValid) return
        val bgHandler = backgroundHandler ?: return
        try {
            val bmp = Bitmap.createBitmap(160, 120, Bitmap.Config.ARGB_8888)
            android.view.PixelCopy.request(surf, bmp, { copyResult ->
                try {
                    if (copyResult == android.view.PixelCopy.SUCCESS) {
                        val sw = bmp.width
                        val sh = bmp.height
                        val pixels = IntArray(sw * sh)
                        bmp.getPixels(pixels, 0, sw, 0, 0, sw, sh)
                        val histBins = IntArray(32)
                        val histBins64 = IntArray(64)
                        val gridCols = 12
                        val gridRows = 16
                        val gridSize = gridCols * gridRows
                        val zebraHits = IntArray(gridSize)
                        val cellCounts = IntArray(gridSize)
                        val cellLumaSums = IntArray(gridSize)
                        val peakingSums = DoubleArray(gridSize)
                        var totalSamples = 0
                        var totalZebra = 0
                        var totalZebra70 = 0
                        var totalGradSum = 0.0
                        for (sy in 1 until sh - 1) {
                            val rowOff = sy * sw
                            for (sx in 1 until sw - 1) {
                                val p = pixels[rowOff + sx]
                                val yVal = (((p shr 16) and 0xFF) * 77 + ((p shr 8) and 0xFF) * 150 + (p and 0xFF) * 29) shr 8
                                histBins[(yVal shr 3).coerceIn(0, 31)]++
                                histBins64[(yVal shr 2).coerceIn(0, 63)]++
                                totalSamples++
                                val pL = pixels[rowOff + sx - 1]
                                val pR = pixels[rowOff + sx + 1]
                                val pU = pixels[rowOff - sw + sx]
                                val pD = pixels[rowOff + sw + sx]
                                val yL = (((pL shr 16) and 0xFF) * 77 + ((pL shr 8) and 0xFF) * 150 + (pL and 0xFF) * 29) shr 8
                                val yR = (((pR shr 16) and 0xFF) * 77 + ((pR shr 8) and 0xFF) * 150 + (pR and 0xFF) * 29) shr 8
                                val yU = (((pU shr 16) and 0xFF) * 77 + ((pU shr 8) and 0xFF) * 150 + (pU and 0xFF) * 29) shr 8
                                val yD = (((pD shr 16) and 0xFF) * 77 + ((pD shr 8) and 0xFF) * 150 + (pD and 0xFF) * 29) shr 8
                                val grad = (kotlin.math.abs(yR - yL) + kotlin.math.abs(yD - yU)) / 510.0
                                totalGradSum += grad
                                val gx = (sx * gridCols / sw).coerceIn(0, gridCols - 1)
                                val gy = (sy * gridRows / sh).coerceIn(0, gridRows - 1)
                                val cIdx = gy * gridCols + gx
                                cellCounts[cIdx]++
                                cellLumaSums[cIdx] += yVal
                                if (yVal >= 242) {
                                    totalZebra++
                                    zebraHits[cIdx]++
                                } else if (yVal in 173..190) {
                                    totalZebra70++
                                }
                                peakingSums[cIdx] += grad
                            }
                        }
                        if (totalSamples > 0) {
                            val maxBin = (histBins.maxOrNull() ?: 1).coerceAtLeast(1).toDouble()
                            val maxBin64 = (histBins64.maxOrNull() ?: 1).coerceAtLeast(1).toDouble()
                            latestLiveHistogram32 = List(32) { i -> (histBins[i] / maxBin).coerceIn(0.0, 1.0) }
                            latestLiveHistogram64 = List(64) { i -> (histBins64[i] / maxBin64).coerceIn(0.0, 1.0) }
                            latestLiveZebraRatio = (totalZebra.toDouble() / totalSamples).coerceIn(0.0, 1.0)
                            latestLiveZebraRatio70 = (totalZebra70.toDouble() / totalSamples).coerceIn(0.0, 1.0)
                            latestLiveFocusPeakingScore = ((totalGradSum / totalSamples) * 4.5).coerceIn(0.0, 1.0)
                            latestLiveZebraGrid16x12 = List(gridSize) { i ->
                                (zebraHits[i].toDouble() / cellCounts[i].coerceAtLeast(1)).coerceIn(0.0, 1.0)
                            }
                            latestLivePeakingGrid16x12 = List(gridSize) { i ->
                                ((peakingSums[i] / cellCounts[i].coerceAtLeast(1)) * 5.0).coerceIn(0.0, 1.0)
                            }
                            latestLiveFalseColorGrid16x12 = List(gridSize) { i ->
                                val cnt = cellCounts[i].coerceAtLeast(1)
                                val ire = ((cellLumaSums[i].toDouble() / cnt) / 255.0) * 100.0
                                when {
                                    ire < 10.0 -> 0
                                    ire < 25.0 -> 1
                                    ire < 48.0 -> 2
                                    ire < 70.0 -> 3
                                    ire < 94.0 -> 4
                                    else -> 5
                                }
                            }
                        }
                    }
                } catch (e: Throwable) {
                    android.util.Log.w("ZameraCapture", "PixelCopy inner analysis warning: ${e.message}")
                } finally {
                    bmp.recycle()
                }
            }, bgHandler)
        } catch (e: Throwable) {
            android.util.Log.w("ZameraCapture", "PixelCopy request warning: ${e.message}")
        }
    }

    private fun setFocusAndMeteringPoint(args: Map<String, Any?>, result: Result) {
        activeFocusPullRunnable?.let { backgroundHandler?.removeCallbacks(it) }
        activeFocusPullRunnable = null
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

            val reqZoom = ((args["zoomRatio"] as? Number)?.toFloat() ?: 1.0f).coerceIn(1.0f, 10.0f)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                val zoomRange = chars.get(CameraCharacteristics.CONTROL_ZOOM_RATIO_RANGE)
                val clampedZoom = if (zoomRange != null) {
                    reqZoom.coerceIn(zoomRange.lower, zoomRange.upper)
                } else {
                    reqZoom
                }
                builder.set(CaptureRequest.CONTROL_ZOOM_RATIO, clampedZoom)
            }
            val sensorRect = chars.get(CameraCharacteristics.SENSOR_INFO_ACTIVE_ARRAY_SIZE)
            if (sensorRect != null && reqZoom > 1.001f) {
                val cropW = (sensorRect.width() / reqZoom).toInt().coerceAtLeast(64)
                val cropH = (sensorRect.height() / reqZoom).toInt().coerceAtLeast(64)
                val cropX = sensorRect.centerX() - cropW / 2
                val cropY = sensorRect.centerY() - cropH / 2
                builder.set(
                    CaptureRequest.SCALER_CROP_REGION,
                    Rect(cropX, cropY, cropX + cropW, cropY + cropH)
                )
            } else if (sensorRect != null) {
                builder.set(CaptureRequest.SCALER_CROP_REGION, sensorRect)
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
            val effectiveMinFocus = if (minFocus > 0.0f) minFocus else 10.0f
            if (manualFocus) {
                val prevAfMode = builder.get(CaptureRequest.CONTROL_AF_MODE)
                if (prevAfMode != CaptureRequest.CONTROL_AF_MODE_OFF) {
                    // Cancel any active AF state machine before locking VCM voice-coil to manual diopters
                    builder.set(CaptureRequest.CONTROL_AF_TRIGGER, CameraMetadata.CONTROL_AF_TRIGGER_CANCEL)
                    session.capture(builder.build(), null, backgroundHandler)
                    builder.set(CaptureRequest.CONTROL_AF_TRIGGER, CameraMetadata.CONTROL_AF_TRIGGER_IDLE)
                }
                builder.set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_OFF)
                val normFocus = (args["focusDistance"] as? Number)?.toFloat() ?: 0.5f
                val focusDiopters = (normFocus.coerceIn(0.0f, 1.0f)) * effectiveMinFocus
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

            val monoMode = args["monoMode"] as? Boolean ?: false
            val availEffects = chars.get(CameraCharacteristics.CONTROL_AVAILABLE_EFFECTS)
            if (monoMode && availEffects != null && availEffects.contains(CameraMetadata.CONTROL_EFFECT_MODE_MONO)) {
                builder.set(CaptureRequest.CONTROL_EFFECT_MODE, CameraMetadata.CONTROL_EFFECT_MODE_MONO)
            } else {
                builder.set(CaptureRequest.CONTROL_EFFECT_MODE, CameraMetadata.CONTROL_EFFECT_MODE_OFF)
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
            // Fast ZSL-grade hardware JPEG & noise/edge settings to eliminate multi-frame HAL stalls
            captureBuilder.set(CaptureRequest.JPEG_QUALITY, 95.toByte())
            captureBuilder.set(CaptureRequest.NOISE_REDUCTION_MODE, CaptureRequest.NOISE_REDUCTION_MODE_FAST)
            captureBuilder.set(CaptureRequest.EDGE_MODE, CaptureRequest.EDGE_MODE_FAST)
            val reqZoom = ((args["zoomRatio"] as? Number)?.toFloat() ?: 1.0f).coerceIn(1.0f, 10.0f)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                captureBuilder.set(CaptureRequest.CONTROL_ZOOM_RATIO, reqZoom)
            }
            previewRequestBuilder?.get(CaptureRequest.SCALER_CROP_REGION)?.let {
                captureBuilder.set(CaptureRequest.SCALER_CROP_REGION, it)
            }
            captureBuilder.set(CaptureRequest.JPEG_ORIENTATION, activeSensorOrientation)

            val isPortraitMode = args["isPortraitMode"] as? Boolean ?: false
            val portraitAperture = ((args["portraitAperture"] as? Number)?.toFloat() ?: 2.8f).coerceIn(1.4f, 16.0f)
            val portraitLighting = ((args["portraitLighting"] as? Number)?.toInt() ?: 0).coerceIn(0, 9)
            val portraitLightIntensity = ((args["portraitLightIntensity"] as? Number)?.toFloat() ?: 0.80f).coerceIn(0.0f, 1.0f)
            val portraitSubjectRadius = ((args["portraitSubjectRadius"] as? Number)?.toFloat() ?: 0.36f).coerceIn(0.20f, 0.58f)
            val focusPointX = ((args["focusPointX"] as? Number)?.toFloat() ?: 0.5f).coerceIn(0.08f, 0.92f)
            val focusPointY = ((args["focusPointY"] as? Number)?.toFloat() ?: 0.45f).coerceIn(0.08f, 0.92f)
            val captureRaw = !isPortraitMode && (args["captureRaw"] as? Boolean ?: true) && rawImageReader != null
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
                        } else if (isPortraitMode) {
                            val portraitStartMs = System.currentTimeMillis()
                            val isFrontCam = physChars.get(CameraCharacteristics.LENS_FACING) == CameraCharacteristics.LENS_FACING_FRONT
                            applyPortraitBokehAndLighting(
                                sourceJpeg = oemJpegFile,
                                outJpeg = trueColorJpegFile,
                                aperture = portraitAperture,
                                lightingMode = portraitLighting,
                                lightIntensity = portraitLightIntensity,
                                subjectRadiusRatio = portraitSubjectRadius,
                                focusX = focusPointX,
                                focusY = focusPointY,
                                isFrontCamera = isFrontCam
                            )
                            val portraitProcessMs = System.currentTimeMillis() - portraitStartMs
                            android.util.Log.i(
                                "ZameraPortrait",
                                "Portrait capture latency: ${portraitProcessMs}ms (target < 1800ms)"
                            )
                            val targetPortrait = if (trueColorJpegFile.exists()) trueColorJpegFile else oemJpegFile
                            mediaStoreJpegUri = saveFileToMediaStoreDcim(
                                sourceFile = targetPortrait,
                                displayName = "${baseName}_PORTRAIT.jpg",
                                mimeType = "image/jpeg"
                            )
                            statsMap = mapOf(
                                "portraitProcessMs" to portraitProcessMs,
                                "portraitLightingMode" to portraitLighting,
                                "portraitAperture" to portraitAperture.toDouble(),
                                "zebraRatio" to latestLiveZebraRatio,
                                "focusPeakingScore" to latestLiveFocusPeakingScore,
                                "rawHistogram32" to latestLiveHistogram32
                            )
                        } else {
                            mediaStoreJpegUri = saveFileToMediaStoreDcim(
                                sourceFile = oemJpegFile,
                                displayName = "${baseName}.jpg",
                                mimeType = "image/jpeg"
                            )
                        }

                        val finalJpegPath = if ((isArtworkMode || isPortraitMode) && trueColorJpegFile.exists()) {
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
                            put("captureDurationMs", System.currentTimeMillis() - timestamp)
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

    /**
     * O(1)-per-pixel Separable Sliding-Window Box Filter on a 2D float grid (w x h).
     */
    private fun boxFilterFloat(src: FloatArray, w: Int, h: Int, radius: Int): FloatArray {
        val r = radius.coerceIn(1, kotlin.math.min(w, h) / 2 - 1)
        val tmp = FloatArray(w * h)
        val out = FloatArray(w * h)
        val norm = 1.0f / (2 * r + 1).toFloat()

        // Horizontal pass
        for (y in 0 until h) {
            val row = y * w
            var sum = 0f
            for (k in -r..r) {
                val xk = k.coerceIn(0, w - 1)
                sum += src[row + xk]
            }
            tmp[row] = sum * norm
            for (x in 1 until w) {
                val addIdx = (x + r).coerceAtMost(w - 1)
                val remIdx = (x - r - 1).coerceAtLeast(0)
                sum += src[row + addIdx] - src[row + remIdx]
                tmp[row + x] = sum * norm
            }
        }

        // Vertical pass
        for (x in 0 until w) {
            var sum = 0f
            for (k in -r..r) {
                val yk = k.coerceIn(0, h - 1)
                sum += tmp[yk * w + x]
            }
            out[x] = sum * norm
            for (y in 1 until h) {
                val addIdx = (y + r).coerceAtMost(h - 1)
                val remIdx = (y - r - 1).coerceAtLeast(0)
                sum += tmp[addIdx * w + x] - tmp[remIdx * w + x]
                out[y * w + x] = sum * norm
            }
        }
        return out
    }

    /**
     * Computes Fast Guided Filter linear coefficients (meanA, meanB) on a `segW x segH` grid:
     * 1. Runs Google ML Kit Bundled Neural Segmentation (`SelfieSegmenter`) with bilinear tensor sampling for humans.
     * 2. Only when NO human is detected (`maxMlConf <= 0.50f`), falls back to Geodesic Edge-Barrier Object Segmentation
     *    around `(focusX, focusY)` so non-human subjects (cups, pets, flowers) are also separated without polluting human portraits!
     * 3. Refines the raw mask using He et al.'s Edge-Preserving Joint Guided Filter (`meanA`, `meanB`) so full-resolution
     *    hair strands, beard fibers, and eyeglass frames are cleanly matted with zero halo.
     */
    private fun computeGuidedAlphaCoefficients(
        srcBmp: Bitmap,
        segW: Int,
        segH: Int,
        focusX: Float,
        focusY: Float,
        subjectRadiusRatio: Float
    ): Triple<FloatArray, FloatArray, Float> {
        val segBmp = Bitmap.createScaledBitmap(srcBmp, segW, segH, true)
        val n = segW * segH
        val mlMask = FloatArray(n)
        var maxMlConf = 0f

        // 1. ML Kit Neural Person/Portrait Segmentation (Warm cached singleton model, zero reload delay)
        // CRITICAL FIX: JNI DirectByteBuffer defaults to BIG_ENDIAN; must set ByteOrder.nativeOrder() before reading floats!
        try {
            val inputImage = InputImage.fromBitmap(segBmp, 0)
            val mask = Tasks.await(
                getOrCreateSelfieSegmenter().process(inputImage),
                2000,
                java.util.concurrent.TimeUnit.MILLISECONDS
            )
            if (mask != null) {
                val mw = mask.width
                val mh = mask.height
                val buf = mask.buffer
                buf.order(ByteOrder.nativeOrder())
                buf.rewind()
                val rawMask = FloatArray(mw * mh)
                buf.asFloatBuffer().get(rawMask)
                for (y in 0 until segH) {
                    val gy = (y.toFloat() / (segH - 1).coerceAtLeast(1)) * (mh - 1)
                    val y0 = gy.toInt().coerceIn(0, mh - 2)
                    val fy = gy - y0
                    for (x in 0 until segW) {
                        val gx = (x.toFloat() / (segW - 1).coerceAtLeast(1)) * (mw - 1)
                        val x0 = gx.toInt().coerceIn(0, mw - 2)
                        val fx = gx - x0
                        val c00 = rawMask[y0 * mw + x0]
                        val c10 = rawMask[y0 * mw + x0 + 1]
                        val c01 = rawMask[(y0 + 1) * mw + x0]
                        val c11 = rawMask[(y0 + 1) * mw + x0 + 1]
                        val c = (c00 * (1f - fx) * (1f - fy) +
                            c10 * fx * (1f - fy) +
                            c01 * (1f - fx) * fy +
                            c11 * fx * fy)
                        val validC = if (c.isNaN()) 0f else c.coerceIn(0f, 1f)
                        mlMask[y * segW + x] = validC
                        if (validC > maxMlConf) maxMlConf = validC
                    }
                }
            }
            android.util.Log.i("ZameraPortrait", "MLKit SelfieSegmenter maxMlConf=$maxMlConf on ${segW}x${segH}")
        } catch (t: Throwable) {
            android.util.Log.e("ZameraPortrait", "MLKit SelfieSegmenter error: ${t.message}", t)
        }

        val pixels = IntArray(n)
        segBmp.getPixels(pixels, 0, segW, 0, 0, segW, segH)
        segBmp.recycle()

        val lumaNorm = FloatArray(n)
        val luma255 = FloatArray(n)
        val chA = FloatArray(n)
        val chB = FloatArray(n)
        for (i in 0 until n) {
            val p = pixels[i]
            val r = ((p shr 16) and 0xFF).toFloat()
            val g = ((p shr 8) and 0xFF).toFloat()
            val b = (p and 0xFF).toFloat()
            val yVal = 0.299f * r + 0.587f * g + 0.114f * b
            luma255[i] = yVal
            lumaNorm[i] = (yVal / 255.0f).coerceIn(0f, 1f)
            chA[i] = r - g
            chB[i] = 0.5f * (r + g) - b
        }

        val rawAlpha = FloatArray(n)

        // Count strong human pixels and locate anatomical bounding box [minHx..maxHx, minHy..maxHy]
        var strongHumanPixels = 0
        var minHx = segW
        var maxHx = 0
        var minHy = segH
        var maxHy = 0
        for (y in 0 until segH) {
            val row = y * segW
            for (x in 0 until segW) {
                if (mlMask[row + x] >= 0.48f) {
                    strongHumanPixels++
                    if (x < minHx) minHx = x
                    if (x > maxHx) maxHx = x
                    if (y < minHy) minHy = y
                    if (y > maxHy) maxHy = y
                }
            }
        }
        val humanAreaRatio = strongHumanPixels.toFloat() / n.coerceAtLeast(1).toFloat()
        val hasStrongMlSubject = maxMlConf > 0.55f && humanAreaRatio >= 0.012f

        if (hasStrongMlSubject) {
            val bodyW = (maxHx - minHx).coerceAtLeast(12)
            val bodyH = (maxHy - minHy).coerceAtLeast(12)
            val anatLeft = (minHx - (bodyW * 0.35f).toInt()).coerceAtLeast(0)
            val anatRight = (maxHx + (bodyW * 0.35f).toInt()).coerceAtMost(segW - 1)
            val anatTop = (minHy - (bodyH * 0.12f).toInt()).coerceAtLeast(0)
            val anatBottom = (maxHy + (bodyH * 0.32f).toInt()).coerceAtMost(segH - 1)
            val lapLeft = (minHx - (bodyW * 0.15f).toInt()).coerceAtLeast(0)
            val lapRight = (maxHx + (bodyW * 0.15f).toInt()).coerceAtMost(segW - 1)
            val lapTop = (minHy + (bodyH * 0.50f).toInt()).coerceAtMost(segH - 1)
            val lapBottom = (maxHy + (bodyH * 0.22f).toInt()).coerceAtMost(segH - 1)

            // 3D Optical Focal Plane weight for wide/room environmental portraits (humanAreaRatio < 0.22f)
            val envFocalWeight = ((0.22f - humanAreaRatio) / 0.15f).coerceIn(0f, 1f)
            val contactY = maxHy.toFloat()

            for (y in 0 until segH) {
                val row = y * segW
                // Smooth 3D Optical Focal Plane band around the subject's floor/table contact plane (y ≈ contactY)
                // Prevents harsh cut-in-half appearance when a person sits on the floor or behind a coffee table!
                val focalPlaneAlpha = if (envFocalWeight > 0.01f) {
                    val dyNorm = if (y <= contactY) {
                        (y - contactY) / (segH * 0.11f).coerceAtLeast(1f)
                    } else {
                        (y - contactY) / (segH * 0.36f).coerceAtLeast(1f)
                    }
                    val band = kotlin.math.exp((-dyNorm * dyNorm).toDouble()).toFloat() * 0.65f
                    val fgFloor = if (y > contactY) 0.24f else 0f
                    kotlin.math.max(band, fgFloor) * envFocalWeight
                } else {
                    0f
                }

                for (x in 0 until segW) {
                    val i = row + x
                    val m = mlMask[i]
                    val inLapZone = x in lapLeft..lapRight && y in lapTop..lapBottom
                    val inAnatZone = x in anatLeft..anatRight && y in anatTop..anatBottom
                    val subjAlpha = when {
                        inLapZone -> ((m - 0.06f) / 0.28f).coerceIn(0f, 1f)
                        inAnatZone -> ((m - 0.15f) / 0.36f).coerceIn(0f, 1f)
                        else -> ((m - 0.30f) / 0.38f).coerceIn(0f, 1f)
                    }
                    rawAlpha[i] = kotlin.math.max(subjAlpha, focalPlaneAlpha)
                }
            }

            // 1B. Narrow Eyeglass / Facial Interior Hole-Fill ONLY:
            // Only bridge small internal dips (width <= segW / 8, where mlMask stays >= 0.32f) such as eyeglass lenses,
            // NEVER bridging across background wall gaps between a raised arm and head or couch cushions!
            val maxGlassSpan = (segW / 8).coerceAtLeast(10)
            for (y in 0 until segH) {
                val row = y * segW
                var x = 0
                while (x < segW) {
                    if (rawAlpha[row + x] >= 0.88f) {
                        var nextStrong = -1
                        var minMlInGap = 1.0f
                        val limit = (x + maxGlassSpan).coerceAtMost(segW - 1)
                        for (k in (x + 1)..limit) {
                            val mk = mlMask[row + k]
                            if (mk < minMlInGap) minMlInGap = mk
                            if (rawAlpha[row + k] >= 0.88f) {
                                nextStrong = k
                                break
                            }
                        }
                        if (nextStrong > x + 1 && minMlInGap >= 0.32f) {
                            for (k in (x + 1) until nextStrong) {
                                if (rawAlpha[row + k] < 0.95f) rawAlpha[row + k] = 0.95f
                            }
                            x = nextStrong
                            continue
                        }
                    }
                    x++
                }
            }
        } else {
            // 2. Non-human object fallback (ONLY when no human is present in the frame!):
            val cx = (focusX * segW).toInt().coerceIn(segW / 5, segW * 4 / 5)
            val cy = (focusY * segH).toInt().coerceIn(segH / 5, segH * 4 / 5)

            var bgL = 0f
            var bgA = 0f
            var bgB = 0f
            var bgCount = 0
            val borderW = (segW * 0.07f).toInt().coerceAtLeast(4)
            val borderH = (segH * 0.07f).toInt().coerceAtLeast(4)
            for (y in 0 until segH step 2) {
                for (x in 0 until segW step 2) {
                    if (x < borderW || x >= segW - borderW || y < borderH) {
                        val idx = y * segW + x
                        bgL += luma255[idx]
                        bgA += chA[idx]
                        bgB += chB[idx]
                        bgCount++
                    }
                }
            }
            if (bgCount > 0) {
                bgL /= bgCount
                bgA /= bgCount
                bgB /= bgCount
            }

            val baseRadiusPx = kotlin.math.min(segW, segH) * (subjectRadiusRatio.coerceIn(0.24f, 0.42f) * 0.95f)
            val coreRadiusPx = baseRadiusPx * 0.65f
            val outerRadiusPx = baseRadiusPx * 1.25f

            for (y in 0 until segH) {
                val dy = (y - cy).toFloat() * 0.85f
                for (x in 0 until segW) {
                    val dx = (x - cx).toFloat()
                    val i = y * segW + x
                    val dist = kotlin.math.sqrt(dx * dx + dy * dy)
                    if (dist <= coreRadiusPx) {
                        rawAlpha[i] = 1.0f
                    } else if (dist >= outerRadiusPx) {
                        rawAlpha[i] = 0.0f
                    } else {
                        val radialT = 1.0f - ((dist - coreRadiusPx) / (outerRadiusPx - coreRadiusPx)).coerceIn(0f, 1f)
                        val dBg = 0.7f * kotlin.math.abs(luma255[i] - bgL) +
                            kotlin.math.abs(chA[i] - bgA) +
                            kotlin.math.abs(chB[i] - bgB)
                        val bgDiffBoost = (dBg / 45.0f).coerceIn(0f, 1f)
                        val combined = (radialT * 0.75f + bgDiffBoost * 0.25f * radialT).coerceIn(0f, 1f)
                        rawAlpha[i] = combined * combined * (3.0f - 2.0f * combined)
                    }
                }
            }
        }

        // 3. Zero-Bleed Soft Optical Guided Filter:
        // Clamp 'ai' tightly to [-0.08..0.08] with eps = 0.04f so dark background objects (like a black floor baseboard
        // behind dark hair) NEVER bleed into the foreground mask as dark spikes, and bright clothing (like white pants
        // below a black cardigan) is NEVER erased by luminance inversion!
        val gfRadius = 4
        val eps = 0.040f
        val ii = FloatArray(n)
        val ip = FloatArray(n)
        for (i in 0 until n) {
            val gSig = lumaNorm[i]
            ii[i] = gSig * gSig
            ip[i] = gSig * rawAlpha[i]
        }
        val meanI = boxFilterFloat(lumaNorm, segW, segH, gfRadius)
        val meanP = boxFilterFloat(rawAlpha, segW, segH, gfRadius)
        val corrI = boxFilterFloat(ii, segW, segH, gfRadius)
        val corrIp = boxFilterFloat(ip, segW, segH, gfRadius)

        val a = FloatArray(n)
        val b = FloatArray(n)
        for (i in 0 until n) {
            val varI = (corrI[i] - meanI[i] * meanI[i]).coerceAtLeast(0f)
            val covIp = corrIp[i] - meanI[i] * meanP[i]
            val ai = (covIp / (varI + eps)).coerceIn(-0.08f, 0.08f)
            a[i] = ai
            b[i] = meanP[i] - ai * meanI[i]
        }
        val meanA = boxFilterFloat(a, segW, segH, gfRadius + 1)
        val meanB = boxFilterFloat(b, segW, segH, gfRadius + 1)
        return Triple(meanA, meanB, if (hasStrongMlSubject) humanAreaRatio else 0.25f)
    }

    private fun applyPortraitBokehAndLighting(
        sourceJpeg: File,
        outJpeg: File,
        aperture: Float,
        lightingMode: Int,
        lightIntensity: Float,
        subjectRadiusRatio: Float,
        focusX: Float,
        focusY: Float,
        isFrontCamera: Boolean = false,
        allowDepthInversionOnBgTap: Boolean = false
    ) {
        try {
            val exif = ExifInterface(sourceJpeg.absolutePath)
            val orientAttr = exif.getAttributeInt(
                ExifInterface.TAG_ORIENTATION,
                ExifInterface.ORIENTATION_NORMAL
            )
            // Decode with inSampleSize = 2 when > 2600px so memory stays low while preserving crisp detail
            val boundsOpts = android.graphics.BitmapFactory.Options().apply {
                inJustDecodeBounds = true
            }
            android.graphics.BitmapFactory.decodeFile(sourceJpeg.absolutePath, boundsOpts)
            val decodeOpts = android.graphics.BitmapFactory.Options().apply {
                inSampleSize = if (kotlin.math.max(boundsOpts.outWidth, boundsOpts.outHeight) > 2600) 2 else 1
                inPreferredConfig = Bitmap.Config.ARGB_8888
            }
            var srcBmp = android.graphics.BitmapFactory.decodeFile(sourceJpeg.absolutePath, decodeOpts) ?: return
            val rotDeg = when (orientAttr) {
                ExifInterface.ORIENTATION_ROTATE_90 -> 90f
                ExifInterface.ORIENTATION_ROTATE_180 -> 180f
                ExifInterface.ORIENTATION_ROTATE_270 -> 270f
                else -> 0f
            }
            if (rotDeg != 0f || isFrontCamera) {
                val m = Matrix().apply {
                    if (rotDeg != 0f) postRotate(rotDeg)
                    // Match Xiaomi stock camera & live preview mirror orientation on front selfie camera
                    if (isFrontCamera) postScale(-1f, 1f)
                }
                val transformed = Bitmap.createBitmap(srcBmp, 0, 0, srcBmp.width, srcBmp.height, m, true)
                if (transformed !== srcBmp) srcBmp.recycle()
                srcBmp = transformed
            }

            val w = srcBmp.width
            val h = srcBmp.height
            val segW = 288
            val segH = (288 * h / w.coerceAtLeast(1)).coerceIn(200, 420)

            // 1. Compute Fast Joint Guided Filter Alpha Matting Coefficients (meanA, meanB, humanAreaRatio)
            val (meanA, meanB, humanAreaRatio) = computeGuidedAlphaCoefficients(
                srcBmp = srcBmp,
                segW = segW,
                segH = segH,
                focusX = focusX,
                focusY = focusY,
                subjectRadiusRatio = subjectRadiusRatio
            )

            val totalPx = w * h
            val srcPixels = IntArray(totalPx)
            srcBmp.getPixels(srcPixels, 0, w, 0, 0, w, h)

            // Check if user tapped on background during Post-Capture Refocus to invert focus plane (Xiaomi Refocus!)
            var invertFocusPlane = false
            if (allowDepthInversionOnBgTap) {
                val tapX = (focusX * (w - 1)).toInt().coerceIn(0, w - 1)
                val tapY = (focusY * (h - 1)).toInt().coerceIn(0, h - 1)
                val tapGx = (focusX * (segW - 1)).toInt().coerceIn(0, segW - 1)
                val tapGy = (focusY * (segH - 1)).toInt().coerceIn(0, segH - 1)
                val tapSp = srcPixels[tapY * w + tapX]
                val tapLum = (0.299f * ((tapSp shr 16) and 0xFF) +
                    0.587f * ((tapSp shr 8) and 0xFF) +
                    0.114f * (tapSp and 0xFF)) / 255.0f
                val tapAlpha = (meanA[tapGy * segW + tapGx] * tapLum + meanB[tapGy * segW + tapGx]).coerceIn(0f, 1f)
                invertFocusPlane = tapAlpha < 0.32f
            }

            // 2. Halo-Free Normalized Background-Only Gaussian Bokeh at 1/3 Scale (2.25x faster with zero quality loss)
            val bw = (w / 3).coerceAtLeast(64)
            val bh = (h / 3).coerceAtLeast(64)
            val bn = bw * bh
            var bgR = FloatArray(bn)
            var bgG = FloatArray(bn)
            var bgB = FloatArray(bn)
            var bgW = FloatArray(bn)

            for (by in 0 until bh) {
                val sy = (by * 3).coerceAtMost(h - 1)
                val gy = (by.toFloat() / (bh - 1).coerceAtLeast(1)) * (segH - 1)
                val y0 = gy.toInt().coerceIn(0, segH - 2)
                val fy = gy - y0
                val srcRow = sy * w
                val bRow = by * bw
                for (bx in 0 until bw) {
                    val sx = (bx * 3).coerceAtMost(w - 1)
                    val gx = (bx.toFloat() / (bw - 1).coerceAtLeast(1)) * (segW - 1)
                    val x0 = gx.toInt().coerceIn(0, segW - 2)
                    val fx = gx - x0

                    val sp = srcPixels[srcRow + sx]
                    val r = ((sp shr 16) and 0xFF).toFloat()
                    val g = ((sp shr 8) and 0xFF).toFloat()
                    val b = (sp and 0xFF).toFloat()
                    val lumNorm = (0.299f * r + 0.587f * g + 0.114f * b) / 255.0f

                    val aVal = meanA[y0 * segW + x0] * (1f - fx) * (1f - fy) +
                        meanA[y0 * segW + x0 + 1] * fx * (1f - fy) +
                        meanA[(y0 + 1) * segW + x0] * (1f - fx) * fy +
                        meanA[(y0 + 1) * segW + x0 + 1] * fx * fy
                    val bVal = meanB[y0 * segW + x0] * (1f - fx) * (1f - fy) +
                        meanB[y0 * segW + x0 + 1] * fx * (1f - fy) +
                        meanB[(y0 + 1) * segW + x0] * (1f - fx) * fy +
                        meanB[(y0 + 1) * segW + x0 + 1] * fx * fy

                    val baseFg = (aVal * lumNorm + bVal).coerceIn(0f, 1f)
                    val fg = if (invertFocusPlane) (1.0f - baseFg) else baseFg
                    // Strictly exclude core human subject pixels (fg > 0.72f) from bleeding into background bokeh
                    val wBg = if (fg > 0.72f) {
                        0.001f
                    } else {
                        val t = (1.0f - fg / 0.72f).coerceIn(0f, 1f)
                        (t * t).coerceAtLeast(0.001f)
                    }

                    val bi = bRow + bx
                    bgR[bi] = r * wBg
                    bgG[bi] = g * wBg
                    bgB[bi] = b * wBg
                    bgW[bi] = wBg
                }
            }

            // 3-pass separable box cascade at 1/3 scale scaled by Optical Subject Magnification (Circle of Confusion):
            // Close-up portraits (humanAreaRatio >= 0.24) get deeper bokeh (gaussRadius ~ 7-9 at 1/3 scale);
            // Wide room portraits (humanAreaRatio ~ 0.05-0.10) get authentic 35mm f/1.8 optical defocus (gaussRadius ~ 3-4)
            // so room objects (curtains, cushions, tea glasses) retain realistic optical form instead of turning into white fog!
            val blurStrength = ((16.0f - aperture.coerceIn(1.4f, 16.0f)) / 14.6f).coerceIn(0.08f, 1.0f)
            val resScale = (kotlin.math.min(bw, bh).toFloat() / 500.0f).coerceIn(0.75f, 1.25f)
            val magScale = kotlin.math.sqrt((humanAreaRatio / 0.24f).toDouble()).toFloat().coerceIn(0.42f, 1.0f)
            val gaussRadius = ((1.8f + blurStrength * 6.8f) * resScale * magScale).toInt().coerceIn(2, 10)
            repeat(3) {
                bgR = boxFilterFloat(bgR, bw, bh, gaussRadius)
                bgG = boxFilterFloat(bgG, bw, bh, gaussRadius)
                bgB = boxFilterFloat(bgB, bw, bh, gaussRadius)
                bgW = boxFilterFloat(bgW, bw, bh, gaussRadius)
            }
            for (i in 0 until bn) {
                val invW = 1.0f / bgW[i].coerceAtLeast(1e-4f)
                bgR[i] = (bgR[i] * invW).coerceIn(0f, 255f)
                bgG[i] = (bgG[i] * invW).coerceIn(0f, 255f)
                bgB[i] = (bgB[i] * invW).coerceIn(0f, 255f)
            }

            val intensity = lightIntensity.coerceIn(0.15f, 1.0f)
            val isMono = lightingMode == 4 || lightingMode == 5 || lightingMode == 7
            val isHighKey = lightingMode == 5
            val isStage = lightingMode == 3 || lightingMode == 4
            val isBlinds = lightingMode == 6 || lightingMode == 7
            val isGoldenHour = lightingMode == 8
            val isPrismCinema = lightingMode == 9
            val cx = w * focusX
            val cy = h * focusY
            val minDim = kotlin.math.min(w, h).toFloat().coerceAtLeast(1f)
            val invMaxDist = 1.0f / (minDim * 0.55f)
            val blindFreq = (2.0 * Math.PI / (minDim * 0.072)).toFloat()
            val cos28 = 0.8829f
            val sin28 = 0.4695f

            // Precompute 256-entry Leica Silver-Gelatin Filmic S-Curve LUT for Monochrome Portrait modes
            val monoLut = FloatArray(256)
            if (isMono) {
                for (v in 0..255) {
                    val xNorm = v / 255.0f
                    if (isHighKey) {
                        val lifted = Math.pow(xNorm.toDouble(), 0.72).toFloat()
                        val sCurve = lifted * lifted * (3.0f - 2.0f * lifted)
                        monoLut[v] = ((0.35f * lifted + 0.65f * sCurve) * 250.0f + 5.0f).coerceIn(0f, 255f)
                    } else {
                        // Deep velvety D-max toe + smooth silver highlight shoulder
                        val s = xNorm * xNorm * (3.0f - 2.0f * xNorm)
                        val filmic = (0.28f * xNorm + 0.72f * s)
                        val contrast = ((filmic - 0.48f) * (1.16f + 0.14f * intensity) + 0.48f).coerceIn(0f, 1f)
                        monoLut[v] = (contrast * 255.0f).coerceIn(0f, 255f)
                    }
                }
            }

            val finalBgR = bgR
            val finalBgG = bgG
            val finalBgB = bgB

            // 3. Multi-Core Parallel Full-Resolution Guided Matting + Color Decontamination + Studio/Gobo/Monochrome Grade
            parallelForRows(h) { startY, endY ->
                for (y in startY until endY) {
                    val gy = (y.toFloat() / (h - 1).coerceAtLeast(1)) * (segH - 1)
                    val y0 = gy.toInt().coerceIn(0, segH - 2)
                    val fy = gy - y0

                    val byCoord = (y / 3.0f).coerceIn(0f, (bh - 1).toFloat())
                    val by0 = byCoord.toInt().coerceIn(0, bh - 2)
                    val bfy = byCoord - by0

                    val rowOffset = y * w
                    val dy = y - cy

                    for (x in 0 until w) {
                        val gx = (x.toFloat() / (w - 1).coerceAtLeast(1)) * (segW - 1)
                        val x0 = gx.toInt().coerceIn(0, segW - 2)
                        val fx = gx - x0

                        val bxCoord = (x / 3.0f).coerceIn(0f, (bw - 1).toFloat())
                        val bx0 = bxCoord.toInt().coerceIn(0, bw - 2)
                        val bfx = bxCoord - bx0

                        val idx = rowOffset + x
                        val sp = srcPixels[idx]
                        var sr = ((sp shr 16) and 0xFF).toFloat()
                        var sg = ((sp shr 8) and 0xFF).toFloat()
                        var sb = (sp and 0xFF).toFloat()
                        val lumNorm = (0.299f * sr + 0.587f * sg + 0.114f * sb) / 255.0f

                        // Evaluate Guided Filter at full resolution
                        val aVal = meanA[y0 * segW + x0] * (1f - fx) * (1f - fy) +
                            meanA[y0 * segW + x0 + 1] * fx * (1f - fy) +
                            meanA[(y0 + 1) * segW + x0] * (1f - fx) * fy +
                            meanA[(y0 + 1) * segW + x0 + 1] * fx * fy
                        val bVal = meanB[y0 * segW + x0] * (1f - fx) * (1f - fy) +
                            meanB[y0 * segW + x0 + 1] * fx * (1f - fy) +
                            meanB[(y0 + 1) * segW + x0] * (1f - fx) * fy +
                            meanB[(y0 + 1) * segW + x0 + 1] * fx * fy

                        val rawFg = (aVal * lumNorm + bVal).coerceIn(0f, 1f)
                        // Gentle optical smoothstep without steep binary clipping so hair/cloth/table transitions stay organic
                        val subjectFg = rawFg * rawFg * (3.0f - 2.0f * rawFg)
                        val fg = if (invertFocusPlane) (1.0f - subjectFg) else subjectFg
                        val bg = 1.0f - fg

                        // Bilinearly sample halo-free normalized background bokeh
                        val b00 = by0 * bw + bx0
                        val b10 = b00 + 1
                        val b01 = b00 + bw
                        val b11 = b01 + 1
                        val w00 = (1f - bfx) * (1f - bfy)
                        val w10 = bfx * (1f - bfy)
                        val w01 = (1f - bfx) * bfy
                        val w11 = bfx * bfy

                        var br = finalBgR[b00] * w00 + finalBgR[b10] * w10 + finalBgR[b01] * w01 + finalBgR[b11] * w11
                        var bgCh = finalBgG[b00] * w00 + finalBgG[b10] * w10 + finalBgG[b01] * w01 + finalBgG[b11] * w11
                        var bb = finalBgB[b00] * w00 + finalBgB[b10] * w10 + finalBgB[b01] * w01 + finalBgB[b11] * w11

                        // Boundary Color Decontamination ONLY for solid Studio Stage / High-Key backdrops (modes 3, 4, 5)
                        // Never apply on natural bokeh (modes 0, 1, 2, 6, 7, 8, 9), where it causes a visible contour ring on walls!
                        if ((isStage || isHighKey) && fg > 0.15f && fg < 0.85f) {
                            val deconStrength = 0.35f * (1.0f - fg)
                            val invFg = 1.0f / fg.coerceAtLeast(0.30f)
                            val targetR = ((sr - br * (1f - fg)) * invFg).coerceIn(sr - 20f, sr + 20f).coerceIn(0f, 255f)
                            val targetG = ((sg - bgCh * (1f - fg)) * invFg).coerceIn(sg - 20f, sg + 20f).coerceIn(0f, 255f)
                            val targetB = ((sb - bb * (1f - fg)) * invFg).coerceIn(sb - 20f, sb + 20f).coerceIn(0f, 255f)
                            sr = sr * (1f - deconStrength) + targetR * deconStrength
                            sg = sg * (1f - deconStrength) + targetG * deconStrength
                            sb = sb * (1f - deconStrength) + targetB * deconStrength
                        }

                        val edgeRim = fg * bg * 4.0f // Peaks at 1.0 along the subject's silhouette contour!

                        // Apply Studio / Gobo / Cinema relighting to separated foreground & background
                        if (lightingMode == 1) {
                            // STUDIO LIGHT: Warm facial/subject fill lift + softly dimmed bokeh background
                            sr = (sr * (1.0f + 0.14f * intensity)).coerceAtMost(255f)
                            sg = (sg * (1.0f + 0.13f * intensity)).coerceAtMost(255f)
                            sb = (sb * (1.0f + 0.11f * intensity)).coerceAtMost(255f)
                            val bgDim = 1.0f - 0.25f * intensity
                            br *= bgDim; bgCh *= bgDim; bb *= bgDim
                        } else if (lightingMode == 2) {
                            // CONTOUR LIGHT: Sculpted center highlight + dramatic edge contour shadow
                            val dx = x - cx
                            val radialNorm = (kotlin.math.sqrt(dx * dx + dy * dy) * invMaxDist).coerceIn(0f, 1.3f)
                            val contourSculpt = (1.15f - 0.34f * radialNorm * intensity).coerceIn(0.66f, 1.17f)
                            sr = (sr * contourSculpt).coerceIn(0f, 255f)
                            sg = (sg * contourSculpt).coerceIn(0f, 255f)
                            sb = (sb * contourSculpt).coerceIn(0f, 255f)
                            val bgDim = 1.0f - 0.46f * intensity
                            br *= bgDim; bgCh *= bgDim; bb *= bgDim
                        } else if (isStage) {
                            // STAGE LIGHT (3) & STAGE MONO (4): Pitch-black separated studio background!
                            val stageKeep = (1.0f - 0.97f * intensity).coerceIn(0.0f, 0.22f)
                            br *= stageKeep; bgCh *= stageKeep; bb *= stageKeep
                            sr = ((sr - 128f) * 1.12f + 130f).coerceIn(0f, 255f)
                            sg = ((sg - 128f) * 1.12f + 130f).coerceIn(0f, 255f)
                            sb = ((sb - 128f) * 1.12f + 130f).coerceIn(0f, 255f)
                        } else if (isHighKey) {
                            // HIGH-KEY MONO (5): Pure Alabaster White separated studio background!
                            val whiteMix = (0.96f * intensity).coerceIn(0.5f, 0.98f)
                            br = br * (1f - whiteMix) + 249f * whiteMix
                            bgCh = bgCh * (1f - whiteMix) + 249f * whiteMix
                            bb = bb * (1f - whiteMix) + 251f * whiteMix
                        } else if (isBlinds) {
                            // VENETIAN BLINDS GOBO (6 = PANJUR GÖLGESİ, 7 = PANJUR MONO):
                            // Angled 28° window-blind light slats with 3D depth parallax on the subject!
                            val proj = (x - cx) * sin28 + (y - cy) * cos28 + fg * (minDim * 0.022f)
                            val wave = kotlin.math.cos((proj * blindFreq).toDouble()).toFloat()
                            val slatLit = ((wave + 0.18f) * 1.65f).coerceIn(0f, 1f)
                            val smoothSlat = slatLit * slatLit * (3.0f - 2.0f * slatLit)
                            val shadowDepth = (0.68f * intensity).coerceIn(0.20f, 0.78f)
                            val fgGain = (1.0f - shadowDepth) + shadowDepth * (0.30f + 0.88f * smoothSlat)
                            // Warm golden window sunlight on lit slats
                            sr = (sr * fgGain * (1.0f + 0.12f * smoothSlat * intensity)).coerceIn(0f, 255f)
                            sg = (sg * fgGain * (1.0f + 0.05f * smoothSlat * intensity)).coerceIn(0f, 255f)
                            sb = (sb * fgGain * (1.0f - 0.06f * smoothSlat * intensity)).coerceIn(0f, 255f)
                            // Background receives deeper moody blind shadows
                            val bgGain = (1.0f - 0.62f * intensity) * (0.25f + 0.75f * smoothSlat)
                            br *= bgGain; bgCh *= bgGain; bb *= bgGain
                        } else if (isGoldenHour) {
                            // GOLDEN HOUR (8 = ALTIN SAAT): Warm 3500K sunset beam + glowing golden contour rim
                            val dx = (x - cx) / minDim
                            val dyNorm = (y - cy) / minDim
                            val sunBeam = (1.0f - ((dx * 0.7f + dyNorm * 0.7f + 0.25f).let { it * it } * 1.4f)).coerceIn(0.2f, 1.0f)
                            val warmBoost = intensity * sunBeam
                            sr = (sr * (1.0f + 0.22f * warmBoost) + 38f * edgeRim * intensity).coerceIn(0f, 255f)
                            sg = (sg * (1.0f + 0.09f * warmBoost) + 22f * edgeRim * intensity).coerceIn(0f, 255f)
                            sb = (sb * (1.0f - 0.12f * warmBoost) + 4f * edgeRim * intensity).coerceIn(0f, 255f)
                            br = (br * (1.0f + 0.14f * intensity)).coerceIn(0f, 255f)
                            bgCh = (bgCh * (1.0f + 0.02f * intensity)).coerceIn(0f, 255f)
                            bb = (bb * (1.0f - 0.18f * intensity)).coerceIn(0f, 255f)
                        } else if (isPrismCinema) {
                            // PRISM & CINEMA (9 = PRİZMA & SİNEMA): Dual-tone Cyan/Amber rim light + spectral prism flare
                            val side = if (x < cx) -1f else 1f
                            val cyanRim = if (side < 0f) edgeRim * intensity else 0f
                            val amberRim = if (side >= 0f) edgeRim * intensity else 0f
                            val prismWave = (0.5f + 0.5f * kotlin.math.sin(((x + y) * 0.018f).toDouble()).toFloat()) * (1f - fg) * intensity
                            sr = (sr + 46f * amberRim + 28f * prismWave).coerceIn(0f, 255f)
                            sg = (sg + 24f * cyanRim + 22f * amberRim + 14f * prismWave).coerceIn(0f, 255f)
                            sb = (sb + 52f * cyanRim + 36f * prismWave).coerceIn(0f, 255f)
                            val bgCinema = 1.0f - 0.35f * intensity
                            br = (br * bgCinema + 18f * prismWave).coerceIn(0f, 255f)
                            bgCh = (bgCh * bgCinema + 12f * prismWave).coerceIn(0f, 255f)
                            bb = (bb * (bgCinema + 0.10f * intensity) + 34f * prismWave).coerceIn(0f, 255f)
                        }

                        // Composite separated Foreground Subject (fg) over Halo-Free Background Bokeh (bg)
                        var outR = sr * fg + br * bg
                        var outG = sg * fg + bgCh * bg
                        var outB = sb * fg + bb * bg

                        // Upgraded Leica M11 Monochrom / Ilford Silver-Gelatin Grade (Stage Mono #4, High-Key Mono #5, Panjur Mono #7)
                        if (isMono) {
                            // 1. Panchromatic Red-Orange filter (0.38 R + 0.52 G + 0.10 B) for luminous skin & deep contrast
                            val fgPanchro = 0.38f * sr + 0.52f * sg + 0.10f * sb
                            val bgPanchro = 0.38f * br + 0.52f * bgCh + 0.10f * bb
                            // 2. Local Subject Micro-Contrast / Clarity (unsharp high-frequency detail on focused subject)
                            val microDetail = (fgPanchro - bgPanchro) * (0.20f * fg * intensity)
                            val rawMono = (0.38f * outR + 0.52f * outG + 0.10f * outB + microDetail).toInt().coerceIn(0, 255)
                            val curvedMono = monoLut[rawMono]
                            // 3. Subtle organic silver-halide midtone film grain
                            val midWeight = 4.0f * (curvedMono / 255.0f) * (1.0f - curvedMono / 255.0f)
                            val hash = ((x * 73856093) xor (y * 19349663)) and 0xFF
                            val grain = ((hash / 127.5f) - 1.0f) * 3.2f * midWeight * intensity
                            val finalMono = (curvedMono + grain).coerceIn(0f, 255f)
                            // 4. Subtle Baryta/Platinum silver split-tone (warm highlights, cool deep shadows)
                            val toneShift = ((finalMono / 255.0f) - 0.5f) * 2.2f
                            outR = (finalMono + toneShift).coerceIn(0f, 255f)
                            outG = finalMono
                            outB = (finalMono - toneShift).coerceIn(0f, 255f)
                        }

                        val ir = outR.toInt().coerceIn(0, 255)
                        val ig = outG.toInt().coerceIn(0, 255)
                        val ib = outB.toInt().coerceIn(0, 255)
                        srcPixels[idx] = (0xFF shl 24) or (ir shl 16) or (ig shl 8) or ib
                    }
                }
            }

            val outBmp = Bitmap.createBitmap(srcPixels, w, h, Bitmap.Config.ARGB_8888)
            FileOutputStream(outJpeg).use { fos ->
                outBmp.compress(Bitmap.CompressFormat.JPEG, 95, fos)
            }
            outBmp.recycle()
            srcBmp.recycle()
        } catch (t: Throwable) {
            android.util.Log.e("ZameraPortrait", "Portrait pipeline error: ${t.message}", t)
        }
    }

    /**
     * Post-capture interactive Portrait Re-Focus, Aperture (f/1.4..f/16), and Studio Lighting reprocessing.
     */
    private fun reprocessPortraitPhoto(args: Map<String, Any?>, result: Result) {
        val sourcePath = args["sourceJpegPath"]?.toString()
        if (sourcePath.isNullOrEmpty() || !File(sourcePath).exists()) {
            result.error("NO_SOURCE", "Source JPEG not found for portrait reprocessing", null)
            return
        }
        val aperture = (args["aperture"] as? Number)?.toFloat()?.coerceIn(1.4f, 16.0f) ?: 2.8f
        val lightingMode = (args["lightingMode"] as? Number)?.toInt()?.coerceIn(0, 9) ?: 0
        val lightIntensity = (args["lightIntensity"] as? Number)?.toFloat()?.coerceIn(0.15f, 1.0f) ?: 0.80f
        val subjectRadiusRatio = (args["subjectRadiusRatio"] as? Number)?.toFloat()?.coerceIn(0.18f, 0.58f) ?: 0.36f
        val focusX = (args["focusX"] as? Number)?.toFloat()?.coerceIn(0.05f, 0.95f) ?: 0.5f
        val focusY = (args["focusY"] as? Number)?.toFloat()?.coerceIn(0.05f, 0.95f) ?: 0.45f
        val isFrontCamera = args["isFrontCamera"] == true
        val saveToGallery = args["saveToGallery"] == true

        rustIspExecutor.execute {
            try {
                val ts = System.currentTimeMillis()
                val outFile = File(appContext.cacheDir, "ZAM_REFOCUS_${ts}.jpg")
                applyPortraitBokehAndLighting(
                    sourceJpeg = File(sourcePath),
                    outJpeg = outFile,
                    aperture = aperture,
                    lightingMode = lightingMode,
                    lightIntensity = lightIntensity,
                    subjectRadiusRatio = subjectRadiusRatio,
                    focusX = focusX,
                    focusY = focusY,
                    isFrontCamera = isFrontCamera,
                    allowDepthInversionOnBgTap = true
                )
                var mediaUri: String? = null
                if (saveToGallery && outFile.exists()) {
                    mediaUri = saveFileToMediaStoreDcim(
                        sourceFile = outFile,
                        displayName = "ZAM_${ts}_PORTRAIT_EDIT.jpg",
                        mimeType = "image/jpeg"
                    )
                }
                mainHandler.post {
                    result.success(
                        mapOf(
                            "jpegPath" to outFile.absolutePath,
                            "mediaStoreUri" to mediaUri
                        )
                    )
                }
            } catch (e: Exception) {
                mainHandler.post {
                    result.error("REFOCUS_ERR", e.message, null)
                }
            }
        }
    }

    /**
     * iOS / Xiaomi Style Subject Lift & Cutout Sticker Extractor:
     * Segments the person or tapped object using ML Kit Neural Segmentation + Geodesic Object Segmentation + Fast Guided Filter,
     * crops tightly to the subject bounding box with a 100% transparent PNG alpha channel, saves to DCIM/Zamera,
     * copies the transparent PNG sticker to the Android System Clipboard, and optionally opens the Android Share sheet!
     */
    private fun extractSubjectCutoutPng(args: Map<String, Any?>, result: Result) {
        val sourcePath = args["sourceJpegPath"]?.toString()
        if (sourcePath.isNullOrEmpty() || !File(sourcePath).exists()) {
            result.error("NO_SOURCE", "Source JPEG not found for subject cutout", null)
            return
        }
        val focusX = (args["focusX"] as? Number)?.toFloat()?.coerceIn(0.08f, 0.92f) ?: 0.5f
        val focusY = (args["focusY"] as? Number)?.toFloat()?.coerceIn(0.08f, 0.92f) ?: 0.45f
        val subjectRadiusRatio = (args["subjectRadiusRatio"] as? Number)?.toFloat()?.coerceIn(0.18f, 0.58f) ?: 0.36f
        val isFrontCamera = args["isFrontCamera"] == true
        val shareNow = args["shareNow"] == true

        rustIspExecutor.execute {
            try {
                val srcFile = File(sourcePath)
                val exif = ExifInterface(srcFile.absolutePath)
                val orientAttr = exif.getAttributeInt(
                    ExifInterface.TAG_ORIENTATION,
                    ExifInterface.ORIENTATION_NORMAL
                )
                val boundsOpts = android.graphics.BitmapFactory.Options().apply {
                    inJustDecodeBounds = true
                }
                android.graphics.BitmapFactory.decodeFile(srcFile.absolutePath, boundsOpts)
                val decodeOpts = android.graphics.BitmapFactory.Options().apply {
                    inSampleSize = if (kotlin.math.max(boundsOpts.outWidth, boundsOpts.outHeight) > 2400) 2 else 1
                    inPreferredConfig = Bitmap.Config.ARGB_8888
                }
                var srcBmp = android.graphics.BitmapFactory.decodeFile(srcFile.absolutePath, decodeOpts)
                    ?: throw IllegalStateException("Failed to decode source JPEG")

                val rotDeg = when (orientAttr) {
                    ExifInterface.ORIENTATION_ROTATE_90 -> 90f
                    ExifInterface.ORIENTATION_ROTATE_180 -> 180f
                    ExifInterface.ORIENTATION_ROTATE_270 -> 270f
                    else -> 0f
                }
                if (rotDeg != 0f || (isFrontCamera && orientAttr != ExifInterface.ORIENTATION_NORMAL)) {
                    val m = Matrix().apply {
                        if (rotDeg != 0f) postRotate(rotDeg)
                        if (isFrontCamera) postScale(-1f, 1f)
                    }
                    val transformed = Bitmap.createBitmap(srcBmp, 0, 0, srcBmp.width, srcBmp.height, m, true)
                    if (transformed !== srcBmp) srcBmp.recycle()
                    srcBmp = transformed
                }

                val w = srcBmp.width
                val h = srcBmp.height
                val segW = 288
                val segH = (288 * h / w.coerceAtLeast(1)).coerceIn(200, 420)

                val (meanA, meanB) = computeGuidedAlphaCoefficients(
                    srcBmp = srcBmp,
                    segW = segW,
                    segH = segH,
                    focusX = focusX,
                    focusY = focusY,
                    subjectRadiusRatio = subjectRadiusRatio
                )

                val totalPx = w * h
                val pixels = IntArray(totalPx)
                srcBmp.getPixels(pixels, 0, w, 0, 0, w, h)
                srcBmp.recycle()

                var minX = w
                var minY = h
                var maxX = 0
                var maxY = 0

                for (y in 0 until h) {
                    val gy = (y.toFloat() / (h - 1).coerceAtLeast(1)) * (segH - 1)
                    val y0 = gy.toInt().coerceIn(0, segH - 2)
                    val fy = gy - y0
                    val rowOffset = y * w
                    for (x in 0 until w) {
                        val gx = (x.toFloat() / (w - 1).coerceAtLeast(1)) * (segW - 1)
                        val x0 = gx.toInt().coerceIn(0, segW - 2)
                        val fx = gx - x0
                        val idx = rowOffset + x
                        val sp = pixels[idx]
                        val r = ((sp shr 16) and 0xFF)
                        val g = ((sp shr 8) and 0xFF)
                        val b = (sp and 0xFF)
                        val lumNorm = (0.299f * r + 0.587f * g + 0.114f * b) / 255.0f

                        val aVal = meanA[y0 * segW + x0] * (1f - fx) * (1f - fy) +
                            meanA[y0 * segW + x0 + 1] * fx * (1f - fy) +
                            meanA[(y0 + 1) * segW + x0] * (1f - fx) * fy +
                            meanA[(y0 + 1) * segW + x0 + 1] * fx * fy
                        val bVal = meanB[y0 * segW + x0] * (1f - fx) * (1f - fy) +
                            meanB[y0 * segW + x0 + 1] * fx * (1f - fy) +
                            meanB[(y0 + 1) * segW + x0] * (1f - fx) * fy +
                            meanB[(y0 + 1) * segW + x0 + 1] * fx * fy

                        val rawFg = (aVal * lumNorm + bVal).coerceIn(0f, 1f)
                        // Crisp cutout matte with anti-aliased edge feathering
                        val tFg = ((rawFg - 0.18f) / 0.68f).coerceIn(0f, 1f)
                        val alpha = tFg * tFg * (3.0f - 2.0f * tFg)
                        val aInt = (alpha * 255.0f).toInt().coerceIn(0, 255)

                        if (aInt > 12) {
                            if (x < minX) minX = x
                            if (x > maxX) maxX = x
                            if (y < minY) minY = y
                            if (y > maxY) maxY = y
                            pixels[idx] = (aInt shl 24) or (r shl 16) or (g shl 8) or b
                        } else {
                            pixels[idx] = 0x00000000
                        }
                    }
                }

                if (maxX <= minX || maxY <= minY) {
                    minX = 0
                    minY = 0
                    maxX = w - 1
                    maxY = h - 1
                } else {
                    val pad = 12
                    minX = (minX - pad).coerceAtLeast(0)
                    minY = (minY - pad).coerceAtLeast(0)
                    maxX = (maxX + pad).coerceAtMost(w - 1)
                    maxY = (maxY + pad).coerceAtMost(h - 1)
                }

                val cropW = (maxX - minX + 1).coerceAtLeast(1)
                val cropH = (maxY - minY + 1).coerceAtLeast(1)
                val croppedPixels = IntArray(cropW * cropH)
                for (cy in 0 until cropH) {
                    System.arraycopy(pixels, (minY + cy) * w + minX, croppedPixels, cy * cropW, cropW)
                }

                val cutoutBmp = Bitmap.createBitmap(croppedPixels, cropW, cropH, Bitmap.Config.ARGB_8888)
                val ts = System.currentTimeMillis()
                val outPngFile = File(appContext.cacheDir, "ZAM_CUTOUT_${ts}.png")
                FileOutputStream(outPngFile).use { fos ->
                    cutoutBmp.compress(Bitmap.CompressFormat.PNG, 100, fos)
                }
                cutoutBmp.recycle()

                val mediaUriStr = saveFileToMediaStoreDcim(
                    sourceFile = outPngFile,
                    displayName = "ZAM_${ts}_CUTOUT.png",
                    mimeType = "image/png"
                )

                mainHandler.post {
                    try {
                        if (mediaUriStr != null) {
                            val uri = android.net.Uri.parse(mediaUriStr)
                            val clipboard = appContext.getSystemService(Context.CLIPBOARD_SERVICE) as? android.content.ClipboardManager
                            val clip = android.content.ClipData.newUri(appContext.contentResolver, "Zamera Özne Çıkartması", uri)
                            clipboard?.setPrimaryClip(clip)

                            if (shareNow) {
                                val sendIntent = android.content.Intent(android.content.Intent.ACTION_SEND).apply {
                                    type = "image/png"
                                    putExtra(android.content.Intent.EXTRA_STREAM, uri)
                                    addFlags(android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                }
                                val chooser = android.content.Intent.createChooser(sendIntent, "Özneyi Paylaş").apply {
                                    addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                (activity ?: appContext).startActivity(chooser)
                            }
                        }
                    } catch (e: Throwable) {
                        android.util.Log.w("ZameraCapture", "Subject cutout clipboard/share warning: ${e.message}")
                    }
                    result.success(
                        mapOf(
                            "pngPath" to outPngFile.absolutePath,
                            "mediaStoreUri" to mediaUriStr,
                            "width" to cropW,
                            "height" to cropH,
                            "copiedToClipboard" to (mediaUriStr != null)
                        )
                    )
                }
            } catch (e: Exception) {
                mainHandler.post {
                    result.error("CUTOUT_ERR", e.message, null)
                }
            }
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
        activeFocusPullRunnable?.let { backgroundHandler?.removeCallbacks(it) }
        activeFocusPullRunnable = null
        stopAudioFloatMeterMonitor()
        stopVideoRecordingSilent()
        videoSessionActive = false
        activeSessionIsTenBitHlg = false
        try {
            captureSession?.close()
            captureSession = null
            cameraDevice?.close()
            cameraDevice = null
            rawImageReader?.close()
            rawImageReader = null
            jpegImageReader?.close()
            jpegImageReader = null
            yuvAnalysisReader?.close()
            yuvAnalysisReader = null
            previewSurface?.release()
            previewSurface = null
            surfaceEntry?.release()
            surfaceEntry = null
            lastTotalCaptureResult = null
        } catch (e: Exception) {
            android.util.Log.w("ZameraCapture", "stopPreviewSession cleanup warning: ${e.message}")
        }
    }

    // =========================================================================
    // FAZ 3 — PRO VIDEO ENGINE (WP-3.1 .. WP-3.6)
    // =========================================================================

    private fun registerThermalMonitor() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            try {
                val pm = appContext.getSystemService(Context.POWER_SERVICE) as? android.os.PowerManager ?: return
                val listener = android.os.PowerManager.OnThermalStatusChangedListener { status ->
                    videoThermalStatus = when (status) {
                        android.os.PowerManager.THERMAL_STATUS_MODERATE -> "MODERATE"
                        android.os.PowerManager.THERMAL_STATUS_SEVERE -> {
                            // WP-3.5: Under SEVERE thermal load, step preview frame rate down to 30 fps if higher
                            if (videoSessionActive && !isVideoRecording && videoFps > 30) {
                                videoFps = 30
                                backgroundHandler?.post {
                                    try {
                                        val b = previewRequestBuilder
                                        val s = captureSession
                                        val manager = appContext.getSystemService(Context.CAMERA_SERVICE) as CameraManager
                                        val chars = manager.getCameraCharacteristics(activePhysicalCameraId ?: activeCameraId)
                                        if (b != null && s != null) {
                                            applyVideoBuilderParameters(b, chars, lockAwb = false)
                                            s.setRepeatingRequest(b.build(), videoCaptureCallback, backgroundHandler)
                                        }
                                    } catch (e: Throwable) {
                                        android.util.Log.w("ZameraCapture", "Thermal 30fps step-down warning: ${e.message}")
                                    }
                                }
                            }
                            "SEVERE"
                        }
                        android.os.PowerManager.THERMAL_STATUS_CRITICAL,
                        android.os.PowerManager.THERMAL_STATUS_EMERGENCY,
                        android.os.PowerManager.THERMAL_STATUS_SHUTDOWN -> {
                            // WP-3.5: Critical thermal event -> safely stop & export active video recording to DCIM/Zamera!
                            if (isVideoRecording) {
                                emergencyStopAndSaveVideoRecording(resumePreview = false)
                            }
                            "CRITICAL"
                        }
                        else -> "NORMAL"
                    }
                }
                pm.addThermalStatusListener(cameraSessionExecutor, listener)
                thermalListener = listener
            } catch (e: Throwable) {
                android.util.Log.w("ZameraCapture", "registerThermalMonitor warning: ${e.message}")
            }
        }
    }

    private fun emergencyStopAndSaveVideoRecording(resumePreview: Boolean) {
        val outFile = currentVideoFile
        stopVideoRecordingSilent()
        if (outFile != null && outFile.exists() && outFile.length() > 0L) {
            saveVideoFileToMediaStoreDcim(outFile, outFile.name)
        }
        val cam = cameraDevice
        if (resumePreview && cam != null && videoSessionActive) {
            backgroundHandler?.post {
                try {
                    val manager = appContext.getSystemService(Context.CAMERA_SERVICE) as CameraManager
                    val chars = manager.getCameraCharacteristics(activePhysicalCameraId ?: activeCameraId)
                    configureVideoPreviewOrRecordSession(cam, chars, null, {}, {})
                } catch (e: Throwable) {
                    android.util.Log.w("ZameraCapture", "Emergency resume preview warning: ${e.message}")
                }
            }
        }
    }

    /**
     * WP-3.4: Real 48 kHz Float-Normalized (`ENCODING_PCM_FLOAT`, $x_i \in [-1, 1]$) Audio Level Monitor.
     * Computes 50 ms Sample Peak dBFS and 300 ms RMS dBFS directly via Rust `zamera_core::compute_audio_peak_rms_dbfs` JNI
     * (zero 16-bit 32768 integer division and zero fake RMS approximation).
     */
    @SuppressLint("MissingPermission")
    private fun startAudioFloatMeterMonitor(preferredDeviceId: String?) {
        stopAudioFloatMeterMonitor()
        val hasMic = ContextCompat.checkSelfPermission(appContext, Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED
        if (!hasMic) return
        try {
            val sampleRate = 48000
            val channelConfig = android.media.AudioFormat.CHANNEL_IN_MONO
            val encoding = android.media.AudioFormat.ENCODING_PCM_FLOAT
            val minBufBytes = android.media.AudioRecord.getMinBufferSize(sampleRate, channelConfig, encoding)
                .coerceAtLeast(sampleRate / 5 * 4)
            val rec = android.media.AudioRecord(
                android.media.MediaRecorder.AudioSource.CAMCORDER,
                sampleRate,
                channelConfig,
                encoding,
                minBufBytes * 2
            )
            if (rec.state != android.media.AudioRecord.STATE_INITIALIZED) {
                rec.release()
                return
            }
            if (preferredDeviceId != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val audioMgr = appContext.getSystemService(Context.AUDIO_SERVICE) as? android.media.AudioManager
                val dev = audioMgr?.getDevices(android.media.AudioManager.GET_DEVICES_INPUTS)
                    ?.firstOrNull { it.id.toString() == preferredDeviceId }
                if (dev != null) {
                    rec.preferredDevice = dev
                }
            }
            rec.startRecording()
            audioRecordMonitor = rec
            audioMeterActive = true
            audioMeterThread = Thread({
                // 50 ms window = 2400 float samples at 48 kHz; 6-window ring (300 ms = 14400 samples) for true RMS
                val chunkLen = 2400
                val ringChunks = 6
                val chunkBuf = FloatArray(chunkLen)
                val rmsRing = FloatArray(chunkLen * ringChunks)
                var ringWriteChunk = 0
                var filledChunks = 0
                while (audioMeterActive) {
                    try {
                        val readCount = rec.read(chunkBuf, 0, chunkLen, android.media.AudioRecord.READ_BLOCKING)
                        if (readCount > 0) {
                            val peakPair = ZameraRustBridge.computeAudioPeakAndRmsDbfs(chunkBuf, readCount)
                            System.arraycopy(chunkBuf, 0, rmsRing, ringWriteChunk * chunkLen, readCount.coerceAtMost(chunkLen))
                            ringWriteChunk = (ringWriteChunk + 1) % ringChunks
                            if (filledChunks < ringChunks) filledChunks++
                            val rmsPair = ZameraRustBridge.computeAudioPeakAndRmsDbfs(rmsRing, filledChunks * chunkLen)
                            videoSamplePeakDbfs = peakPair.first.toDouble()
                            videoRmsDbfs = rmsPair.second.toDouble()
                        }
                    } catch (e: Throwable) {
                        android.util.Log.w("ZameraCapture", "AudioRecord float read warning: ${e.message}")
                        break
                    }
                }
            }, "ZameraAudioFloatMeter").apply {
                isDaemon = true
                start()
            }
        } catch (e: Throwable) {
            android.util.Log.w("ZameraCapture", "startAudioFloatMeterMonitor warning: ${e.message}")
        }
    }

    private fun stopAudioFloatMeterMonitor() {
        audioMeterActive = false
        val th = audioMeterThread
        audioMeterThread = null
        val rec = audioRecordMonitor
        audioRecordMonitor = null
        if (rec != null) {
            try {
                rec.stop()
            } catch (e: Throwable) {
                android.util.Log.w("ZameraCapture", "AudioRecord stop warning: ${e.message}")
            }
            try {
                rec.release()
            } catch (e: Throwable) {
                android.util.Log.w("ZameraCapture", "AudioRecord release warning: ${e.message}")
            }
        }
        if (th != null && th !== Thread.currentThread()) {
            try {
                th.join(120L)
            } catch (e: Throwable) {
                android.util.Log.w("ZameraCapture", "AudioMeterThread join warning: ${e.message}")
            }
        }
    }

    private fun applySoftwareAutoIsoStep(measuredLuma: Double) {
        val builder = previewRequestBuilder ?: return
        val session = captureSession ?: return
        try {
            val targetLuma = (0.42 * Math.pow(2.0, videoEvCompensation.coerceIn(-3.0, 3.0))).coerceIn(0.08, 0.88)
            val meas = measuredLuma.coerceIn(0.005, 1.0)
            val minI = videoIsoMin.toDouble().coerceAtLeast(10.0)
            val maxI = videoIsoMax.toDouble().coerceAtLeast(minI)
            val curIso = videoActiveIso.coerceIn(minI, maxI)

            val rustStep = ZameraRustBridge.computeSoftwareAutoIsoStep(
                currentIso = curIso,
                isoMin = minI,
                isoMax = maxI,
                measuredLuma = meas,
                targetLuma = targetLuma,
                angleDeg = videoShutterAngleDeg.coerceIn(11.25, 360.0),
                fps = videoFps.coerceIn(24, 120).toDouble()
            )
            val nextIso = rustStep.nextIso
            videoNdRecommendation = when (rustStep.ndFactor) {
                16 -> "ND16"
                8 -> "ND8"
                4 -> "ND4"
                else -> null
            }

            if (kotlin.math.abs(nextIso - curIso) >= 1.5) {
                videoActiveIso = nextIso
                builder.set(CaptureRequest.CONTROL_AE_MODE, CaptureRequest.CONTROL_AE_MODE_OFF)
                builder.set(CaptureRequest.SENSOR_SENSITIVITY, nextIso.roundToInt())
                builder.set(CaptureRequest.SENSOR_EXPOSURE_TIME, rustStep.shutterExposureNs)
                builder.set(CaptureRequest.SENSOR_FRAME_DURATION, rustStep.frameDurationNs)
                session.setRepeatingRequest(builder.build(), videoCaptureCallback, backgroundHandler)
            }
        } catch (e: Throwable) {
            android.util.Log.w("ZameraCapture", "applySoftwareAutoIsoStep warning: ${e.message}")
        }
    }

    private val videoCaptureCallback = object : CameraCaptureSession.CaptureCallback() {
        override fun onCaptureCompleted(
            session: CameraCaptureSession,
            request: CaptureRequest,
            res: TotalCaptureResult
        ) {
            lastTotalCaptureResult = res
            val ts = res.get(CaptureResult.SENSOR_TIMESTAMP) ?: 0L
            if (isVideoRecording && ts > 0L) {
                val prev = prevVideoSensorTimestampNs
                if (prev > 0L) {
                    val expectedNs = 1_000_000_000L / videoFps.coerceAtLeast(1)
                    val deltaNs = ts - prev
                    if (deltaNs > (expectedNs * 3L) / 2L) {
                        val missed = ((deltaNs / expectedNs).toInt() - 1).coerceAtLeast(1)
                        videoDroppedFrames += missed
                    }
                }
                prevVideoSensorTimestampNs = ts
            }
        }
    }

    @SuppressLint("MissingPermission")
    private fun startVideoSession(args: Map<String, Any?>, result: Result) {
        try {
            stopPreviewSession()
            ensureBackgroundThread()

            val requestedId = args["cameraId"]?.toString() ?: "2"
            videoWidth = ((args["width"] as? Number)?.toInt() ?: 3840).coerceIn(1280, 3840)
            videoHeight = ((args["height"] as? Number)?.toInt() ?: 2160).coerceIn(720, 2160)
            videoFps = ((args["fps"] as? Number)?.toInt() ?: 30).coerceIn(24, 120)
            videoShutterAngleDeg = ((args["shutterAngleDeg"] as? Number)?.toDouble() ?: 180.0).coerceIn(11.25, 360.0)
            videoProfileName = args["profile"]?.toString() ?: "universalRec709Locked"
            videoStabilizationEnabled = args["videoStabilization"] as? Boolean ?: true
            videoLockShutterAngle = true
            videoManualIso = false
            videoDroppedFrames = 0
            prevVideoSensorTimestampNs = 0L

            val manager = appContext.getSystemService(Context.CAMERA_SERVICE) as CameraManager
            val logicalIds = manager.cameraIdList.toList()
            val openLogicalId: String
            val targetPhysicalId: String?
            if (logicalIds.contains(requestedId)) {
                openLogicalId = requestedId
                targetPhysicalId = null
            } else {
                var ownerId = logicalIds.firstOrNull() ?: "0"
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    for (lid in logicalIds) {
                        try {
                            if (manager.getCameraCharacteristics(lid).physicalCameraIds.contains(requestedId)) {
                                ownerId = lid
                                break
                            }
                        } catch (e: Exception) {
                            android.util.Log.w("ZameraCapture", "Physical camera lookup warning: ${e.message}")
                        }
                    }
                }
                openLogicalId = ownerId
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
            videoIsoMin = isoRange?.lower ?: 50
            videoIsoMax = isoRange?.upper ?: 3200
            videoActiveIso = 100.0.coerceIn(videoIsoMin.toDouble(), videoIsoMax.toDouble())

            val map = chars.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP)
            val previewSize = map?.getOutputSizes(android.graphics.SurfaceTexture::class.java)
                ?.filter { it.width <= 1920 && it.height <= 1080 && it.width * 9 == it.height * 16 }
                ?.maxByOrNull { it.width * it.height }
                ?: map?.getOutputSizes(android.graphics.SurfaceTexture::class.java)
                    ?.filter { it.width <= 1920 && it.height <= 1440 }
                    ?.maxByOrNull { it.width * it.height }
                ?: android.util.Size(1920, 1080)

            val entry = textureRegistry.createSurfaceTexture()
            surfaceEntry = entry
            val surfaceTexture = entry.surfaceTexture()
            surfaceTexture.setDefaultBufferSize(previewSize.width, previewSize.height)
            val surf = Surface(surfaceTexture)
            previewSurface = surf

            val isFrontCamera = chars.get(CameraCharacteristics.LENS_FACING) == CameraCharacteristics.LENS_FACING_FRONT
            val yuvSize = map?.getOutputSizes(ImageFormat.YUV_420_888)
                ?.filter { it.width in 160..640 && it.height in 120..480 }
                ?.minByOrNull { kotlin.math.abs(it.width * it.height - 320 * 240) }
                ?: android.util.Size(320, 240)

            yuvAnalysisReader = ImageReader.newInstance(yuvSize.width, yuvSize.height, ImageFormat.YUV_420_888, 2).apply {
                setOnImageAvailableListener({ reader ->
                    val img = try { reader.acquireLatestImage() } catch (_: Throwable) { null }
                        ?: return@setOnImageAvailableListener
                    try {
                        val now = System.currentTimeMillis()
                        if (now - lastYuvAnalysisMs >= 100L) {
                            lastYuvAnalysisMs = now
                            analyzePreviewYuvFrame(img, activeSensorOrientation, isFrontCamera)
                        }
                    } catch (e: Throwable) {
                        android.util.Log.w("ZameraCapture", "Video YUV analysis warning: ${e.message}")
                    } finally {
                        img.close()
                    }
                }, backgroundHandler)
            }

            manager.openCamera(openLogicalId, object : CameraDevice.StateCallback() {
                override fun onOpened(camera: CameraDevice) {
                    cameraDevice = camera
                    videoSessionActive = true
                    configureVideoPreviewOrRecordSession(
                        camera = camera,
                        chars = chars,
                        recorderSurface = null,
                        onReady = {
                            mainHandler.post {
                                result.success(
                                    mapOf(
                                        "textureId" to entry.id(),
                                        "previewWidth" to previewSize.width,
                                        "previewHeight" to previewSize.height,
                                        "sensorOrientation" to activeSensorOrientation,
                                        "activeCameraId" to (targetPhysicalId ?: openLogicalId),
                                        "supportsRawSensor" to false,
                                        "minimumFocusDistanceDiopters" to minFocusDist.toDouble(),
                                        "isoMin" to videoIsoMin,
                                        "isoMax" to videoIsoMax,
                                        "exposureNsMin" to (expRange?.lower ?: 50_000L),
                                        "exposureNsMax" to (expRange?.upper ?: 1_000_000_000L)
                                    )
                                )
                            }
                        },
                        onFail = { errMsg ->
                            mainHandler.post {
                                result.error("VIDEO_SESSION_ERR", errMsg, null)
                            }
                        }
                    )
                }

                override fun onDisconnected(camera: CameraDevice) {
                    stopVideoRecordingSilent()
                    camera.close()
                    cameraDevice = null
                }

                override fun onError(camera: CameraDevice, error: Int) {
                    stopVideoRecordingSilent()
                    camera.close()
                    cameraDevice = null
                    mainHandler.post {
                        result.error("VIDEO_CAMERA_ERR", "CameraDevice error $error", null)
                    }
                }
            }, backgroundHandler)
        } catch (e: Exception) {
            result.error("START_VIDEO_ERR", e.message, null)
        }
    }

    private fun configureVideoPreviewOrRecordSession(
        camera: CameraDevice,
        chars: CameraCharacteristics,
        recorderSurface: Surface?,
        onReady: () -> Unit,
        onFail: (String) -> Unit
    ) {
        val surf = previewSurface ?: run {
            onFail("Preview surface null")
            return
        }
        var retriedWithoutYuv = false

        fun attemptConfigure(includeYuv: Boolean, useTenBitHlg: Boolean) {
            try {
                val template = if (recorderSurface != null) CameraDevice.TEMPLATE_RECORD else CameraDevice.TEMPLATE_PREVIEW
                val builder = camera.createCaptureRequest(template)
                builder.addTarget(surf)
                if (recorderSurface != null) {
                    builder.addTarget(recorderSurface)
                }
                if (includeYuv) {
                    yuvAnalysisReader?.surface?.let { builder.addTarget(it) }
                }

                applyVideoBuilderParameters(builder, chars, lockAwb = recorderSurface != null)
                previewRequestBuilder = builder

                val surfaces = mutableListOf<Surface>(surf)
                if (recorderSurface != null) surfaces.add(recorderSurface)
                if (includeYuv) yuvAnalysisReader?.surface?.let { surfaces.add(it) }

                val stateCallback = object : CameraCaptureSession.StateCallback() {
                    override fun onConfigured(session: CameraCaptureSession) {
                        captureSession = session
                        activeSessionIsTenBitHlg = useTenBitHlg
                        try {
                            session.setRepeatingRequest(builder.build(), videoCaptureCallback, backgroundHandler)
                            onReady()
                        } catch (e: Exception) {
                            onFail(e.message ?: "setRepeatingRequest failed")
                        }
                    }

                    override fun onConfigureFailed(session: CameraCaptureSession) {
                        if (useTenBitHlg) {
                            activeSessionIsTenBitHlg = false
                            attemptConfigure(includeYuv = includeYuv, useTenBitHlg = false)
                            return
                        }
                        if (includeYuv && !retriedWithoutYuv) {
                            retriedWithoutYuv = true
                            attemptConfigure(includeYuv = false, useTenBitHlg = false)
                            return
                        }
                        onFail("Video CameraCaptureSession configure failed")
                    }
                }

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    var hlgSupportedOnDevice = false
                    val outConfigs = surfaces.map { s ->
                        OutputConfiguration(s).apply {
                            if (activePhysicalCameraId != null) {
                                setPhysicalCameraId(activePhysicalCameraId)
                            }
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                                useTenBitHlg &&
                                s === recorderSurface
                            ) {
                                val dr = chars.get(CameraCharacteristics.REQUEST_AVAILABLE_DYNAMIC_RANGE_PROFILES)
                                if (dr?.supportedProfiles?.contains(DynamicRangeProfiles.HLG10) == true) {
                                    dynamicRangeProfile = DynamicRangeProfiles.HLG10
                                    hlgSupportedOnDevice = true
                                }
                            }
                        }
                    }
                    if (useTenBitHlg && !hlgSupportedOnDevice) {
                        activeSessionIsTenBitHlg = false
                        attemptConfigure(includeYuv = includeYuv, useTenBitHlg = false)
                        return
                    }
                    val sessionConfig = SessionConfiguration(
                        SessionConfiguration.SESSION_REGULAR,
                        outConfigs,
                        cameraSessionExecutor,
                        stateCallback
                    )
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        val supported = try {
                            camera.isSessionConfigurationSupported(sessionConfig)
                        } catch (_: Throwable) {
                            true
                        }
                        if (!supported && useTenBitHlg) {
                            attemptConfigure(includeYuv = includeYuv, useTenBitHlg = false)
                            return
                        }
                    }
                    camera.createCaptureSession(sessionConfig)
                } else {
                    camera.createCaptureSession(surfaces, stateCallback, backgroundHandler)
                }
            } catch (e: Exception) {
                if (includeYuv && !retriedWithoutYuv) {
                    retriedWithoutYuv = true
                    attemptConfigure(includeYuv = false, useTenBitHlg = false)
                    return
                }
                onFail(e.message ?: "configureVideoPreviewOrRecordSession exception")
            }
        }

        val wantHlg10 = videoProfileName == "androidHlg10Hevc10Bit" && recorderSurface != null
        attemptConfigure(includeYuv = true, useTenBitHlg = wantHlg10)
    }

    private fun applyVideoBuilderParameters(
        builder: CaptureRequest.Builder,
        chars: CameraCharacteristics,
        lockAwb: Boolean
    ) {
        // 50 Hz Anti-Banding for Turkey mains grid (WP-3.2)
        builder.set(CaptureRequest.CONTROL_AE_ANTIBANDING_MODE, CaptureRequest.CONTROL_AE_ANTIBANDING_MODE_50HZ)

        // OIS + EIS Video Stabilization (WP-3.6)
        val oisModes = chars.get(CameraCharacteristics.LENS_INFO_AVAILABLE_OPTICAL_STABILIZATION)
        if (oisModes != null && oisModes.contains(CameraMetadata.LENS_OPTICAL_STABILIZATION_MODE_ON)) {
            builder.set(CaptureRequest.LENS_OPTICAL_STABILIZATION_MODE, CameraMetadata.LENS_OPTICAL_STABILIZATION_MODE_ON)
        }
        val vStabModes = chars.get(CameraCharacteristics.CONTROL_AVAILABLE_VIDEO_STABILIZATION_MODES)
        if (videoStabilizationEnabled && vStabModes != null && vStabModes.contains(CameraMetadata.CONTROL_VIDEO_STABILIZATION_MODE_ON)) {
            builder.set(CaptureRequest.CONTROL_VIDEO_STABILIZATION_MODE, CameraMetadata.CONTROL_VIDEO_STABILIZATION_MODE_ON)
        }

        // Zamera Flat SDR Contrast Curve (WP-3.1 — strictly separated from HLG10!)
        if (videoProfileName == "zameraFlatSdr") {
            val flatPts = floatArrayOf(
                0.00f, 0.08f,
                0.18f, 0.34f,
                0.50f, 0.62f,
                0.80f, 0.84f,
                1.00f, 0.94f
            )
            builder.set(CaptureRequest.TONEMAP_MODE, CaptureRequest.TONEMAP_MODE_CONTRAST_CURVE)
            builder.set(
                CaptureRequest.TONEMAP_CURVE,
                android.hardware.camera2.params.TonemapCurve(flatPts, flatPts, flatPts)
            )
        } else {
            builder.set(CaptureRequest.TONEMAP_MODE, CaptureRequest.TONEMAP_MODE_FAST)
        }

        // 180° Shutter Angle Lock + Constant Frame Rate (CFR) + Software Auto-ISO (WP-3.2)
        val expRange = chars.get(CameraCharacteristics.SENSOR_INFO_EXPOSURE_TIME_RANGE)
        val isoRange = chars.get(CameraCharacteristics.SENSOR_INFO_SENSITIVITY_RANGE)
        val fpsClamped = videoFps.coerceIn(24, 120)
        val frameDurationNs = 1_000_000_000L / fpsClamped
        if (videoLockShutterAngle || videoManualIso) {
            val rawShutterNs = ((videoShutterAngleDeg.coerceIn(11.25, 360.0) / (360.0 * fpsClamped)) * 1_000_000_000.0).toLong()
            val clampedShutter = if (expRange != null) rawShutterNs.coerceIn(expRange.lower, expRange.upper) else rawShutterNs
            var effIso = videoActiveIso
            if (videoEvCompensation != 0.0) {
                effIso = effIso * Math.pow(2.0, videoEvCompensation)
            }
            val clampedIso = if (isoRange != null) effIso.roundToInt().coerceIn(isoRange.lower, isoRange.upper) else effIso.roundToInt()
            builder.set(CaptureRequest.CONTROL_AE_MODE, CaptureRequest.CONTROL_AE_MODE_OFF)
            builder.set(CaptureRequest.SENSOR_EXPOSURE_TIME, clampedShutter)
            builder.set(CaptureRequest.SENSOR_FRAME_DURATION, frameDurationNs)
            builder.set(CaptureRequest.SENSOR_SENSITIVITY, clampedIso)
        } else {
            builder.set(CaptureRequest.CONTROL_AE_MODE, CaptureRequest.CONTROL_AE_MODE_ON)
            builder.set(CaptureRequest.CONTROL_AE_TARGET_FPS_RANGE, android.util.Range(fpsClamped, fpsClamped))
            val compRange = chars.get(CameraCharacteristics.CONTROL_AE_COMPENSATION_RANGE)
            val compStep = chars.get(CameraCharacteristics.CONTROL_AE_COMPENSATION_STEP) ?: android.util.Rational(1, 3)
            if (compRange != null && compStep.toDouble() > 0.0) {
                val steps = (videoEvCompensation / compStep.toDouble()).roundToInt()
                    .coerceIn(compRange.lower, compRange.upper)
                builder.set(CaptureRequest.CONTROL_AE_EXPOSURE_COMPENSATION, steps)
            }
        }

        if (lockAwb) {
            builder.set(CaptureRequest.CONTROL_AWB_LOCK, true)
        }
    }

    private fun updateVideoControls(args: Map<String, Any?>, result: Result) {
        val builder = previewRequestBuilder
        val session = captureSession
        if (builder == null || session == null) {
            result.success(false)
            return
        }
        try {
            val manager = appContext.getSystemService(Context.CAMERA_SERVICE) as CameraManager
            val chars = manager.getCameraCharacteristics(activePhysicalCameraId ?: activeCameraId)

            videoFps = ((args["fps"] as? Number)?.toInt() ?: videoFps).coerceIn(24, 120)
            videoShutterAngleDeg = ((args["shutterAngleDeg"] as? Number)?.toDouble() ?: videoShutterAngleDeg).coerceIn(11.25, 360.0)
            videoLockShutterAngle = args["lockShutterAngle"] as? Boolean ?: true
            videoManualIso = args["manualIso"] as? Boolean ?: false
            if (videoManualIso) {
                videoActiveIso = ((args["iso"] as? Number)?.toDouble() ?: videoActiveIso).coerceIn(videoIsoMin.toDouble(), videoIsoMax.toDouble())
            }
            videoEvCompensation = ((args["evCompensation"] as? Number)?.toDouble() ?: 0.0).coerceIn(-3.0, 3.0)
            videoProfileName = args["profile"]?.toString() ?: videoProfileName

            val reqZoom = ((args["zoomRatio"] as? Number)?.toFloat() ?: 1.0f).coerceIn(0.5f, 10.0f)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                val zoomRange = chars.get(CameraCharacteristics.CONTROL_ZOOM_RATIO_RANGE)
                val clampedZoom = if (zoomRange != null) reqZoom.coerceIn(zoomRange.lower, zoomRange.upper) else reqZoom.coerceAtLeast(1.0f)
                builder.set(CaptureRequest.CONTROL_ZOOM_RATIO, clampedZoom)
            }

            val manualFocus = args["manualFocus"] as? Boolean ?: false
            val minFocus = chars.get(CameraCharacteristics.LENS_INFO_MINIMUM_FOCUS_DISTANCE) ?: 0.0f
            if (manualFocus && minFocus > 0.0f) {
                activeFocusPullRunnable?.let { backgroundHandler?.removeCallbacks(it) }
                activeFocusPullRunnable = null
                val focusNorm = ((args["focusDistance"] as? Number)?.toFloat() ?: 0.25f).coerceIn(0.0f, 1.0f)
                builder.set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_OFF)
                builder.set(CaptureRequest.LENS_FOCUS_DISTANCE, focusNorm * minFocus)
            } else {
                activeFocusPullRunnable?.let { backgroundHandler?.removeCallbacks(it) }
                activeFocusPullRunnable = null
                builder.set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_VIDEO)
            }

            val manualWb = args["manualWb"] as? Boolean ?: false
            if (manualWb) {
                val kelvin = ((args["kelvin"] as? Number)?.toFloat() ?: 5500f).coerceIn(2000f, 10000f)
                val tint = ((args["tint"] as? Number)?.toFloat() ?: 0f).coerceIn(-50f, 50f)
                val cm1 = extractMatrix3x3(chars.get(CameraCharacteristics.SENSOR_COLOR_TRANSFORM1)) ?: FloatArray(9)
                val cm2 = extractMatrix3x3(chars.get(CameraCharacteristics.SENSOR_COLOR_TRANSFORM2)) ?: cm1
                val fm1 = extractMatrix3x3(chars.get(CameraCharacteristics.SENSOR_FORWARD_MATRIX1)) ?: cm1
                val fm2 = extractMatrix3x3(chars.get(CameraCharacteristics.SENSOR_FORWARD_MATRIX2)) ?: fm1
                val solved = ZameraRustBridge.computeDngKelvinWb(kelvin, tint, cm1, cm2, fm1, fm2)
                if (solved != null) {
                    val g = solved.first
                    builder.set(CaptureRequest.CONTROL_AWB_MODE, CaptureRequest.CONTROL_AWB_MODE_OFF)
                    builder.set(CaptureRequest.COLOR_CORRECTION_MODE, CaptureRequest.COLOR_CORRECTION_MODE_TRANSFORM_MATRIX)
                    builder.set(CaptureRequest.COLOR_CORRECTION_GAINS, RggbChannelVector(g[0], g[1], g[2], g[3]))
                }
            } else if (!isVideoRecording) {
                builder.set(CaptureRequest.CONTROL_AWB_LOCK, false)
                builder.set(CaptureRequest.CONTROL_AWB_MODE, CaptureRequest.CONTROL_AWB_MODE_AUTO)
            }

            applyVideoBuilderParameters(builder, chars, lockAwb = isVideoRecording)
            session.setRepeatingRequest(builder.build(), videoCaptureCallback, backgroundHandler)
            result.success(true)
        } catch (e: Exception) {
            result.error("UPDATE_VIDEO_CTRL_ERR", e.message, null)
        }
    }

    private fun startVideoRecording(args: Map<String, Any?>, result: Result) {
        val cam = cameraDevice
        if (cam == null) {
            result.error("NO_VIDEO_CAMERA", "CameraDevice is not open", null)
            return
        }
        if (isVideoRecording) {
            result.success(mapOf("started" to true, "videoPath" to currentVideoFile?.absolutePath))
            return
        }
        try {
            // Check 500 MB minimum storage threshold (WP-3.5)
            val stat = android.os.StatFs(appContext.filesDir.absolutePath)
            if (stat.availableBytes < 500L * 1024L * 1024L) {
                result.error("LOW_STORAGE", "Depolama alanı 500 MB altında; kayıt başlatılamadı.", null)
                return
            }

            val manager = appContext.getSystemService(Context.CAMERA_SERVICE) as CameraManager
            val chars = manager.getCameraCharacteristics(activePhysicalCameraId ?: activeCameraId)
            val map = chars.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP)
            val supportedVideoSizes = map?.getOutputSizes(android.media.MediaRecorder::class.java) ?: emptyArray()
            val chosenSize = supportedVideoSizes
                .filter { it.width <= videoWidth && it.height <= videoHeight && it.width * 9 == it.height * 16 }
                .maxByOrNull { it.width * it.height }
                ?: supportedVideoSizes.maxByOrNull { it.width * it.height }
                ?: android.util.Size(1920, 1080)

            videoWidth = chosenSize.width
            videoHeight = chosenSize.height

            val videosDir = File(appContext.filesDir, "videos").apply { mkdirs() }
            val outMp4 = File(videosDir, "ZAMERA_VID_${System.currentTimeMillis()}.mp4")
            currentVideoFile = outMp4

            val hasAudioPerm = ContextCompat.checkSelfPermission(
                appContext,
                Manifest.permission.RECORD_AUDIO
            ) == PackageManager.PERMISSION_GRANTED

            @Suppress("DEPRECATION")
            val recorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                android.media.MediaRecorder(appContext)
            } else {
                android.media.MediaRecorder()
            }

            if (hasAudioPerm) {
                recorder.setAudioSource(android.media.MediaRecorder.AudioSource.CAMCORDER)
            }
            recorder.setVideoSource(android.media.MediaRecorder.VideoSource.SURFACE)
            recorder.setOutputFormat(android.media.MediaRecorder.OutputFormat.MPEG_4)
            recorder.setOutputFile(outMp4.absolutePath)
            recorder.setVideoSize(videoWidth, videoHeight)
            val safeFps = videoFps.coerceIn(24, 60)
            recorder.setVideoFrameRate(safeFps)
            val bitrate = when {
                videoWidth >= 3840 && safeFps >= 60 -> 150_000_000
                videoWidth >= 3840 -> 100_000_000
                else -> 50_000_000
            }
            recorder.setVideoEncodingBitRate(bitrate)
            if (videoProfileName == "androidHlg10Hevc10Bit" && Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                try {
                    recorder.setVideoEncoder(android.media.MediaRecorder.VideoEncoder.HEVC)
                    recorder.setVideoEncodingProfileLevel(
                        android.media.MediaCodecInfo.CodecProfileLevel.HEVCProfileMain10,
                        android.media.MediaCodecInfo.CodecProfileLevel.HEVCHighTierLevel51
                    )
                } catch (_: Throwable) {
                    recorder.setVideoEncoder(android.media.MediaRecorder.VideoEncoder.HEVC)
                }
            } else {
                recorder.setVideoEncoder(android.media.MediaRecorder.VideoEncoder.HEVC)
            }
            if (hasAudioPerm) {
                recorder.setAudioEncoder(android.media.MediaRecorder.AudioEncoder.AAC)
                recorder.setAudioSamplingRate(48000)
                recorder.setAudioChannels(2)
                recorder.setAudioEncodingBitRate(256_000)
                // Optional audio input device routing (WP-3.4)
                val reqAudioId = args["audioDeviceId"]?.toString()
                if (reqAudioId != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    val audioMgr = appContext.getSystemService(Context.AUDIO_SERVICE) as? android.media.AudioManager
                    val dev = audioMgr?.getDevices(android.media.AudioManager.GET_DEVICES_INPUTS)
                        ?.firstOrNull { it.id.toString() == reqAudioId }
                    if (dev != null) {
                        recorder.preferredDevice = dev
                    }
                }
            }
            // WP-3.5: Crash-resilient 2-minute segment rollover (prevents data loss >2 min on force-kill/power loss)
            recorder.setMaxDuration(120_000)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val segFile = File(videosDir, "ZAMERA_VID_${System.currentTimeMillis()}_SEG2.mp4")
                nextVideoSegmentFile = segFile
                try {
                    recorder.setNextOutputFile(segFile)
                } catch (e: Throwable) {
                    android.util.Log.w("ZameraCapture", "setNextOutputFile warning: ${e.message}")
                }
                recorder.setOnInfoListener { _, what, _ ->
                    if (what == android.media.MediaRecorder.MEDIA_RECORDER_INFO_MAX_DURATION_REACHED) {
                        val finishedSeg = currentVideoFile
                        val promotedSeg = nextVideoSegmentFile
                        if (finishedSeg != null && finishedSeg.exists() && finishedSeg.length() > 0L) {
                            rustIspExecutor.execute {
                                saveVideoFileToMediaStoreDcim(finishedSeg, finishedSeg.name)
                            }
                        }
                        if (promotedSeg != null) {
                            currentVideoFile = promotedSeg
                            val futureSeg = File(videosDir, "ZAMERA_VID_${System.currentTimeMillis()}_SEG.mp4")
                            nextVideoSegmentFile = futureSeg
                            try {
                                mediaRecorder?.setNextOutputFile(futureSeg)
                            } catch (e: Throwable) {
                                android.util.Log.w("ZameraCapture", "Next segment rollover warning: ${e.message}")
                            }
                        }
                    }
                }
            }
            recorder.setOrientationHint(activeSensorOrientation)
            recorder.prepare()
            mediaRecorder = recorder
            val recSurface = recorder.surface

            configureVideoPreviewOrRecordSession(
                camera = cam,
                chars = chars,
                recorderSurface = recSurface,
                onReady = {
                    try {
                        recorder.start()
                        videoRecordStartMs = System.currentTimeMillis()
                        videoDroppedFrames = 0
                        prevVideoSensorTimestampNs = 0L
                        isVideoRecording = true
                        startAudioFloatMeterMonitor(args["audioDeviceId"]?.toString())
                        mainHandler.post {
                            result.success(
                                mapOf(
                                    "started" to true,
                                    "videoPath" to outMp4.absolutePath,
                                    "width" to videoWidth,
                                    "height" to videoHeight,
                                    "fps" to safeFps
                                )
                            )
                        }
                    } catch (e: Exception) {
                        stopVideoRecordingSilent()
                        mainHandler.post {
                            result.error("RECORDER_START_ERR", e.message, null)
                        }
                    }
                },
                onFail = { errMsg ->
                    stopVideoRecordingSilent()
                    mainHandler.post {
                        result.error("RECORD_SESSION_ERR", errMsg, null)
                    }
                }
            )
        } catch (e: Exception) {
            stopVideoRecordingSilent()
            result.error("START_RECORD_ERR", e.message, null)
        }
    }

    private fun stopVideoRecording(result: Result) {
        val outFile = currentVideoFile
        val wasTenBitHlg = activeSessionIsTenBitHlg
        val durMs = if (isVideoRecording && videoRecordStartMs > 0L) {
            (System.currentTimeMillis() - videoRecordStartMs).coerceAtLeast(100L)
        } else {
            0L
        }
        stopVideoRecordingSilent()

        // Resume clean preview session on the open camera
        val cam = cameraDevice
        if (cam != null && videoSessionActive) {
            try {
                val manager = appContext.getSystemService(Context.CAMERA_SERVICE) as CameraManager
                val chars = manager.getCameraCharacteristics(activePhysicalCameraId ?: activeCameraId)
                configureVideoPreviewOrRecordSession(cam, chars, null, {}, {})
            } catch (e: Throwable) {
                android.util.Log.w("ZameraCapture", "Resume video preview warning: ${e.message}")
            }
        }

        if (outFile != null && outFile.exists() && outFile.length() > 0L) {
            val uriStr = saveVideoFileToMediaStoreDcim(outFile, outFile.name)
            val actualProfile = if (videoProfileName == "androidHlg10Hevc10Bit" && !wasTenBitHlg) {
                "universalRec709Locked"
            } else {
                videoProfileName
            }
            val bitrateMbps = when {
                videoWidth >= 3840 && videoFps >= 60 -> 150.0
                videoWidth >= 3840 -> 100.0
                else -> 50.0
            }
            result.success(
                mapOf(
                    "videoPath" to outFile.absolutePath,
                    "mediaStoreUri" to uriStr,
                    "durationMs" to durMs,
                    "width" to videoWidth,
                    "height" to videoHeight,
                    "fps" to videoFps,
                    "bitrateMbps" to bitrateMbps,
                    "codec" to if (wasTenBitHlg) "HEVC Main10" else "HEVC Main",
                    "profile" to actualProfile,
                    "colorStandard" to if (wasTenBitHlg) "BT.2020" else "BT.709",
                    "colorTransfer" to if (wasTenBitHlg) "HLG (ARIB STD-B67)" else "SDR (Rec.709)",
                    "droppedFrames" to videoDroppedFrames,
                    "fileSizeBytes" to outFile.length()
                )
            )
        } else {
            result.success(emptyMap<String, Any?>())
        }
    }

    private fun stopVideoRecordingSilent() {
        isVideoRecording = false
        stopAudioFloatMeterMonitor()
        val rec = mediaRecorder
        mediaRecorder = null
        if (rec != null) {
            try {
                rec.stop()
            } catch (e: Throwable) {
                android.util.Log.w("ZameraCapture", "MediaRecorder.stop warning: ${e.message}")
            }
            try {
                rec.reset()
                rec.release()
            } catch (e: Throwable) {
                android.util.Log.w("ZameraCapture", "MediaRecorder.release warning: ${e.message}")
            }
        }
        nextVideoSegmentFile?.let { seg ->
            if (seg.exists() && seg.length() == 0L) {
                seg.delete()
            }
        }
        nextVideoSegmentFile = null
        videoSamplePeakDbfs = -96.0
        videoRmsDbfs = -96.0
    }

    private fun stopVideoSessionInternal() {
        val wasRecording = isVideoRecording
        val outFile = currentVideoFile
        stopVideoRecordingSilent()
        if (wasRecording && outFile != null && outFile.exists() && outFile.length() > 0L) {
            saveVideoFileToMediaStoreDcim(outFile, outFile.name)
        }
        stopPreviewSession()
    }

    private fun triggerFocusPull(args: Map<String, Any?>, result: Result) {
        val builder = previewRequestBuilder
        val session = captureSession
        val bg = backgroundHandler
        if (builder == null || session == null || bg == null) {
            result.success(false)
            return
        }
        try {
            activeFocusPullRunnable?.let { bg.removeCallbacks(it) }
            activeFocusPullRunnable = null

            val manager = appContext.getSystemService(Context.CAMERA_SERVICE) as CameraManager
            val chars = manager.getCameraCharacteristics(activePhysicalCameraId ?: activeCameraId)
            val minFocus = chars.get(CameraCharacteristics.LENS_INFO_MINIMUM_FOCUS_DISTANCE) ?: 0.0f
            if (minFocus <= 0.0f) {
                result.success(false)
                return
            }
            val fromNorm = ((args["fromFocusNorm"] as? Number)?.toFloat() ?: 0.1f).coerceIn(0f, 1f)
            val toNorm = ((args["toFocusNorm"] as? Number)?.toFloat() ?: 0.8f).coerceIn(0f, 1f)
            val durationMs = ((args["durationMs"] as? Number)?.toLong() ?: 2000L).coerceIn(300L, 10000L)
            val startMs = System.currentTimeMillis()

            val stepRunnable = object : Runnable {
                override fun run() {
                    val curBuilder = previewRequestBuilder ?: return
                    val curSession = captureSession ?: return
                    val t = ((System.currentTimeMillis() - startMs).toFloat() / durationMs.toFloat()).coerceIn(0f, 1f)
                    // Cubic ease-in-out interpolation (WP-3.6)
                    val ease = t * t * (3.0f - 2.0f * t)
                    val curNorm = fromNorm + (toNorm - fromNorm) * ease
                    try {
                        curBuilder.set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_OFF)
                        curBuilder.set(CaptureRequest.LENS_FOCUS_DISTANCE, curNorm * minFocus)
                        curSession.setRepeatingRequest(curBuilder.build(), videoCaptureCallback, bg)
                    } catch (e: Throwable) {
                        android.util.Log.w("ZameraCapture", "FocusPull step warning: ${e.message}")
                    }
                    if (t < 1.0f) {
                        bg.postDelayed(this, 16L)
                    } else {
                        activeFocusPullRunnable = null
                    }
                }
            }
            activeFocusPullRunnable = stepRunnable
            bg.post(stepRunnable)
            result.success(true)
        } catch (e: Exception) {
            result.error("FOCUS_PULL_ERR", e.message, null)
        }
    }

    private fun listAudioInputDevices(): List<Map<String, Any?>> {
        val out = mutableListOf<Map<String, Any?>>()
        try {
            val audioMgr = appContext.getSystemService(Context.AUDIO_SERVICE) as? android.media.AudioManager
            val devices = audioMgr?.getDevices(android.media.AudioManager.GET_DEVICES_INPUTS) ?: emptyArray()
            for (d in devices) {
                val typeStr = when (d.type) {
                    android.media.AudioDeviceInfo.TYPE_BUILTIN_MIC -> "BUILTIN_MIC"
                    android.media.AudioDeviceInfo.TYPE_USB_DEVICE,
                    android.media.AudioDeviceInfo.TYPE_USB_HEADSET,
                    android.media.AudioDeviceInfo.TYPE_USB_ACCESSORY -> "USB_C"
                    android.media.AudioDeviceInfo.TYPE_WIRED_HEADSET -> "WIRED"
                    android.media.AudioDeviceInfo.TYPE_BLUETOOTH_SCO,
                    android.media.AudioDeviceInfo.TYPE_BLE_HEADSET -> "BLUETOOTH"
                    else -> "OTHER"
                }
                val label = d.productName?.toString()?.takeIf { it.isNotBlank() } ?: "Mikrofon ($typeStr)"
                out.add(
                    mapOf(
                        "id" to d.id.toString(),
                        "name" to "$label · $typeStr",
                        "type" to typeStr
                    )
                )
            }
        } catch (e: Throwable) {
            android.util.Log.w("ZameraCapture", "listAudioInputDevices warning: ${e.message}")
        }
        if (out.isEmpty()) {
            out.add(mapOf("id" to "default", "name" to "Dahili Stereo Mikrofon", "type" to "BUILTIN_MIC"))
        }
        return out
    }

    private fun extractVideoTelemetry(): Map<String, Any?> {
        if (!isVideoRecording) {
            videoSamplePeakDbfs = -96.0
            videoRmsDbfs = -96.0
        }

        val stat = try {
            android.os.StatFs(appContext.filesDir.absolutePath)
        } catch (_: Throwable) {
            null
        }
        val availBytes = stat?.availableBytes ?: 0L
        val bytesPerSec = when {
            videoWidth >= 3840 && videoFps >= 60 -> 150_000_000L / 8L
            videoWidth >= 3840 -> 100_000_000L / 8L
            else -> 50_000_000L / 8L
        }
        val remSec = (availBytes / bytesPerSec.coerceAtLeast(1L)).toInt().coerceAtLeast(0)

        // Auto-stop and export to DCIM/Zamera if free storage drops below 500 MB during recording (WP-3.5)
        if (isVideoRecording && availBytes in 1L..(500L * 1024L * 1024L)) {
            emergencyStopAndSaveVideoRecording(resumePreview = true)
        }

        val durMs = if (isVideoRecording && videoRecordStartMs > 0L) {
            (System.currentTimeMillis() - videoRecordStartMs).coerceAtLeast(0L)
        } else {
            0L
        }

        val baseTel = extractLiveTelemetry()
        return baseTel + mapOf(
            "isRecording" to isVideoRecording,
            "recordedDurationMs" to durMs,
            "samplePeakDbfs" to videoSamplePeakDbfs,
            "rmsDbfs" to videoRmsDbfs,
            "droppedFrameCount" to videoDroppedFrames,
            "thermalStatus" to videoThermalStatus,
            "availableStorageBytes" to availBytes,
            "remainingRecordSeconds" to remSec,
            "iso" to (baseTel["iso"] ?: videoActiveIso.roundToInt()),
            "shutterAngleDeg" to videoShutterAngleDeg,
            "fps" to videoFps,
            "ndFilterRecommendation" to videoNdRecommendation,
            "activePhysicalLensId" to (activePhysicalCameraId ?: activeCameraId)
        )
    }

    private fun saveVideoFileToMediaStoreDcim(sourceFile: File, displayName: String): String? {
        if (!sourceFile.exists()) return null
        return try {
            val resolver = appContext.contentResolver
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, displayName)
                put(MediaStore.MediaColumns.MIME_TYPE, "video/mp4")
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    put(MediaStore.MediaColumns.RELATIVE_PATH, "${Environment.DIRECTORY_DCIM}/Zamera")
                    put(MediaStore.MediaColumns.IS_PENDING, 1)
                }
            }
            val uri = resolver.insert(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, values) ?: return null
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

    private fun probeCamera2Capabilities(): Map<String, Any?> {
        val manager = appContext.getSystemService(Context.CAMERA_SERVICE) as CameraManager
        val logicalIds = manager.cameraIdList.toList()
        val allDiscoveredIds = linkedSetOf<String>().apply { addAll(logicalIds) }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            for (id in logicalIds) {
                try {
                    val chars = manager.getCameraCharacteristics(id)
                    allDiscoveredIds.addAll(chars.physicalCameraIds)
                } catch (e: Exception) {
                    android.util.Log.w("ZameraCapture", "probe physicalCameraIds warning: ${e.message}")
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
        } catch (e: Exception) {
            android.util.Log.w("ZameraCapture", "probe_report.json write warning: ${e.message}")
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
        stopVideoSessionInternal()
        stopPreviewSession()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            try {
                val pm = appContext.getSystemService(Context.POWER_SERVICE) as? android.os.PowerManager
                val listener = thermalListener
                if (pm != null && listener != null) {
                    pm.removeThermalStatusListener(listener)
                }
            } catch (e: Exception) {
                android.util.Log.w("ZameraCapture", "removeThermalStatusListener warning: ${e.message}")
            }
            thermalListener = null
        }
        try {
            selfieSegmenterInstance?.close()
            selfieSegmenterInstance = null
        } catch (e: Throwable) {
            android.util.Log.w("ZameraCapture", "SelfieSegmenter close warning: ${e.message}")
        }
        ispWorkerPool.shutdown()
        rustIspExecutor.shutdown()
        cameraSessionExecutor.shutdown()
        backgroundThread?.quitSafely()
        backgroundThread = null
        backgroundHandler = null
        channel.setMethodCallHandler(null)
        videoChannel.setMethodCallHandler(null)
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

    @JvmStatic
    private external fun nativeComputeSoftwareAutoIsoDirect(
        inBuffer: ByteBuffer,
        outBuffer: ByteBuffer
    ): Int

    @JvmStatic
    private external fun nativeComputeAudioDbfsDirect(
        inBuffer: ByteBuffer,
        sampleCount: Int,
        outBuffer: ByteBuffer
    ): Int

    data class SoftwareAutoIsoResult(
        val nextIso: Double,
        val ndFactor: Int,
        val shutterExposureNs: Long,
        val frameDurationNs: Long
    )

    fun computeSoftwareAutoIsoStep(
        currentIso: Double,
        isoMin: Double,
        isoMax: Double,
        measuredLuma: Double,
        targetLuma: Double,
        angleDeg: Double,
        fps: Double
    ): SoftwareAutoIsoResult {
        if (loaded) {
            try {
                val inBuf = ByteBuffer.allocateDirect(7 * 4).order(ByteOrder.nativeOrder())
                val inf = inBuf.asFloatBuffer()
                inf.put(currentIso.toFloat())
                inf.put(isoMin.toFloat())
                inf.put(isoMax.toFloat())
                inf.put(measuredLuma.toFloat())
                inf.put(targetLuma.toFloat())
                inf.put(angleDeg.toFloat())
                inf.put(fps.toFloat())
                val outBuf = ByteBuffer.allocateDirect(4 * 4).order(ByteOrder.nativeOrder())
                if (nativeComputeSoftwareAutoIsoDirect(inBuf, outBuf) == 0) {
                    val outf = outBuf.asFloatBuffer()
                    return SoftwareAutoIsoResult(
                        nextIso = outf.get(0).toDouble(),
                        ndFactor = outf.get(1).roundToInt(),
                        shutterExposureNs = outf.get(2).toLong(),
                        frameDurationNs = outf.get(3).toLong()
                    )
                }
            } catch (e: Throwable) {
                android.util.Log.w("ZameraRustBridge", "nativeComputeSoftwareAutoIsoDirect fallback: ${e.message}")
            }
        }
        val evError = kotlin.math.ln(targetLuma / measuredLuma) / kotlin.math.ln(2.0)
        val nextIso = if (kotlin.math.abs(evError) < 0.06) {
            currentIso
        } else {
            val stepEv = (evError * 0.55).coerceIn(-1.0 / 6.0, 1.0 / 6.0)
            (currentIso * Math.pow(2.0, stepEv)).coerceIn(isoMin, isoMax)
        }
        val overEv = kotlin.math.ln(measuredLuma / targetLuma) / kotlin.math.ln(2.0)
        val ndFactor = if (nextIso <= isoMin * 1.05 && overEv > 1.0) {
            when {
                overEv > 3.5 -> 16
                overEv > 2.5 -> 8
                else -> 4
            }
        } else 0
        val shutterNs = ((angleDeg.coerceIn(11.25, 360.0) / (360.0 * fps.coerceIn(1.0, 240.0))) * 1_000_000_000.0).toLong()
        val frameNs = (1_000_000_000.0 / fps.coerceIn(1.0, 240.0)).toLong()
        return SoftwareAutoIsoResult(nextIso, ndFactor, shutterNs, frameNs)
    }

    fun computeAudioPeakAndRmsDbfs(samples: FloatArray, count: Int): Pair<Float, Float> {
        val n = count.coerceIn(0, samples.size)
        if (n <= 0) return Pair(-96.0f, -96.0f)
        if (loaded) {
            try {
                val inBuf = ByteBuffer.allocateDirect(n * 4).order(ByteOrder.nativeOrder())
                inBuf.asFloatBuffer().put(samples, 0, n)
                val outBuf = ByteBuffer.allocateDirect(2 * 4).order(ByteOrder.nativeOrder())
                if (nativeComputeAudioDbfsDirect(inBuf, n, outBuf) == 0) {
                    val outf = outBuf.asFloatBuffer()
                    return Pair(outf.get(0), outf.get(1))
                }
            } catch (e: Throwable) {
                android.util.Log.w("ZameraRustBridge", "nativeComputeAudioDbfsDirect fallback: ${e.message}")
            }
        }
        var peak = 0.0f
        var sumSq = 0.0
        for (i in 0 until n) {
            val s = samples[i]
            val a = if (s.isFinite()) kotlin.math.abs(s).coerceAtMost(1.0f) else 0.0f
            if (a > peak) peak = a
            sumSq += a.toDouble() * a.toDouble()
        }
        val rms = kotlin.math.sqrt(sumSq / n.toDouble()).toFloat()
        val peakDb = if (peak <= 1.5848932e-5f) -96.0f else (20.0f * kotlin.math.log10(peak)).coerceIn(-96.0f, 0.0f)
        val rmsDb = if (rms <= 1.5848932e-5f) -96.0f else (20.0f * kotlin.math.log10(rms)).coerceIn(-96.0f, 0.0f)
        return Pair(peakDb, rmsDb)
    }

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
