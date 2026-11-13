package com.akarworks.zamera_capture

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.content.ContentValues
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ColorSpace
import android.graphics.ImageFormat
import android.graphics.Matrix
import android.graphics.Rect
import android.hardware.camera2.*
import android.hardware.camera2.params.ColorSpaceTransform
import android.hardware.camera2.params.DynamicRangeProfiles
import android.hardware.camera2.params.LensShadingMap
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
import kotlin.math.ln
import kotlin.math.log10
import kotlin.math.pow
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

    // Managed warm ML Kit SelfieSegmenter & Bundled LiteRT/TFLite Multiclass + 3D Depth + U²-NetP Matting Interpreters
    @Volatile
    private var selfieSegmenterInstance: com.google.mlkit.vision.segmentation.Segmenter? = null
    private val multiclassModelLock = Any()
    private val depthModelLock = Any()
    private val u2netModelLock = Any()
    @Volatile
    private var multiclassInterpreterInstance: org.tensorflow.lite.Interpreter? = null
    @Volatile
    private var depthInterpreterInstance: org.tensorflow.lite.Interpreter? = null
    @Volatile
    private var u2netInterpreterInstance: org.tensorflow.lite.Interpreter? = null

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

    private fun loadAssetModelBuffer(assetName: String): ByteBuffer {
        return try {
            appContext.assets.openFd(assetName).use { afd ->
                java.io.FileInputStream(afd.fileDescriptor).channel.use { ch ->
                    ch.map(java.nio.channels.FileChannel.MapMode.READ_ONLY, afd.startOffset, afd.declaredLength)
                }
            }
        } catch (_: Throwable) {
            val bytes = appContext.assets.open(assetName).use { it.readBytes() }
            ByteBuffer.allocateDirect(bytes.size).order(ByteOrder.nativeOrder()).apply {
                put(bytes)
                rewind()
            }
        }
    }

    private fun getOrCreateMulticlassInterpreter(): org.tensorflow.lite.Interpreter? {
        multiclassInterpreterInstance?.let { return it }
        synchronized(multiclassModelLock) {
            multiclassInterpreterInstance?.let { return it }
            return try {
                val opts = org.tensorflow.lite.Interpreter.Options()
                    .setNumThreads(4)
                    .setUseXNNPACK(true)
                org.tensorflow.lite.Interpreter(loadAssetModelBuffer("selfie_multiclass_256x256.tflite"), opts)
                    .also { multiclassInterpreterInstance = it }
            } catch (t: Throwable) {
                android.util.Log.e("ZameraPortrait", "SelfieMulticlass init failed: ${t.message}", t)
                null
            }
        }
    }

    private fun getOrCreateDepthInterpreter(): org.tensorflow.lite.Interpreter? {
        depthInterpreterInstance?.let { return it }
        synchronized(depthModelLock) {
            depthInterpreterInstance?.let { return it }
            return try {
                val opts = org.tensorflow.lite.Interpreter.Options()
                    .setNumThreads(4)
                    .setUseXNNPACK(true)
                org.tensorflow.lite.Interpreter(loadAssetModelBuffer("depth_anything_v2_small.tflite"), opts)
                    .also { depthInterpreterInstance = it }
            } catch (t: Throwable) {
                android.util.Log.e("ZameraPortrait", "DepthAnythingV2 init failed: ${t.message}", t)
                null
            }
        }
    }

    private fun getOrCreateU2NetInterpreter(): org.tensorflow.lite.Interpreter? {
        u2netInterpreterInstance?.let { return it }
        synchronized(u2netModelLock) {
            u2netInterpreterInstance?.let { return it }
            return try {
                val opts = org.tensorflow.lite.Interpreter.Options()
                    .setNumThreads(2)
                    .setUseXNNPACK(true)
                org.tensorflow.lite.Interpreter(loadAssetModelBuffer("u2netp.tflite"), opts)
                    .also { u2netInterpreterInstance = it }
            } catch (t: Throwable) {
                android.util.Log.e("ZameraPortrait", "U2NetP init failed: ${t.message}", t)
                null
            }
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
    @Volatile
    private var latestLiveCenterSrgb: List<Int> = listOf(119, 119, 119)
    @Volatile
    private var latestLiveCenterLabD50: List<Double> = listOf(50.0, 0.0, 0.0)

    // Photo DSLR PASM & AE/AF Lock State
    @Volatile
    private var photoManualIso: Boolean = false
    @Volatile
    private var photoManualShutter: Boolean = false
    @Volatile
    private var photoAeAfLocked: Boolean = false
    @Volatile
    private var photoActiveIso: Double = 100.0
    @Volatile
    private var photoActiveShutterNs: Long = 8_000_000L
    @Volatile
    private var photoIsoMin: Int = 50
    @Volatile
    private var photoIsoMax: Int = 3200
    @Volatile
    private var photoExpNsMin: Long = 50_000L
    @Volatile
    private var photoExpNsMax: Long = 1_000_000_000L
    @Volatile
    private var photoEvCompensation: Double = 0.0

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
    @Volatile
    private var videoAeAfLocked: Boolean = false
    @Volatile
    private var videoPreferredAudioDeviceId: String? = null
    @Volatile
    private var fallbackSmoothedAudioPower: Double = 0.0

    private val portraitSessionCache = PortraitSessionCache(maxEntries = 1)

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        appContext = flutterPluginBinding.applicationContext
        textureRegistry = flutterPluginBinding.textureRegistry
        // Pre-warm MediaPipe Selfie Multiclass + ML Kit SelfieSegmenter + DepthAnythingV2 in background
        rustIspExecutor.execute {
            try {
                getOrCreateMulticlassInterpreter()
                getOrCreateSelfieSegmenter()
                getOrCreateDepthInterpreter()
            } catch (e: Throwable) {
                android.util.Log.w("ZameraCapture", "Portrait AI pre-warm warning: ${e.message}")
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
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    act.window?.colorMode = android.content.pm.ActivityInfo.COLOR_MODE_WIDE_COLOR_GAMUT
                }
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
            "setVideoFocusAndMeteringPoint" -> {
                val args = call.arguments as? Map<String, Any?> ?: emptyMap()
                setVideoFocusAndMeteringPoint(args, result)
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
            photoIsoMin = isoRange?.lower ?: 50
            photoIsoMax = isoRange?.upper ?: 3200
            photoExpNsMin = expRange?.lower ?: 50_000L
            photoExpNsMax = expRange?.upper ?: 1_000_000_000L
            photoManualIso = false
            photoManualShutter = false
            photoAeAfLocked = false
            photoEvCompensation = 0.0
            photoActiveIso = 100.0.coerceIn(photoIsoMin.toDouble(), photoIsoMax.toDouble())
            photoActiveShutterNs = 8_000_000L.coerceIn(photoExpNsMin, photoExpNsMax)

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
                                val shadingModes = chars.get(CameraCharacteristics.SHADING_AVAILABLE_MODES)
                                if (shadingModes != null && shadingModes.contains(CameraMetadata.SHADING_MODE_HIGH_QUALITY)) {
                                    builder.set(CaptureRequest.SHADING_MODE, CameraMetadata.SHADING_MODE_HIGH_QUALITY)
                                }
                                val lsmModes = chars.get(CameraCharacteristics.STATISTICS_INFO_AVAILABLE_LENS_SHADING_MAP_MODES)
                                if (lsmModes != null && lsmModes.contains(CameraMetadata.STATISTICS_LENS_SHADING_MAP_MODE_ON)) {
                                    builder.set(
                                        CaptureRequest.STATISTICS_LENS_SHADING_MAP_MODE,
                                        CameraMetadata.STATISTICS_LENS_SHADING_MAP_MODE_ON
                                    )
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
            ?: logicalRes.get(CaptureResult.SENSOR_SENSITIVITY)
            ?: (if (!videoSessionActive && (photoManualIso || photoManualShutter)) photoActiveIso.roundToInt() else null)
        val expNs = physRes.get(CaptureResult.SENSOR_EXPOSURE_TIME)
            ?: logicalRes.get(CaptureResult.SENSOR_EXPOSURE_TIME)
            ?: (if (!videoSessionActive && (photoManualIso || photoManualShutter)) photoActiveShutterNs else null)
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

        val meanLumaNorm = latestMeanSceneLumaNorm.coerceIn(0.005, 1.0)
        val meteredEvDelta = (ln(meanLumaNorm.coerceAtLeast(0.005) / 0.42) / ln(2.0)).coerceIn(-3.0, 3.0)
        val currentAeAfLocked = if (videoSessionActive) videoAeAfLocked else photoAeAfLocked

        return mapOf(
            "cameraId" to (activePhysicalCameraId ?: activeCameraId),
            "iso" to iso,
            "exposureTimeNs" to expNs,
            "focusDistanceDiopters" to focusDiopters?.toDouble(),
            "aperture" to aperture?.toDouble(),
            "focalLengthMm" to focalLength?.toDouble(),
            "solvedCctKelvin" to liveCctKelvin,
            "meteredEvDelta" to meteredEvDelta,
            "aeAfLocked" to currentAeAfLocked,
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
            "liveCenterSrgb" to latestLiveCenterSrgb,
            "liveCenterLabD50" to latestLiveCenterLabD50,
            "ndFilterRecommendation" to videoNdRecommendation
        )
    }

    private fun srgb8ToLabD50Native(r: Int, g: Int, b: Int): List<Double> {
        fun eotf(code: Int): Double {
            val c = code.coerceIn(0, 255) / 255.0
            return if (c <= 0.04045) c / 12.92 else Math.pow((c + 0.055) / 1.055, 2.4)
        }
        val lr = eotf(r)
        val lg = eotf(g)
        val lb = eotf(b)
        // sRGB linear -> XYZ D65 -> Bradford D65->D50
        val x50 = 0.4360747 * lr + 0.3850649 * lg + 0.1430804 * lb
        val y50 = 0.2225045 * lr + 0.7168786 * lg + 0.0606169 * lb
        val z50 = 0.0139322 * lr + 0.0971045 * lg + 0.7141733 * lb

        val eps = 216.0 / 24389.0
        val kap = 24389.0 / 27.0
        fun f(t: Double): Double = if (t > eps) Math.cbrt(t) else (kap * t + 16.0) / 116.0
        val fx = f((x50 / 0.96422).coerceAtLeast(0.0))
        val fy = f((y50 / 1.00000).coerceAtLeast(0.0))
        val fz = f((z50 / 0.82521).coerceAtLeast(0.0))
        return listOf(116.0 * fy - 16.0, 500.0 * (fx - fy), 200.0 * (fy - fz))
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

        // Sample central 8x8 YUV_420_888 region for live center sRGB & CIE L*a*b* (D50) colorimeter
        try {
            if (img.planes.size >= 3) {
                val uPlane = img.planes[1]
                val vPlane = img.planes[2]
                val uBuf = uPlane.buffer
                val vBuf = vPlane.buffer
                val uRowStride = uPlane.rowStride
                val uPixStride = uPlane.pixelStride
                val vRowStride = vPlane.rowStride
                val vPixStride = vPlane.pixelStride
                val cx0 = (sw / 2 - 4).coerceAtLeast(0)
                val cx1 = (sw / 2 + 4).coerceAtMost(sw)
                val cy0 = (sh / 2 - 4).coerceAtLeast(0)
                val cy1 = (sh / 2 + 4).coerceAtMost(sh)
                var sumY = 0.0
                var sumU = 0.0
                var sumV = 0.0
                var cCnt = 0
                for (cy in cy0 until cy1) {
                    val uvY = cy / 2
                    for (cx in cx0 until cx1) {
                        val uvX = cx / 2
                        val yIdx = cy * rowStride + cx * pixelStride
                        val uIdx = uvY * uRowStride + uvX * uPixStride
                        val vIdx = uvY * vRowStride + uvX * vPixStride
                        if (yIdx < yBuf.limit() && uIdx < uBuf.limit() && vIdx < vBuf.limit()) {
                            sumY += (yBuf.get(yIdx).toInt() and 0xFF).toDouble()
                            sumU += (uBuf.get(uIdx).toInt() and 0xFF).toDouble()
                            sumV += (vBuf.get(vIdx).toInt() and 0xFF).toDouble()
                            cCnt++
                        }
                    }
                }
                if (cCnt > 0) {
                    val ym = sumY / cCnt
                    val um = sumU / cCnt - 128.0
                    val vm = sumV / cCnt - 128.0
                    val sr = (ym + 1.402 * vm).roundToInt().coerceIn(0, 255)
                    val sg = (ym - 0.344136 * um - 0.714136 * vm).roundToInt().coerceIn(0, 255)
                    val sb = (ym + 1.772 * um).roundToInt().coerceIn(0, 255)
                    latestLiveCenterSrgb = listOf(sr, sg, sb)
                    latestLiveCenterLabD50 = srgb8ToLabD50Native(sr, sg, sb)
                }
            }
        } catch (e: Throwable) {
            android.util.Log.w("ZameraCapture", "Center YUV sample warning: ${e.message}")
        }

        // WP-3.2 Software Auto-ISO PI Controller (active when 180° shutter angle is locked and manualIso is false)
        if (videoSessionActive && videoLockShutterAngle && !videoManualIso && !videoAeAfLocked) {
            applySoftwareAutoIsoStep(meanLumaNorm)
        } else if (!videoSessionActive && !photoAeAfLocked && (photoManualIso != photoManualShutter)) {
            applyPhotoPasmExposureStep(meanLumaNorm)
        }
    }

    private val photoPreviewCaptureCallback = object : CameraCaptureSession.CaptureCallback() {
        override fun onCaptureCompleted(
            session: CameraCaptureSession,
            request: CaptureRequest,
            res: TotalCaptureResult
        ) {
            lastTotalCaptureResult = res
            if (yuvAnalysisReader == null && !videoSessionActive) {
                val surf = previewSurface
                if (surf != null) {
                    val now = System.currentTimeMillis()
                    if (now - lastYuvAnalysisMs >= 160L) {
                        lastYuvAnalysisMs = now
                        samplePreviewSurfaceViaPixelCopy(surf)
                    }
                }
            }
        }
    }

    /**
     * DSLR Semi-Automatic Exposure Controller for Tv (Shutter Priority -> Auto-ISO)
     * and Sv (ISO Sensitivity Priority -> Auto-Shutter) driven by live YUV scene luma + EV bias.
     */
    private fun applyPhotoPasmExposureStep(measuredLuma: Double) {
        val builder = previewRequestBuilder ?: return
        val session = captureSession ?: return
        if (photoAeAfLocked) return
        try {
            val targetLuma = (0.42 * Math.pow(2.0, photoEvCompensation.coerceIn(-3.0, 3.0))).coerceIn(0.06, 0.88)
            val meas = measuredLuma.coerceIn(0.005, 1.0)
            val evError = (ln(targetLuma / meas) / ln(2.0)).coerceIn(-4.0, 4.0)
            if (kotlin.math.abs(evError) < 0.06) return
            val dampedStepEv = (evError * 0.45).coerceIn(-1.25, 1.25)
            val ratio = Math.pow(2.0, dampedStepEv)

            if (!photoManualIso && photoManualShutter) {
                // Tv (Shutter Priority): fixed shutter, smooth software Auto-ISO within sensor sensitivity range
                val minI = photoIsoMin.toDouble().coerceAtLeast(10.0)
                val maxI = photoIsoMax.toDouble().coerceAtLeast(minI)
                val curIso = photoActiveIso.coerceIn(minI, maxI)
                val nextIso = (curIso * ratio).coerceIn(minI, maxI)
                if (kotlin.math.abs(nextIso - curIso) >= 1.5) {
                    photoActiveIso = nextIso
                    val fixedShutter = photoActiveShutterNs.coerceIn(photoExpNsMin, photoExpNsMax)
                    builder.set(CaptureRequest.CONTROL_AE_MODE, CaptureRequest.CONTROL_AE_MODE_OFF)
                    builder.set(CaptureRequest.CONTROL_AE_LOCK, false)
                    builder.set(CaptureRequest.SENSOR_EXPOSURE_TIME, fixedShutter)
                    builder.set(CaptureRequest.SENSOR_SENSITIVITY, nextIso.roundToInt().coerceIn(photoIsoMin, photoIsoMax))
                    session.setRepeatingRequest(builder.build(), photoPreviewCaptureCallback, backgroundHandler)
                }
            } else if (photoManualIso && !photoManualShutter) {
                // Sv (Sensitivity Priority): fixed ISO, smooth software Auto-Shutter within sensor expRange
                val minExp = photoExpNsMin.coerceAtLeast(10_000L)
                val maxExp = photoExpNsMax.coerceAtMost(500_000_000L).coerceAtLeast(minExp)
                val curExp = photoActiveShutterNs.coerceIn(minExp, maxExp).toDouble()
                val nextExp = (curExp * ratio).coerceIn(minExp.toDouble(), maxExp.toDouble())
                val nextExpLong = nextExp.toLong().coerceIn(minExp, maxExp)
                if (nextExpLong != photoActiveShutterNs &&
                    kotlin.math.abs(nextExp - curExp) / curExp.coerceAtLeast(1.0) >= 0.02
                ) {
                    photoActiveShutterNs = nextExpLong
                    val fixedIso = photoActiveIso.roundToInt().coerceIn(photoIsoMin, photoIsoMax)
                    builder.set(CaptureRequest.CONTROL_AE_MODE, CaptureRequest.CONTROL_AE_MODE_OFF)
                    builder.set(CaptureRequest.CONTROL_AE_LOCK, false)
                    builder.set(CaptureRequest.SENSOR_SENSITIVITY, fixedIso)
                    builder.set(CaptureRequest.SENSOR_EXPOSURE_TIME, nextExpLong)
                    session.setRepeatingRequest(builder.build(), photoPreviewCaptureCallback, backgroundHandler)
                }
            }
        } catch (e: Throwable) {
            android.util.Log.w("ZameraCapture", "applyPhotoPasmExposureStep warning: ${e.message}")
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
                        var totalLumaSum = 0L
                        var totalGradSum = 0.0
                        for (sy in 1 until sh - 1) {
                            val rowOff = sy * sw
                            for (sx in 1 until sw - 1) {
                                val p = pixels[rowOff + sx]
                                val yVal = (((p shr 16) and 0xFF) * 77 + ((p shr 8) and 0xFF) * 150 + (p and 0xFF) * 29) shr 8
                                histBins[(yVal shr 3).coerceIn(0, 31)]++
                                histBins64[(yVal shr 2).coerceIn(0, 63)]++
                                totalLumaSum += yVal
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
                            var cR = 0
                            var cG = 0
                            var cB = 0
                            var cN = 0
                            for (cy in (sh / 2 - 4).coerceAtLeast(0) until (sh / 2 + 4).coerceAtMost(sh)) {
                                for (cx in (sw / 2 - 4).coerceAtLeast(0) until (sw / 2 + 4).coerceAtMost(sw)) {
                                    val px = pixels[cy * sw + cx]
                                    cR += (px shr 16) and 0xFF
                                    cG += (px shr 8) and 0xFF
                                    cB += px and 0xFF
                                    cN++
                                }
                            }
                            if (cN > 0) {
                                val sr = (cR / cN).coerceIn(0, 255)
                                val sg = (cG / cN).coerceIn(0, 255)
                                val sb = (cB / cN).coerceIn(0, 255)
                                latestLiveCenterSrgb = listOf(sr, sg, sb)
                                latestLiveCenterLabD50 = srgb8ToLabD50Native(sr, sg, sb)
                            }
                            val meanLumaNorm = ((totalLumaSum.toDouble() / totalSamples) / 255.0).coerceIn(0.005, 1.0)
                            latestMeanSceneLumaNorm = meanLumaNorm
                            if (videoSessionActive && videoLockShutterAngle && !videoManualIso && !videoAeAfLocked) {
                                applySoftwareAutoIsoStep(meanLumaNorm)
                            } else if (!videoSessionActive && !photoAeAfLocked && (photoManualIso != photoManualShutter)) {
                                applyPhotoPasmExposureStep(meanLumaNorm)
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

    private fun buildSpotMeteringRegion(
        chars: CameraCharacteristics,
        builder: CaptureRequest.Builder,
        normX: Float,
        normY: Float
    ): MeteringRectangle? {
        val sensorRect = chars.get(CameraCharacteristics.SENSOR_INFO_ACTIVE_ARRAY_SIZE) ?: return null
        if (sensorRect.width() < 64 || sensorRect.height() < 64) return null
        val clampedX = normX.coerceIn(0.05f, 0.95f)
        val clampedY = normY.coerceIn(0.05f, 0.95f)
        // Rotate normalized portrait UI coordinates (clampedX, clampedY) into physical sensor array orientation
        val (sensorNormX, sensorNormY) = when ((activeSensorOrientation % 360 + 360) % 360) {
            90 -> Pair(clampedY, 1.0f - clampedX)
            270 -> Pair(1.0f - clampedY, 1.0f - clampedX)
            180 -> Pair(1.0f - clampedX, 1.0f - clampedY)
            else -> Pair(clampedX, clampedY)
        }
        val baseRect = builder.get(CaptureRequest.SCALER_CROP_REGION) ?: sensorRect
        val cx = (baseRect.left + sensorNormX * baseRect.width()).toInt()
        val cy = (baseRect.top + sensorNormY * baseRect.height()).toInt()
        val halfW = (baseRect.width() * 0.075f).toInt().coerceAtLeast(32)
        val halfH = (baseRect.height() * 0.075f).toInt().coerceAtLeast(32)
        val left = (cx - halfW).coerceAtLeast(sensorRect.left)
        val top = (cy - halfH).coerceAtLeast(sensorRect.top)
        val right = (cx + halfW).coerceAtMost(sensorRect.right).coerceAtLeast(left + 1)
        val bottom = (cy + halfH).coerceAtMost(sensorRect.bottom).coerceAtLeast(top + 1)
        return MeteringRectangle(
            Rect(left, top, right, bottom),
            MeteringRectangle.METERING_WEIGHT_MAX - 1
        )
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
            val normX = ((args["x"] as? Number)?.toFloat() ?: 0.5f)
            val normY = ((args["y"] as? Number)?.toFloat() ?: 0.5f)
            val lockAeAf = args["lockAeAf"] as? Boolean ?: false
            val region = buildSpotMeteringRegion(chars, builder, normX, normY)
            if (region == null) {
                result.success(false)
                return
            }

            photoAeAfLocked = lockAeAf
            val maxAf = chars.get(CameraCharacteristics.CONTROL_MAX_REGIONS_AF) ?: 0
            val maxAe = chars.get(CameraCharacteristics.CONTROL_MAX_REGIONS_AE) ?: 0
            val minFocus = chars.get(CameraCharacteristics.LENS_INFO_MINIMUM_FOCUS_DISTANCE) ?: 0.0f
            val isManualFocus = builder.get(CaptureRequest.CONTROL_AF_MODE) == CaptureRequest.CONTROL_AF_MODE_OFF
            if (maxAf > 0 && minFocus > 0.0f) {
                builder.set(CaptureRequest.CONTROL_AF_REGIONS, arrayOf(region))
                if (!isManualFocus) {
                    builder.set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_AUTO)
                }
            }
            if (maxAe > 0) {
                builder.set(CaptureRequest.CONTROL_AE_REGIONS, arrayOf(region))
            }
            builder.set(CaptureRequest.CONTROL_AE_LOCK, lockAeAf)

            session.setRepeatingRequest(builder.build(), photoPreviewCaptureCallback, backgroundHandler)

            // Trigger active AF sweep if variable focus is enabled and not locked in manual focus
            if (maxAf > 0 && minFocus > 0.0f && !isManualFocus) {
                builder.set(CaptureRequest.CONTROL_AF_TRIGGER, CameraMetadata.CONTROL_AF_TRIGGER_START)
                session.capture(builder.build(), photoPreviewCaptureCallback, backgroundHandler)
                builder.set(CaptureRequest.CONTROL_AF_TRIGGER, CameraMetadata.CONTROL_AF_TRIGGER_IDLE)
            }

            result.success(true)
        } catch (e: Exception) {
            result.error("TAP_FOCUS_ERR", e.message, null)
        }
    }

    private fun setVideoFocusAndMeteringPoint(args: Map<String, Any?>, result: Result) {
        activeFocusPullRunnable?.let { backgroundHandler?.removeCallbacks(it) }
        activeFocusPullRunnable = null
        val builder = previewRequestBuilder
        val session = captureSession
        if (builder == null || session == null || !videoSessionActive) {
            result.success(false)
            return
        }
        try {
            val manager = appContext.getSystemService(Context.CAMERA_SERVICE) as CameraManager
            val charsId = activePhysicalCameraId ?: activeCameraId
            val chars = manager.getCameraCharacteristics(charsId)
            val normX = ((args["x"] as? Number)?.toFloat() ?: 0.5f)
            val normY = ((args["y"] as? Number)?.toFloat() ?: 0.5f)
            val lockAeAf = args["lockAeAf"] as? Boolean ?: false
            val region = buildSpotMeteringRegion(chars, builder, normX, normY)
            if (region == null) {
                result.success(false)
                return
            }

            videoAeAfLocked = lockAeAf
            val maxAf = chars.get(CameraCharacteristics.CONTROL_MAX_REGIONS_AF) ?: 0
            val maxAe = chars.get(CameraCharacteristics.CONTROL_MAX_REGIONS_AE) ?: 0
            val minFocus = chars.get(CameraCharacteristics.LENS_INFO_MINIMUM_FOCUS_DISTANCE) ?: 0.0f
            val isManualFocus = builder.get(CaptureRequest.CONTROL_AF_MODE) == CaptureRequest.CONTROL_AF_MODE_OFF

            if (maxAf > 0 && minFocus > 0.0f) {
                builder.set(CaptureRequest.CONTROL_AF_REGIONS, arrayOf(region))
                if (!isManualFocus) {
                    builder.set(
                        CaptureRequest.CONTROL_AF_MODE,
                        if (lockAeAf) CaptureRequest.CONTROL_AF_MODE_AUTO else CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_VIDEO
                    )
                }
            }
            if (maxAe > 0) {
                builder.set(CaptureRequest.CONTROL_AE_REGIONS, arrayOf(region))
            }
            builder.set(CaptureRequest.CONTROL_AE_LOCK, lockAeAf)

            session.setRepeatingRequest(builder.build(), videoCaptureCallback, backgroundHandler)

            if (maxAf > 0 && minFocus > 0.0f && !isManualFocus) {
                builder.set(
                    CaptureRequest.CONTROL_AF_TRIGGER,
                    if (lockAeAf) CameraMetadata.CONTROL_AF_TRIGGER_START else CameraMetadata.CONTROL_AF_TRIGGER_CANCEL
                )
                session.capture(builder.build(), videoCaptureCallback, backgroundHandler)
                builder.set(CaptureRequest.CONTROL_AF_TRIGGER, CameraMetadata.CONTROL_AF_TRIGGER_IDLE)
            }

            result.success(true)
        } catch (e: Exception) {
            result.error("VIDEO_TAP_FOCUS_ERR", e.message, null)
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
            val manualIso = args["manualIso"] as? Boolean ?: manualExposure
            val manualShutter = args["manualShutter"] as? Boolean ?: manualExposure
            val aeAfLocked = args["aeAfLocked"] as? Boolean ?: false
            val artworkLinearMode = args["artworkLinearMode"] as? Boolean ?: false
            val rawEvComp = (args["evCompensation"] as? Number)?.toDouble() ?: 0.0
            // In Sanat Mode (artworkLinearMode) with 0 EV override, apply +0.35 EV AE bias for optimal linear pigment SNR without clipping
            val evComp = if (artworkLinearMode && kotlin.math.abs(rawEvComp) < 0.05) 0.35 else rawEvComp

            photoIsoMin = isoRange?.lower ?: 50
            photoIsoMax = isoRange?.upper ?: 3200
            photoExpNsMin = expRange?.lower ?: 50_000L
            photoExpNsMax = expRange?.upper ?: 1_000_000_000L
            val prevWasAutoAe = builder.get(CaptureRequest.CONTROL_AE_MODE) == CaptureRequest.CONTROL_AE_MODE_ON
            photoManualIso = manualIso
            photoManualShutter = manualShutter
            photoAeAfLocked = aeAfLocked
            photoEvCompensation = evComp.coerceIn(-3.0, 3.0)

            val reqIso = (args["iso"] as? Number)?.toInt() ?: 100
            val clampedIso = if (isoRange != null) reqIso.coerceIn(isoRange.lower, isoRange.upper) else reqIso
            val reqShutterNs = (args["exposureTimeNs"] as? Number)?.toLong() ?: 8_000_000L
            val clampedShutter = if (expRange != null) reqShutterNs.coerceIn(expRange.lower, expRange.upper) else reqShutterNs

            when {
                !manualIso && !manualShutter -> {
                    // P (Program AE): Hardware AE + EV compensation + optional AE lock
                    builder.set(CaptureRequest.CONTROL_AE_MODE, CaptureRequest.CONTROL_AE_MODE_ON)
                    builder.set(CaptureRequest.CONTROL_AE_LOCK, aeAfLocked)
                    val compRange = chars.get(CameraCharacteristics.CONTROL_AE_COMPENSATION_RANGE)
                    val compStep = chars.get(CameraCharacteristics.CONTROL_AE_COMPENSATION_STEP)
                    if (compRange != null && compStep != null && compStep.toDouble() > 0.0) {
                        val steps = (evComp / compStep.toDouble()).roundToInt()
                            .coerceIn(compRange.lower, compRange.upper)
                        builder.set(CaptureRequest.CONTROL_AE_EXPOSURE_COMPENSATION, steps)
                    }
                    lastTotalCaptureResult?.get(CaptureResult.SENSOR_SENSITIVITY)?.let {
                        photoActiveIso = it.toDouble().coerceIn(photoIsoMin.toDouble(), photoIsoMax.toDouble())
                    }
                    lastTotalCaptureResult?.get(CaptureResult.SENSOR_EXPOSURE_TIME)?.let {
                        photoActiveShutterNs = it.coerceIn(photoExpNsMin, photoExpNsMax)
                    }
                }
                !manualIso && manualShutter -> {
                    // Tv (Shutter Priority): Fixed shutter speed, dynamic software Auto-ISO
                    if (prevWasAutoAe) {
                        lastTotalCaptureResult?.get(CaptureResult.SENSOR_SENSITIVITY)?.let {
                            photoActiveIso = it.toDouble().coerceIn(photoIsoMin.toDouble(), photoIsoMax.toDouble())
                        }
                    }
                    photoActiveShutterNs = clampedShutter
                    val autoIsoSeed = photoActiveIso.roundToInt().coerceIn(photoIsoMin, photoIsoMax)
                    builder.set(CaptureRequest.CONTROL_AE_MODE, CaptureRequest.CONTROL_AE_MODE_OFF)
                    builder.set(CaptureRequest.CONTROL_AE_LOCK, false)
                    builder.set(CaptureRequest.SENSOR_EXPOSURE_TIME, clampedShutter)
                    builder.set(CaptureRequest.SENSOR_SENSITIVITY, autoIsoSeed)
                }
                manualIso && !manualShutter -> {
                    // Sv (Sensitivity Priority): Fixed ISO, dynamic software Auto-Shutter
                    if (prevWasAutoAe) {
                        lastTotalCaptureResult?.get(CaptureResult.SENSOR_EXPOSURE_TIME)?.let {
                            photoActiveShutterNs = it.coerceIn(photoExpNsMin, photoExpNsMax)
                        }
                    }
                    photoActiveIso = clampedIso.toDouble()
                    val autoShutterSeed = photoActiveShutterNs.coerceIn(photoExpNsMin, photoExpNsMax)
                    builder.set(CaptureRequest.CONTROL_AE_MODE, CaptureRequest.CONTROL_AE_MODE_OFF)
                    builder.set(CaptureRequest.CONTROL_AE_LOCK, false)
                    builder.set(CaptureRequest.SENSOR_SENSITIVITY, clampedIso)
                    builder.set(CaptureRequest.SENSOR_EXPOSURE_TIME, autoShutterSeed)
                }
                else -> {
                    // M (Full Manual): Both ISO and Shutter fixed
                    photoActiveIso = clampedIso.toDouble()
                    photoActiveShutterNs = clampedShutter
                    builder.set(CaptureRequest.CONTROL_AE_MODE, CaptureRequest.CONTROL_AE_MODE_OFF)
                    builder.set(CaptureRequest.CONTROL_AE_LOCK, false)
                    builder.set(CaptureRequest.SENSOR_SENSITIVITY, clampedIso)
                    builder.set(CaptureRequest.SENSOR_EXPOSURE_TIME, clampedShutter)
                }
            }

            // Sanat Mode 1:1 True-Color live preview tonemap & lens shading
            val shadingModes = chars.get(CameraCharacteristics.SHADING_AVAILABLE_MODES)
            if (shadingModes != null && shadingModes.contains(CameraMetadata.SHADING_MODE_HIGH_QUALITY)) {
                builder.set(CaptureRequest.SHADING_MODE, CameraMetadata.SHADING_MODE_HIGH_QUALITY)
            }
            val lsmModes = chars.get(CameraCharacteristics.STATISTICS_INFO_AVAILABLE_LENS_SHADING_MAP_MODES)
            if (lsmModes != null && lsmModes.contains(CameraMetadata.STATISTICS_LENS_SHADING_MAP_MODE_ON)) {
                builder.set(
                    CaptureRequest.STATISTICS_LENS_SHADING_MAP_MODE,
                    CameraMetadata.STATISTICS_LENS_SHADING_MAP_MODE_ON
                )
            }
            val tonemapModes = chars.get(CameraCharacteristics.TONEMAP_AVAILABLE_TONE_MAP_MODES)
            if (tonemapModes != null) {
                when {
                    tonemapModes.contains(CaptureRequest.TONEMAP_MODE_HIGH_QUALITY) ->
                        builder.set(CaptureRequest.TONEMAP_MODE, CaptureRequest.TONEMAP_MODE_HIGH_QUALITY)
                    tonemapModes.contains(CaptureRequest.TONEMAP_MODE_FAST) ->
                        builder.set(CaptureRequest.TONEMAP_MODE, CaptureRequest.TONEMAP_MODE_FAST)
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
            } else if (aeAfLocked && minFocus > 0.0f) {
                if (builder.get(CaptureRequest.CONTROL_AF_MODE) != CaptureRequest.CONTROL_AF_MODE_AUTO) {
                    builder.set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_AUTO)
                    builder.set(CaptureRequest.CONTROL_AF_TRIGGER, CameraMetadata.CONTROL_AF_TRIGGER_START)
                    session.capture(builder.build(), photoPreviewCaptureCallback, backgroundHandler)
                    builder.set(CaptureRequest.CONTROL_AF_TRIGGER, CameraMetadata.CONTROL_AF_TRIGGER_IDLE)
                }
            } else {
                if (builder.get(CaptureRequest.CONTROL_AF_MODE) == CaptureRequest.CONTROL_AF_MODE_AUTO) {
                    builder.set(CaptureRequest.CONTROL_AF_TRIGGER, CameraMetadata.CONTROL_AF_TRIGGER_CANCEL)
                    session.capture(builder.build(), photoPreviewCaptureCallback, backgroundHandler)
                    builder.set(CaptureRequest.CONTROL_AF_TRIGGER, CameraMetadata.CONTROL_AF_TRIGGER_IDLE)
                }
                builder.set(
                    CaptureRequest.CONTROL_AF_MODE,
                    CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE
                )
            }

            val manualWb = args["manualWb"] as? Boolean ?: false
            val kelvin = (args["kelvin"] as? Number)?.toFloat()
            val tint = (args["tint"] as? Number)?.toFloat() ?: 0.0f
            val rggb = args["rggbGains"] as? List<*>
            val customWbGains = (args["customWbGains"] as? List<*>)?.mapNotNull { (it as? Number)?.toFloat() }
            val customCamToXyz = (args["camToXyzD50"] as? List<*>)?.mapNotNull { (it as? Number)?.toFloat() }
            val hasCustomWb = customWbGains != null && customWbGains.size >= 3
            val hasCustomCcm = customCamToXyz != null && customCamToXyz.size == 9

            if (hasCustomWb || hasCustomCcm || manualWb) {
                val cm1 = extractMatrix3x3(chars.get(CameraCharacteristics.SENSOR_COLOR_TRANSFORM1))
                    ?: floatArrayOf(0.8125f, -0.2734f, -0.1094f, -0.4375f, 1.3281f, 0.0859f, -0.0312f, 0.2578f, 0.4297f)
                val cm2 = extractMatrix3x3(chars.get(CameraCharacteristics.SENSOR_COLOR_TRANSFORM2))
                    ?: floatArrayOf(1.2188f, -0.4688f, -0.4531f, -0.9766f, 2.1797f, -0.2891f, -0.1875f, 0.3750f, 0.6094f)
                val fm1 = extractMatrix3x3(chars.get(CameraCharacteristics.SENSOR_FORWARD_MATRIX1))
                    ?: floatArrayOf(0.5469f, 0.2734f, 0.1406f, 0.1875f, 0.8672f, -0.0547f, -0.0547f, -0.3672f, 1.2500f)
                val fm2 = extractMatrix3x3(chars.get(CameraCharacteristics.SENSOR_FORWARD_MATRIX2))
                    ?: floatArrayOf(0.6016f, -0.0391f, 0.3984f, 0.2734f, 0.4688f, 0.2500f, 0.0547f, -0.6562f, 1.4219f)

                val dngWb = if (manualWb && kelvin != null) {
                    ZameraRustBridge.computeDngKelvinWb(kelvin, tint, cm1, cm2, fm1, fm2)
                } else {
                    null
                }

                builder.set(CaptureRequest.CONTROL_AWB_MODE, CaptureRequest.CONTROL_AWB_MODE_OFF)
                if (hasCustomWb || hasCustomCcm) {
                    val d50ToSrgb = floatArrayOf(
                        3.1338561f, -1.6168667f, -0.4906146f,
                        -0.9787684f, 1.9161415f, 0.0334540f,
                        0.0719453f, -0.2289914f, 1.4052427f
                    )
                    val xyzMat = if (hasCustomCcm) customCamToXyz!!.toFloatArray() else fm1
                    val camToSrgb = FloatArray(9)
                    for (r in 0 until 3) {
                        for (c in 0 until 3) {
                            camToSrgb[r * 3 + c] =
                                d50ToSrgb[r * 3] * xyzMat[c] +
                                d50ToSrgb[r * 3 + 1] * xyzMat[3 + c] +
                                d50ToSrgb[r * 3 + 2] * xyzMat[6 + c]
                        }
                    }
                    val gainsVec = when {
                        hasCustomWb -> {
                            val gRef = customWbGains!![1].coerceAtLeast(1e-4f)
                            RggbChannelVector(
                                (customWbGains[0] / gRef).coerceIn(0.25f, 8.0f),
                                1.0f,
                                1.0f,
                                (customWbGains[2] / gRef).coerceIn(0.25f, 8.0f)
                            )
                        }
                        dngWb != null -> RggbChannelVector(dngWb.first[0], dngWb.first[1], dngWb.first[2], dngWb.first[3])
                        else -> {
                            val np = lastTotalCaptureResult?.get(CaptureResult.SENSOR_NEUTRAL_COLOR_POINT)
                            if (np != null && np.size >= 3) {
                                val nr = np[0].toFloat().coerceAtLeast(1e-4f)
                                val ng = np[1].toFloat().coerceAtLeast(1e-4f)
                                val nb = np[2].toFloat().coerceAtLeast(1e-4f)
                                RggbChannelVector(
                                    (ng / nr).coerceIn(0.25f, 8.0f),
                                    1.0f,
                                    1.0f,
                                    (ng / nb).coerceIn(0.25f, 8.0f)
                                )
                            } else {
                                RggbChannelVector(1.85f, 1.0f, 1.0f, 1.55f)
                            }
                        }
                    }
                    builder.set(
                        CaptureRequest.COLOR_CORRECTION_MODE,
                        CaptureRequest.COLOR_CORRECTION_MODE_TRANSFORM_MATRIX
                    )
                    builder.set(
                        CaptureRequest.COLOR_CORRECTION_TRANSFORM,
                        floatArrayToColorSpaceTransform(camToSrgb)
                    )
                    builder.set(CaptureRequest.COLOR_CORRECTION_GAINS, gainsVec)
                } else if (dngWb != null) {
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
                builder.set(
                    CaptureRequest.COLOR_CORRECTION_MODE,
                    if (artworkLinearMode) {
                        CaptureRequest.COLOR_CORRECTION_MODE_HIGH_QUALITY
                    } else {
                        CaptureRequest.COLOR_CORRECTION_MODE_FAST
                    }
                )
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
                photoPreviewCaptureCallback,
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
            val isPortraitMode = args["isPortraitMode"] as? Boolean ?: false
            val isArtworkMode = args["isArtworkMode"] as? Boolean ?: true
            val losslessPng = args["losslessPng"] as? Boolean ?: false
            val exportPng = isArtworkMode && !isPortraitMode && losslessPng
            val trueColorExt = if (exportPng) "png" else "jpg"
            val trueColorMime = if (exportPng) "image/png" else "image/jpeg"
            val trueColorJpegFile = File(outDir, "${baseName}_TRUECOLOR.${trueColorExt}")
            val dngFile = File(outDir, "${baseName}.dng")

            val captureBuilder = camera.createCaptureRequest(CameraDevice.TEMPLATE_STILL_CAPTURE)
            captureBuilder.addTarget(jpegReader.surface)
            // Fast ZSL-grade hardware JPEG & noise/edge settings to eliminate multi-frame HAL stalls
            captureBuilder.set(CaptureRequest.JPEG_QUALITY, (if (isArtworkMode) 100 else 95).toByte())
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

            val portraitAperture = ((args["portraitAperture"] as? Number)?.toFloat() ?: 2.8f).coerceIn(1.4f, 16.0f)
            val portraitLighting = ((args["portraitLighting"] as? Number)?.toInt() ?: 0).coerceIn(0, 9)
            val portraitLightIntensity = ((args["portraitLightIntensity"] as? Number)?.toFloat() ?: 0.80f).coerceIn(0.0f, 1.0f)
            val portraitSubjectRadius = ((args["portraitSubjectRadius"] as? Number)?.toFloat() ?: 0.36f).coerceIn(0.20f, 0.58f)
            val focusPointX = ((args["focusPointX"] as? Number)?.toFloat() ?: 0.5f).coerceIn(0.08f, 0.92f)
            val focusPointY = ((args["focusPointY"] as? Number)?.toFloat() ?: 0.45f).coerceIn(0.08f, 0.92f)
            val captureRaw = !isPortraitMode && (args["captureRaw"] as? Boolean ?: true) && rawImageReader != null
            val useDisplayP3 = args["useDisplayP3"] as? Boolean ?: false
            val fullResolution = args["fullResolution"] as? Boolean ?: true
            val normalizeExposure = args["normalizeExposure"] as? Boolean ?: true
            val explicitExposureMode = (args["artworkExposureMode"] as? Number)?.toInt()
            val artworkExposureMode = resolveArtworkExposureMode(explicitExposureMode, normalizeExposure)
            val calibrateColorChecker = args["calibrateColorChecker"] as? Boolean ?: false
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
                        prev.get(CaptureRequest.CONTROL_AE_LOCK)?.let {
                            captureBuilder.set(CaptureRequest.CONTROL_AE_LOCK, it)
                        }
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
            val capTonemapModes = physChars.get(CameraCharacteristics.TONEMAP_AVAILABLE_TONE_MAP_MODES)
            when {
                capTonemapModes != null && capTonemapModes.contains(CaptureRequest.TONEMAP_MODE_HIGH_QUALITY) ->
                    captureBuilder.set(CaptureRequest.TONEMAP_MODE, CaptureRequest.TONEMAP_MODE_HIGH_QUALITY)
                capTonemapModes != null && capTonemapModes.contains(CaptureRequest.TONEMAP_MODE_FAST) ->
                    captureBuilder.set(CaptureRequest.TONEMAP_MODE, CaptureRequest.TONEMAP_MODE_FAST)
                else -> previewRequestBuilder?.get(CaptureRequest.TONEMAP_MODE)?.let { tm ->
                    captureBuilder.set(CaptureRequest.TONEMAP_MODE, tm)
                }
            }
            val shadingModes = physChars.get(CameraCharacteristics.SHADING_AVAILABLE_MODES)
            if (shadingModes != null && shadingModes.contains(CameraMetadata.SHADING_MODE_HIGH_QUALITY)) {
                captureBuilder.set(CaptureRequest.SHADING_MODE, CameraMetadata.SHADING_MODE_HIGH_QUALITY)
            }
            val lsmModes = physChars.get(CameraCharacteristics.STATISTICS_INFO_AVAILABLE_LENS_SHADING_MAP_MODES)
            if (lsmModes != null && lsmModes.contains(CameraMetadata.STATISTICS_LENS_SHADING_MAP_MODE_ON)) {
                captureBuilder.set(
                    CaptureRequest.STATISTICS_LENS_SHADING_MAP_MODE,
                    CameraMetadata.STATISTICS_LENS_SHADING_MAP_MODE_ON
                )
            }
            val capturedSensorOrientation = physChars.get(CameraCharacteristics.SENSOR_ORIENTATION) ?: activeSensorOrientation
            val capturedCameraId = charsId

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
                                    dngCreator.setOrientation(exifOrientationFromDegrees(capturedSensorOrientation))
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
                                val rggbShading4x48 = if (!lensShadingApplied) {
                                    extractLensShading4x48(activePhysResult)
                                } else {
                                    null
                                }
                                val ffArray = if (flatFieldGrid != null && flatFieldGrid.size == 48) {
                                    flatFieldGrid.toFloatArray()
                                } else {
                                    null
                                }

                                val plane = rawImg.planes[0]
                                val rawBuffer = plane.buffer
                                rawBuffer.rewind()

                                val isFrontCam = physChars.get(CameraCharacteristics.LENS_FACING) == CameraCharacteristics.LENS_FACING_FRONT
                                var activeWbGains = wbGains
                                var activeHasCustomMatrix = hasCustomMatrix
                                var activeFm1OrCustom = primaryFm1OrCustom
                                var liveCalibrationResultMap: Map<String, Any>? = null

                                if (calibrateColorChecker) {
                                    val uiCorners = if (perspectiveCornersNorm != null && perspectiveCornersNorm.size == 8) {
                                        perspectiveCornersNorm.toFloatArray()
                                    } else {
                                        floatArrayOf(0.15f, 0.20f, 0.85f, 0.20f, 0.85f, 0.80f, 0.15f, 0.80f)
                                    }
                                    val sensorCorners = FloatArray(8)
                                    for (ci in 0 until 4) {
                                        val pt = uiToSensorNorm(
                                            uiCorners[ci * 2],
                                            uiCorners[ci * 2 + 1],
                                            capturedSensorOrientation,
                                            isFrontCam
                                        )
                                        sensorCorners[ci * 2] = pt.first
                                        sensorCorners[ci * 2 + 1] = pt.second
                                    }
                                    val calibOut = ZameraRustBridge.calibrateColorChecker24(
                                        rawDirectBuffer = rawBuffer,
                                        width = rawImg.width,
                                        height = rawImg.height,
                                        rowStride = plane.rowStride,
                                        cfaPattern = cfaPattern,
                                        blackLevel = blackLevel,
                                        whiteLevel = whiteLevel,
                                        cornersNorm = sensorCorners,
                                        flatField8x6 = ffArray,
                                        rggbShading4x48 = rggbShading4x48
                                    )
                                    if (calibOut != null) {
                                        liveCalibrationResultMap = calibOut.reportMap
                                        activeWbGains = calibOut.wbGains
                                        activeFm1OrCustom = calibOut.camToXyzD50Flat
                                        activeHasCustomMatrix = true
                                    }
                                    rawBuffer.rewind()
                                }

                                val effectiveNeutralForCct = when {
                                    activeHasCustomMatrix -> null
                                    customWbGains != null && customWbGains.size >= 3 -> {
                                        val gRef = customWbGains[1].coerceAtLeast(1e-4f)
                                        floatArrayOf(
                                            (gRef / customWbGains[0].coerceAtLeast(1e-4f)).coerceIn(0.05f, 10.0f),
                                            1.0f,
                                            (gRef / customWbGains[2].coerceAtLeast(1e-4f)).coerceIn(0.05f, 10.0f)
                                        )
                                    }
                                    else -> asShotNeutral
                                }
                                val effectiveExposureMode = if (isArtworkMode) {
                                    artworkExposureMode
                                } else {
                                    if (args["normalizeExposure"] == true) 1 else 0
                                }
                                val postRawBoost = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                                    ((activePhysResult.get(CaptureResult.CONTROL_POST_RAW_SENSITIVITY_BOOST) ?: 100).toFloat() / 100.0f)
                                        .coerceIn(1.0f, 6.0f)
                                } else {
                                    1.0f
                                }
                                val referenceMidY = if (isArtworkMode && effectiveExposureMode == 2) {
                                    measureJpegTrimmedLinearLuminance(jpegBytes)
                                } else {
                                    0.0f
                                }
                                val capturedIso = activePhysResult.get(CaptureResult.SENSOR_SENSITIVITY)
                                val capturedExpNs = activePhysResult.get(CaptureResult.SENSOR_EXPOSURE_TIME)
                                val capturedAperture = activePhysResult.get(CaptureResult.LENS_APERTURE)
                                    ?: physChars.get(CameraCharacteristics.LENS_INFO_AVAILABLE_APERTURES)?.firstOrNull()
                                val capturedFocalMm = activePhysResult.get(CaptureResult.LENS_FOCAL_LENGTH)
                                    ?: physChars.get(CameraCharacteristics.LENS_INFO_AVAILABLE_FOCAL_LENGTHS)?.firstOrNull()

                                // Fixes B1, B2, B3, B7:
                                // - In Sanat Mode (`isArtworkMode == true`), develop full-res (4096x3072 -> rotated 3072x4096 12.6 MP)
                                //   with DNG CCT interpolation (`FM1`/`FM2`) and True-Tone Exposure Mode!
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
                                    wbGains = activeWbGains,
                                    fm1OrCustomMatrix = activeFm1OrCustom,
                                    asShotNeutralForCct = effectiveNeutralForCct,
                                    cm1 = cm1,
                                    cm2 = cm2,
                                    fm2 = fm2,
                                    flatField8x6 = ffArray,
                                    rggbShading4x48 = rggbShading4x48,
                                    useDisplayP3 = useDisplayP3,
                                    exposureMode = effectiveExposureMode,
                                    fullResolution = isArtworkMode && fullResolution && !isFrontCam,
                                    writeTrueColorBitmap = isArtworkMode,
                                    sensorOrientationDegrees = capturedSensorOrientation,
                                    isFrontCamera = isFrontCam,
                                    applyPerspectiveWarp = isArtworkMode && applyPerspectiveWarp,
                                    perspectiveCornersNorm = if (perspectiveCornersNorm != null && perspectiveCornersNorm.size == 8) perspectiveCornersNorm.toFloatArray() else null,
                                    losslessPng = exportPng,
                                    iso = capturedIso,
                                    exposureTimeNs = capturedExpNs,
                                    aperture = capturedAperture,
                                    focalLengthMm = capturedFocalMm,
                                    referenceMidY = referenceMidY,
                                    sensorBaselineGain = postRawBoost,
                                    outFile = trueColorJpegFile
                                )

                                val useTrueColorOut = isArtworkMode && trueColorJpegFile.exists()
                                val primaryFileToExport = if (useTrueColorOut) {
                                    trueColorJpegFile
                                } else {
                                    oemJpegFile
                                }
                                val exportExt = if (useTrueColorOut) trueColorExt else "jpg"
                                val exportMime = if (useTrueColorOut) trueColorMime else "image/jpeg"
                                val suffix = if (useTrueColorOut) "TRUECOLOR" else "PRO"
                                mediaStoreJpegUri = saveFileToMediaStoreDcim(
                                    sourceFile = primaryFileToExport,
                                    displayName = "${baseName}_${suffix}.${exportExt}",
                                    mimeType = exportMime
                                )

                                statsMap = mapOf(
                                    "blackLevel" to blackLevel.toList(),
                                    "whiteLevel" to whiteLevel.toDouble(),
                                    "cfaPattern" to cfaPattern,
                                    "lensShadingApplied" to (lensShadingApplied || rggbShading4x48 != null),
                                    "wbGainsUsed" to activeWbGains.toList(),
                                    "centerLinearCamRgb" to devResult.centerLinearCamRgb,
                                    "centerLabD50" to devResult.centerLabD50,
                                    "colorSpaceTag" to (if (useDisplayP3) "Display P3" else "sRGB"),
                                    "liveCalibrationResult" to liveCalibrationResultMap,
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
                            val portraitOutcome = applyPortraitBokehAndLighting(
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
                                "Portrait capture latency: ${portraitProcessMs}ms (depthActive=${portraitOutcome.depthActive})"
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
                                "portraitDepthActive" to portraitOutcome.depthActive,
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
                            put("cameraId", capturedCameraId)
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
     * Extracts and bilinearly resamples Camera2 4-channel RGGB `LensShadingMap` into
     * `4 x 48` (`8x6` per channel `[R, Gr, Gb, B]`) for `zamera_core` when
     * `SENSOR_INFO_LENS_SHADING_APPLIED == false`.
     */
    private fun extractLensShading4x48(result: CaptureResult): FloatArray? {
        val lsm: LensShadingMap = try {
            result.get(CaptureResult.STATISTICS_LENS_SHADING_CORRECTION_MAP)
        } catch (e: Throwable) {
            android.util.Log.w("ZameraCapture", "LensShadingMap read warning: ${e.message}")
            null
        } ?: return null
        val cols = lsm.columnCount
        val rows = lsm.rowCount
        if (cols < 1 || rows < 1) return null
        val out = FloatArray(4 * 48)
        val channels = intArrayOf(
            RggbChannelVector.RED,
            RggbChannelVector.GREEN_EVEN,
            RggbChannelVector.GREEN_ODD,
            RggbChannelVector.BLUE
        )
        for (chIdx in 0 until 4) {
            val ch = channels[chIdx]
            val chOffset = chIdx * 48
            for (gy in 0 until 6) {
                val fy = if (rows == 1) 0f else (gy.toFloat() / 5.0f) * (rows - 1).toFloat()
                val y0 = fy.toInt().coerceIn(0, rows - 1)
                val y1 = (y0 + 1).coerceIn(0, rows - 1)
                val ty = fy - y0.toFloat()
                for (gx in 0 until 8) {
                    val fx = if (cols == 1) 0f else (gx.toFloat() / 7.0f) * (cols - 1).toFloat()
                    val x0 = fx.toInt().coerceIn(0, cols - 1)
                    val x1 = (x0 + 1).coerceIn(0, cols - 1)
                    val tx = fx - x0.toFloat()
                    val g00 = lsm.getGainFactor(ch, x0, y0)
                    val g10 = lsm.getGainFactor(ch, x1, y0)
                    val g01 = lsm.getGainFactor(ch, x0, y1)
                    val g11 = lsm.getGainFactor(ch, x1, y1)
                    val top = g00 + (g10 - g00) * tx
                    val bot = g01 + (g11 - g01) * tx
                    out[chOffset + gy * 8 + gx] = (top + (bot - top) * ty).coerceIn(1.0f, 8.0f)
                }
            }
        }
        return out
    }

    /**
     * Maps normalized `[0, 1]` upright UI coordinates `(ux, uy)` back into unrotated
     * `RAW_SENSOR` `[0, 1]` coordinates `(sx, sy)` matching `postRotate` + `postScale`.
     */
    private fun uiToSensorNorm(
        ux: Float,
        uy: Float,
        sensorOrientationDegrees: Int,
        isFrontCamera: Boolean
    ): Pair<Float, Float> {
        val rx = (if (isFrontCamera) 1.0f - ux else ux).coerceIn(0.0f, 1.0f)
        val ry = uy.coerceIn(0.0f, 1.0f)
        return when ((sensorOrientationDegrees % 360 + 360) % 360) {
            90 -> Pair(ry, (1.0f - rx).coerceIn(0.0f, 1.0f))
            180 -> Pair((1.0f - rx).coerceIn(0.0f, 1.0f), (1.0f - ry).coerceIn(0.0f, 1.0f))
            270 -> Pair((1.0f - ry).coerceIn(0.0f, 1.0f), rx)
            else -> Pair(rx, ry)
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
    private data class NeuralSegResult(
        val mask: FloatArray,
        val maxConf: Float,
        val usedSubjectSeg: Boolean,
        val areaRatio: Float
    )

    private data class MulticlassSegResult(
        val humanProb: FloatArray,
        val skinProb: FloatArray,
        val hairProb: FloatArray,
        val clothesProb: FloatArray,
        val accessProb: FloatArray,
        val maxHumanConf: Float,
        val humanAreaRatio: Float
    )

    private data class PortraitMatteResult(
        val meanA: FloatArray,
        val meanB: FloatArray,
        val humanAreaRatio: Float,
        val depthMap: FloatArray?,
        val focusDepth: Float
    )

    /**
     * Runs a single 256x256 pass of Google's flagship 6-Class `selfie_multiclass_256x256.tflite` (`16.4 MB`)
     * returning a `[256 * 256 * 6]` array of normalized class probabilities:
     * `[0: background, 1: hair, 2: body-skin (hands/fingers/arms/neck), 3: face-skin, 4: clothes, 5: accessories (eyeglasses/held phone)]`.
     */
    private fun runSingleMulticlassPass(bmp: Bitmap): FloatArray? {
        val interpreter = getOrCreateMulticlassInterpreter() ?: return null
        val mw = 256
        val mh = 256
        val n = mw * mh
        val scaled = Bitmap.createScaledBitmap(bmp, mw, mh, true)
        val px = IntArray(n)
        scaled.getPixels(px, 0, mw, 0, 0, mw, mh)
        if (scaled !== bmp) scaled.recycle()

        val inBuf = ByteBuffer.allocateDirect(n * 3 * 4).order(ByteOrder.nativeOrder())
        val inFloats = FloatArray(n * 3)
        val inv255 = 1.0f / 255.0f
        var k = 0
        for (i in 0 until n) {
            val c = px[i]
            inFloats[k++] = ((c shr 16) and 0xFF) * inv255
            inFloats[k++] = ((c shr 8) and 0xFF) * inv255
            inFloats[k++] = (c and 0xFF) * inv255
        }
        inBuf.asFloatBuffer().put(inFloats)
        inBuf.rewind()

        val outBuf = ByteBuffer.allocateDirect(n * 6 * 4).order(ByteOrder.nativeOrder())
        try {
            synchronized(multiclassModelLock) {
                interpreter.run(inBuf, outBuf)
            }
        } catch (t: Throwable) {
            android.util.Log.e("ZameraPortrait", "SelfieMulticlass inference error: ${t.message}", t)
            return null
        }
        outBuf.rewind()
        val rawOut = FloatArray(n * 6)
        outBuf.asFloatBuffer().get(rawOut)

        for (i in 0 until n) {
            val base = i * 6
            var c0 = rawOut[base]
            var c1 = rawOut[base + 1]
            var c2 = rawOut[base + 2]
            var c3 = rawOut[base + 3]
            var c4 = rawOut[base + 4]
            var c5 = rawOut[base + 5]
            val sum = c0 + c1 + c2 + c3 + c4 + c5
            val isProb = c0 >= 0f && c1 >= 0f && c2 >= 0f && c3 >= 0f && c4 >= 0f && c5 >= 0f &&
                sum in 0.96f..1.04f
            if (!isProb) {
                var maxV = c0
                if (c1 > maxV) maxV = c1
                if (c2 > maxV) maxV = c2
                if (c3 > maxV) maxV = c3
                if (c4 > maxV) maxV = c4
                if (c5 > maxV) maxV = c5
                c0 = kotlin.math.exp((c0 - maxV).coerceIn(-20f, 0f))
                c1 = kotlin.math.exp((c1 - maxV).coerceIn(-20f, 0f))
                c2 = kotlin.math.exp((c2 - maxV).coerceIn(-20f, 0f))
                c3 = kotlin.math.exp((c3 - maxV).coerceIn(-20f, 0f))
                c4 = kotlin.math.exp((c4 - maxV).coerceIn(-20f, 0f))
                c5 = kotlin.math.exp((c5 - maxV).coerceIn(-20f, 0f))
            }
            val invSum = 1.0f / (c0 + c1 + c2 + c3 + c4 + c5).coerceAtLeast(1e-6f)
            rawOut[base] = (c0 * invSum).coerceIn(0f, 1f)
            rawOut[base + 1] = (c1 * invSum).coerceIn(0f, 1f)
            rawOut[base + 2] = (c2 * invSum).coerceIn(0f, 1f)
            rawOut[base + 3] = (c3 * invSum).coerceIn(0f, 1f)
            rawOut[base + 4] = (c4 * invSum).coerceIn(0f, 1f)
            rawOut[base + 5] = (c5 * invSum).coerceIn(0f, 1f)
        }
        return rawOut
    }

    /**
     * Runs 2-Pass Google MediaPipe 6-Class Multiclass Segmentation (`selfie_multiclass_256x256.tflite`):
     * - Pass 1 (Global 256x256): Extracts full-frame Hair (c1), Body-Skin/Hands/Fingers (c2), Face-Skin (c3),
     *   Clothes/Sleeves (c4), and Held Accessories/Glasses (c5).
     * - Pass 2 (High-Resolution Hand/Finger & Head Zoomed ROI 256x256): Crops around the detected skin/hair
     *   (or full body in medium/wide shots) so spread fingers, thumbs, ears, and held phones receive 2.5x–3.2x
     *   higher neural spatial resolution in ~110ms total!
     */
    private fun runMulticlassSegmentation(srcBmp: Bitmap, segW: Int, segH: Int): MulticlassSegResult? {
        val t0 = System.currentTimeMillis()
        val global256 = runSingleMulticlassPass(srcBmp) ?: return null
        val mw = 256
        val mh = 256
        val n = segW * segH
        val humanProb = FloatArray(n)
        val skinProb = FloatArray(n)
        val hairProb = FloatArray(n)
        val clothesProb = FloatArray(n)
        val accessProb = FloatArray(n)

        var maxHumanConf = 0f
        var bodyStrongCount = 0
        for (y in 0 until segH) {
            val gy = (y.toFloat() / (segH - 1).coerceAtLeast(1)) * (mh - 1)
            val y0 = gy.toInt().coerceIn(0, mh - 2)
            val fy = gy - y0
            val rowOff = y * segW
            for (x in 0 until segW) {
                val gx = (x.toFloat() / (segW - 1).coerceAtLeast(1)) * (mw - 1)
                val x0 = gx.toInt().coerceIn(0, mw - 2)
                val fx = gx - x0
                val w00 = (1f - fx) * (1f - fy)
                val w10 = fx * (1f - fy)
                val w01 = (1f - fx) * fy
                val w11 = fx * fy
                val b00 = (y0 * mw + x0) * 6
                val b10 = b00 + 6
                val b01 = ((y0 + 1) * mw + x0) * 6
                val b11 = b01 + 6

                val c1 = global256[b00 + 1] * w00 + global256[b10 + 1] * w10 + global256[b01 + 1] * w01 + global256[b11 + 1] * w11
                val c2 = global256[b00 + 2] * w00 + global256[b10 + 2] * w10 + global256[b01 + 2] * w01 + global256[b11 + 2] * w11
                val c3 = global256[b00 + 3] * w00 + global256[b10 + 3] * w10 + global256[b01 + 3] * w01 + global256[b11 + 3] * w11
                val c4 = global256[b00 + 4] * w00 + global256[b10 + 4] * w10 + global256[b01 + 4] * w01 + global256[b11 + 4] * w11
                val c5 = global256[b00 + 5] * w00 + global256[b10 + 5] * w10 + global256[b01 + 5] * w01 + global256[b11 + 5] * w11

                val idx = rowOff + x
                val sk = (c2 + c3).coerceIn(0f, 1f)
                val hm = (c1 + sk + c4).coerceIn(0f, 1f)
                hairProb[idx] = c1.coerceIn(0f, 1f)
                skinProb[idx] = sk
                clothesProb[idx] = c4.coerceIn(0f, 1f)
                accessProb[idx] = c5.coerceIn(0f, 1f)
                humanProb[idx] = hm
                if (hm > maxHumanConf) maxHumanConf = hm
                if (hm >= 0.48f) bodyStrongCount++
            }
        }

        // Pass 2: Zoomed High-Resolution ROI Pass for Hands/Spread Fingers/Head (or Full Body on Medium/Wide Shots)
        if (maxHumanConf >= 0.45f && bodyStrongCount >= n / 120) {
            try {
                val isWideBodyShot = bodyStrongCount < (n * 42) / 100
                var minRx = segW; var maxRx = 0; var minRy = segH; var maxRy = 0
                for (y in 0 until segH) {
                    val row = y * segW
                    for (x in 0 until segW) {
                        val i = row + x
                        val hit = if (isWideBodyShot) {
                            humanProb[i] >= 0.22f
                        } else {
                            skinProb[i] >= 0.14f || hairProb[i] >= 0.24f
                        }
                        if (hit) {
                            if (x < minRx) minRx = x
                            if (x > maxRx) maxRx = x
                            if (y < minRy) minRy = y
                            if (y > maxRy) maxRy = y
                        }
                    }
                }
                if (maxRx > minRx + 16 && maxRy > minRy + 16) {
                    val spanW = (maxRx - minRx).coerceAtLeast(24)
                    val spanH = (maxRy - minRy).coerceAtLeast(24)
                    val roiX0 = (minRx - (spanW * 0.24f).toInt()).coerceIn(0, segW - 32)
                    val roiX1 = (maxRx + (spanW * 0.24f).toInt()).coerceIn(roiX0 + 32, segW - 1)
                    val roiY0 = (minRy - (spanH * 0.18f).toInt()).coerceIn(0, segH - 32)
                    val roiY1 = (maxRy + (spanH * 0.22f).toInt()).coerceIn(roiY0 + 32, segH - 1)
                    val rw = roiX1 - roiX0 + 1
                    val rh = roiY1 - roiY0 + 1
                    if (rw * rh < (n * 86) / 100) {
                        val fw = srcBmp.width
                        val fh = srcBmp.height
                        val cx0 = (roiX0 * fw / segW).coerceIn(0, fw - 32)
                        val cy0 = (roiY0 * fh / segH).coerceIn(0, fh - 32)
                        val cw = (rw * fw / segW).coerceIn(32, fw - cx0)
                        val ch = (rh * fh / segH).coerceIn(32, fh - cy0)
                        val cropBmp = Bitmap.createBitmap(srcBmp, cx0, cy0, cw, ch)
                        val roi256 = runSingleMulticlassPass(cropBmp)
                        if (cropBmp !== srcBmp) cropBmp.recycle()
                        if (roi256 != null) {
                            val marginX = (rw * 0.08f).coerceAtLeast(4f)
                            val marginY = (rh * 0.08f).coerceAtLeast(4f)
                            for (y in roiY0..roiY1) {
                                val ly = (y - roiY0).toFloat() / (rh - 1).coerceAtLeast(1)
                                val gy = (ly * (mh - 1)).coerceIn(0f, (mh - 1).toFloat())
                                val y0 = gy.toInt().coerceIn(0, mh - 2)
                                val fy = gy - y0
                                val wy = kotlin.math.min((y - roiY0) / marginY, (roiY1 - y) / marginY).coerceIn(0f, 1f)
                                val rowOff = y * segW
                                for (x in roiX0..roiX1) {
                                    val lx = (x - roiX0).toFloat() / (rw - 1).coerceAtLeast(1)
                                    val gx = (lx * (mw - 1)).coerceIn(0f, (mw - 1).toFloat())
                                    val x0 = gx.toInt().coerceIn(0, mw - 2)
                                    val fx = gx - x0
                                    val wx = kotlin.math.min((x - roiX0) / marginX, (roiX1 - x) / marginX).coerceIn(0f, 1f)
                                    val wBlend = (wx * wy * 0.85f).coerceIn(0f, 0.85f)

                                    val w00 = (1f - fx) * (1f - fy)
                                    val w10 = fx * (1f - fy)
                                    val w01 = (1f - fx) * fy
                                    val w11 = fx * fy
                                    val b00 = (y0 * mw + x0) * 6
                                    val b10 = b00 + 6
                                    val b01 = ((y0 + 1) * mw + x0) * 6
                                    val b11 = b01 + 6

                                    val rc1 = roi256[b00 + 1] * w00 + roi256[b10 + 1] * w10 + roi256[b01 + 1] * w01 + roi256[b11 + 1] * w11
                                    val rc2 = roi256[b00 + 2] * w00 + roi256[b10 + 2] * w10 + roi256[b01 + 2] * w01 + roi256[b11 + 2] * w11
                                    val rc3 = roi256[b00 + 3] * w00 + roi256[b10 + 3] * w10 + roi256[b01 + 3] * w01 + roi256[b11 + 3] * w11
                                    val rc4 = roi256[b00 + 4] * w00 + roi256[b10 + 4] * w10 + roi256[b01 + 4] * w01 + roi256[b11 + 4] * w11
                                    val rc5 = roi256[b00 + 5] * w00 + roi256[b10 + 5] * w10 + roi256[b01 + 5] * w01 + roi256[b11 + 5] * w11

                                    val idx = rowOff + x
                                    val rSk = (rc2 + rc3).coerceIn(0f, 1f)
                                    val rHm = (rc1 + rSk + rc4).coerceIn(0f, 1f)
                                    hairProb[idx] = (hairProb[idx] * (1f - wBlend) + rc1 * wBlend).coerceIn(0f, 1f)
                                    skinProb[idx] = (skinProb[idx] * (1f - wBlend) + rSk * wBlend).coerceIn(0f, 1f)
                                    clothesProb[idx] = kotlin.math.max(clothesProb[idx], rc4 * wBlend).coerceIn(0f, 1f)
                                    accessProb[idx] = (accessProb[idx] * (1f - wBlend) + rc5 * wBlend).coerceIn(0f, 1f)
                                    humanProb[idx] = (humanProb[idx] * (1f - wBlend) + rHm * wBlend).coerceIn(0f, 1f)
                                    if (humanProb[idx] > maxHumanConf) maxHumanConf = humanProb[idx]
                                }
                            }
                        }
                    }
                }
            } catch (t: Throwable) {
                android.util.Log.w("ZameraPortrait", "SelfieMulticlass ROI Pass2 warning: ${t.message}")
            }
        }

        var finalStrong = 0
        for (i in 0 until n) {
            if (humanProb[i] >= 0.48f) finalStrong++
        }
        val areaRatio = finalStrong.toFloat() / n.coerceAtLeast(1).toFloat()
        android.util.Log.i(
            "ZameraPortrait",
            "SelfieMulticlass 6-class ready in ${System.currentTimeMillis() - t0}ms (maxConf=$maxHumanConf, area=$areaRatio)"
        )
        return MulticlassSegResult(
            humanProb = humanProb,
            skinProb = skinProb,
            hairProb = hairProb,
            clothesProb = clothesProb,
            accessProb = accessProb,
            maxHumanConf = maxHumanConf,
            humanAreaRatio = areaRatio
        )
    }

    /**
     * Runs bundled `depth_anything_v2_small.tflite` (`[1, 3, 518, 686]` NCHW -> `[1, 518, 686]` relative inverse depth)
     * with isotropic edge-replicated letterboxing for vertical/arbitrary aspect ratios, mapping ONLY the active ROI
     * onto `segW x segH` normalized into `[0.0 .. 1.0]` (`1.0` = closest foreground, `0.0` = far background).
     */
    private fun runDepthAnything3dMap(srcBmp: Bitmap, segW: Int, segH: Int): FloatArray? {
        val t0 = System.currentTimeMillis()
        val interpreter = getOrCreateDepthInterpreter() ?: return null
        val dw = 686
        val dh = 518
        val planeSize = dw * dh
        val geom = PortraitOpticalEngine.computeIsotropicLetterbox(srcBmp.width, srcBmp.height, dw, dh)

        val activeBmp = Bitmap.createScaledBitmap(srcBmp, geom.activeW, geom.activeH, true)
        val activePx = IntArray(geom.activeW * geom.activeH)
        activeBmp.getPixels(activePx, 0, geom.activeW, 0, 0, geom.activeW, geom.activeH)
        if (activeBmp !== srcBmp) activeBmp.recycle()

        val inBuf = ByteBuffer.allocateDirect(3 * planeSize * 4).order(ByteOrder.nativeOrder())
        val chR = FloatArray(planeSize)
        val chG = FloatArray(planeSize)
        val chB = FloatArray(planeSize)
        val inv255 = 1.0f / 255.0f
        val actW = geom.activeW
        val actH = geom.activeH
        val padX = geom.padX
        val padY = geom.padY

        for (ty in 0 until dh) {
            val ay = (ty - padY).coerceIn(0, actH - 1)
            val aRow = ay * actW
            val tRow = ty * dw
            for (tx in 0 until dw) {
                val ax = (tx - padX).coerceIn(0, actW - 1)
                val c = activePx[aRow + ax]
                val dstIdx = tRow + tx
                chR[dstIdx] = (((c shr 16) and 0xFF) * inv255 - 0.485f) / 0.229f
                chG[dstIdx] = (((c shr 8) and 0xFF) * inv255 - 0.456f) / 0.224f
                chB[dstIdx] = ((c and 0xFF) * inv255 - 0.406f) / 0.225f
            }
        }
        val fb = inBuf.asFloatBuffer()
        fb.put(chR)
        fb.put(chG)
        fb.put(chB)
        inBuf.rewind()

        val outBuf = ByteBuffer.allocateDirect(planeSize * 4).order(ByteOrder.nativeOrder())
        try {
            synchronized(depthModelLock) {
                interpreter.run(inBuf, outBuf)
            }
        } catch (t: Throwable) {
            android.util.Log.e("ZameraPortrait", "DepthAnythingV2 inference error: ${t.message}", t)
            return null
        }
        outBuf.rewind()
        val rawDepth = FloatArray(planeSize)
        outBuf.asFloatBuffer().get(rawDepth)

        val out = PortraitOpticalEngine.resampleLetterboxDepthRoi(rawDepth, geom, segW, segH) ?: return null
        android.util.Log.i(
            "ZameraPortrait",
            "DepthAnythingV2 3D map ready in ${System.currentTimeMillis() - t0}ms (activeRoi=${actW}x${actH}, pad=${padX},${padY})"
        )
        return out
    }

    /**
     * Runs bundled `u2netp.tflite` (`[1, 320, 320, 3]` NHWC -> 7 multi-scale sigmoid saliency outputs `[1, 320, 320, 1]`)
     * fusing output index `3` (`PartitionedCall:0` -> `d0`) and `0` (`PartitionedCall:1` -> `d1`) as `0.78f * d0 + 0.22f * d1`
     * WITHOUT low-signal min-max noise inflation.
     */
    private fun runSingleU2NetPass(bmp: Bitmap): FloatArray? {
        val interpreter = getOrCreateU2NetInterpreter() ?: return null
        val uw = 320
        val uh = 320
        val n = uw * uh
        val scaled = Bitmap.createScaledBitmap(bmp, uw, uh, true)
        val px = IntArray(n)
        scaled.getPixels(px, 0, uw, 0, 0, uw, uh)
        if (scaled !== bmp) scaled.recycle()

        val inBuf = ByteBuffer.allocateDirect(n * 3 * 4).order(ByteOrder.nativeOrder())
        val inFloats = FloatArray(n * 3)
        val inv255 = 1.0f / 255.0f
        var k = 0
        for (i in 0 until n) {
            val c = px[i]
            inFloats[k++] = (((c shr 16) and 0xFF) * inv255 - 0.485f) / 0.229f
            inFloats[k++] = (((c shr 8) and 0xFF) * inv255 - 0.456f) / 0.224f
            inFloats[k++] = ((c and 0xFF) * inv255 - 0.406f) / 0.225f
        }
        inBuf.asFloatBuffer().put(inFloats)
        inBuf.rewind()

        val outputs = HashMap<Int, Any>(7)
        val outBuf0 = ByteBuffer.allocateDirect(n * 4).order(ByteOrder.nativeOrder())
        val outBuf3 = ByteBuffer.allocateDirect(n * 4).order(ByteOrder.nativeOrder())
        val scratchOutBuf = ByteBuffer.allocateDirect(n * 4).order(ByteOrder.nativeOrder())
        for (idx in 0 until 7) {
            outputs[idx] = when (idx) {
                0 -> outBuf0
                3 -> outBuf3
                else -> scratchOutBuf.duplicate().order(ByteOrder.nativeOrder())
            }
        }
        try {
            synchronized(u2netModelLock) {
                interpreter.runForMultipleInputsOutputs(arrayOf<Any>(inBuf), outputs)
            }
        } catch (t: Throwable) {
            android.util.Log.e("ZameraPortrait", "U2NetP inference error: ${t.message}", t)
            return null
        }
        outBuf0.rewind()
        outBuf3.rewind()
        val d1 = FloatArray(n)
        val d0 = FloatArray(n)
        outBuf0.asFloatBuffer().get(d1)
        outBuf3.asFloatBuffer().get(d0)

        return PortraitOpticalEngine.fuseCalibratedU2NetOutputs(d0, d1)
    }

    /**
     * Runs U²-NetP full-frame (reusing `cachedGlobal320` if available) and optionally refines a zoomed ROI around
     * `(focusX, focusY)` when genuine calibrated saliency exists there, returning `(global320, matteSegWxSegH)`.
     */
    private fun runU2NetSalientMatting(
        srcBmp: Bitmap,
        segW: Int,
        segH: Int,
        focusX: Float,
        focusY: Float,
        cachedGlobal320: FloatArray? = null
    ): Pair<FloatArray, FloatArray>? {
        val t0 = System.currentTimeMillis()
        val uw = 320
        val uh = 320
        val global320 = if (cachedGlobal320 != null && cachedGlobal320.size >= uw * uh) {
            cachedGlobal320
        } else {
            runSingleU2NetPass(srcBmp) ?: return null
        }
        val out = FloatArray(segW * segH)
        for (y in 0 until segH) {
            val gy = (y.toFloat() / (segH - 1).coerceAtLeast(1)) * (uh - 1)
            val y0 = gy.toInt().coerceIn(0, uh - 2)
            val fy = gy - y0
            val rowOff = y * segW
            for (x in 0 until segW) {
                val gx = (x.toFloat() / (segW - 1).coerceAtLeast(1)) * (uw - 1)
                val x0 = gx.toInt().coerceIn(0, uw - 2)
                val fx = gx - x0
                out[rowOff + x] = global320[y0 * uw + x0] * (1f - fx) * (1f - fy) +
                    global320[y0 * uw + x0 + 1] * fx * (1f - fy) +
                    global320[(y0 + 1) * uw + x0] * (1f - fx) * fy +
                    global320[(y0 + 1) * uw + x0 + 1] * fx * fy
            }
        }

        // Only run zoomed ROI pass if calibrated global saliency confirms a real salient candidate near (focusX, focusY)
        val probeGx = (focusX.coerceIn(0f, 1f) * (uw - 1)).toInt().coerceIn(0, uw - 1)
        val probeGy = (focusY.coerceIn(0f, 1f) * (uh - 1)).toInt().coerceIn(0, uh - 1)
        var localGlobalPeak = 0f
        for (py in (probeGy - 28).coerceAtLeast(0)..(probeGy + 28).coerceAtMost(uh - 1)) {
            val rOff = py * uw
            for (px in (probeGx - 28).coerceAtLeast(0)..(probeGx + 28).coerceAtMost(uw - 1)) {
                val v = global320[rOff + px]
                if (v > localGlobalPeak) localGlobalPeak = v
            }
        }

        if (localGlobalPeak >= 0.30f) {
            try {
                val fw = srcBmp.width
                val fh = srcBmp.height
                val roiW = (fw * 0.68f).toInt().coerceIn(64, fw)
                val roiH = (fh * 0.68f).toInt().coerceIn(64, fh)
                val cx = (focusX * fw).toInt()
                val cy = (focusY * fh).toInt()
                val rx0 = (cx - roiW / 2).coerceIn(0, (fw - roiW).coerceAtLeast(0))
                val ry0 = (cy - roiH / 2).coerceIn(0, (fh - roiH).coerceAtLeast(0))
                val crop = Bitmap.createBitmap(srcBmp, rx0, ry0, roiW, roiH)
                val roi320 = runSingleU2NetPass(crop)
                if (crop !== srcBmp) crop.recycle()
                if (roi320 != null) {
                    val sx0 = (rx0 * segW / fw).coerceIn(0, segW - 1)
                    val sx1 = ((rx0 + roiW) * segW / fw).coerceIn(sx0 + 1, segW - 1)
                    val sy0 = (ry0 * segH / fh).coerceIn(0, segH - 1)
                    val sy1 = ((ry0 + roiH) * segH / fh).coerceIn(sy0 + 1, segH - 1)
                    val rw = (sx1 - sx0).coerceAtLeast(1)
                    val rh = (sy1 - sy0).coerceAtLeast(1)
                    val marginX = (rw * 0.10f).coerceAtLeast(4f)
                    val marginY = (rh * 0.10f).coerceAtLeast(4f)
                    for (y in sy0..sy1) {
                        val ly = (y - sy0).toFloat() / rh
                        val gy = (ly * (uh - 1)).coerceIn(0f, (uh - 1).toFloat())
                        val y0 = gy.toInt().coerceIn(0, uh - 2)
                        val fy = gy - y0
                        val wy = kotlin.math.min((y - sy0) / marginY, (sy1 - y) / marginY).coerceIn(0f, 1f)
                        val rowOff = y * segW
                        for (x in sx0..sx1) {
                            val lx = (x - sx0).toFloat() / rw
                            val gx = (lx * (uw - 1)).coerceIn(0f, (uw - 1).toFloat())
                            val x0 = gx.toInt().coerceIn(0, uw - 2)
                            val fx = gx - x0
                            val wx = kotlin.math.min((x - sx0) / marginX, (sx1 - x) / marginX).coerceIn(0f, 1f)
                            val wBlend = (wx * wy * 0.60f).coerceIn(0f, 0.60f)
                            val rv = roi320[y0 * uw + x0] * (1f - fx) * (1f - fy) +
                                roi320[y0 * uw + x0 + 1] * fx * (1f - fy) +
                                roi320[(y0 + 1) * uw + x0] * (1f - fx) * fy +
                                roi320[(y0 + 1) * uw + x0 + 1] * fx * fy
                            out[rowOff + x] = (out[rowOff + x] * (1f - wBlend) + rv * wBlend).coerceIn(0f, 1f)
                        }
                    }
                }
            } catch (t: Throwable) {
                android.util.Log.w("ZameraPortrait", "U2NetP ROI pass warning: ${t.message}")
            }
        }
        android.util.Log.i(
            "ZameraPortrait",
            "U2NetP calibrated matte ready in ${System.currentTimeMillis() - t0}ms (peak=$localGlobalPeak)"
        )
        return Pair(global320, out)
    }

    /**
     * Computes the Focused Subject's 3D Depth Plane (`focusDepth`) and a per-pixel 3D Depth Gate (`depthGate[i] ∈ [0..1]`).
     */
    private fun computeSubjectDepthGate(
        depthMap: FloatArray?,
        mlMask: FloatArray,
        u2netMask: FloatArray?,
        segW: Int,
        segH: Int,
        focusX: Float,
        focusY: Float,
        hasStrongHuman: Boolean
    ): Pair<Float, FloatArray> {
        val n = segW * segH
        if (depthMap == null) {
            return Pair(0.70f, FloatArray(n) { 1.0f })
        }
        val cx = (focusX * (segW - 1)).roundToInt().coerceIn(0, segW - 1)
        val cy = (focusY * (segH - 1)).roundToInt().coerceIn(0, segH - 1)

        val depthSamples = FloatArray(4096)
        var dCount = 0
        if (hasStrongHuman) {
            for (y in 0 until segH step 3) {
                val row = y * segW
                for (x in 0 until segW step 3) {
                    val i = row + x
                    if (mlMask[i] >= 0.78f && dCount < depthSamples.size) {
                        depthSamples[dCount++] = depthMap[i]
                    }
                }
            }
        } else if (u2netMask != null) {
            val rx = (segW * 0.10f).toInt().coerceAtLeast(6)
            val ry = (segH * 0.10f).toInt().coerceAtLeast(6)
            for (y in (cy - ry).coerceAtLeast(0)..(cy + ry).coerceAtMost(segH - 1) step 2) {
                val row = y * segW
                for (x in (cx - rx).coerceAtLeast(0)..(cx + rx).coerceAtMost(segW - 1) step 2) {
                    val i = row + x
                    if (u2netMask[i] >= 0.42f && dCount < depthSamples.size) {
                        depthSamples[dCount++] = depthMap[i]
                    }
                }
            }
        }

        val focusDepth: Float
        val depthSpread: Float
        if (dCount >= 8) {
            java.util.Arrays.sort(depthSamples, 0, dCount)
            focusDepth = depthSamples[(dCount * 65) / 100]
            val p25 = depthSamples[(dCount * 25) / 100]
            val p85 = depthSamples[(dCount * 85) / 100]
            depthSpread = (p85 - p25).coerceIn(0.06f, 0.20f)
        } else {
            // Pure 3D surface focus: median depth in compact focus spot around (cx, cy)
            val spotR = (kotlin.math.min(segW, segH) * 0.04f).toInt().coerceIn(2, 12)
            var spotCnt = 0
            for (y in (cy - spotR).coerceAtLeast(0)..(cy + spotR).coerceAtMost(segH - 1)) {
                val row = y * segW
                for (x in (cx - spotR).coerceAtLeast(0)..(cx + spotR).coerceAtMost(segW - 1)) {
                    if (spotCnt < depthSamples.size) {
                        depthSamples[spotCnt++] = depthMap[row + x]
                    }
                }
            }
            if (spotCnt > 0) {
                java.util.Arrays.sort(depthSamples, 0, spotCnt)
                focusDepth = depthSamples[spotCnt / 2].coerceIn(0.0f, 1.0f)
            } else {
                focusDepth = depthMap[cy * segW + cx].coerceIn(0.0f, 1.0f)
            }
            depthSpread = 0.10f
        }

        val gate = FloatArray(n)
        val rearPass = focusDepth - 1.05f * depthSpread
        val rearStop = focusDepth - 1.85f * depthSpread
        val invRearBand = 1.0f / (rearPass - rearStop).coerceAtLeast(0.04f)
        for (i in 0 until n) {
            val d = depthMap[i]
            val g = if (d >= rearPass) {
                1.0f
            } else {
                ((d - rearStop) * invRearBand).coerceIn(0f, 1f)
            }
            gate[i] = g * g * (3.0f - 2.0f * g)
        }
        return Pair(focusDepth, gate)
    }

    private fun runNeuralPortraitSegmentation(
        srcBmp: Bitmap,
        segBmp: Bitmap,
        segW: Int,
        segH: Int,
        focusX: Float,
        focusY: Float
    ): NeuralSegResult {
        val n = segW * segH
        val selfieMask = FloatArray(n)
        var maxSelfieConf = 0f

        // Pass 1: Global Full-Frame ML Kit SelfieSegmenter on 512x682
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
                        val c = rawMask[y0 * mw + x0] * (1f - fx) * (1f - fy) +
                            rawMask[y0 * mw + x0 + 1] * fx * (1f - fy) +
                            rawMask[(y0 + 1) * mw + x0] * (1f - fx) * fy +
                            rawMask[(y0 + 1) * mw + x0 + 1] * fx * fy
                        val validC = if (c.isNaN()) 0f else c.coerceIn(0f, 1f)
                        selfieMask[y * segW + x] = validC
                        if (validC > maxSelfieConf) maxSelfieConf = validC
                    }
                }
            }
            android.util.Log.i("ZameraPortrait", "MLKit SelfieSegmenter Pass1 maxSelfieConf=$maxSelfieConf on ${segW}x${segH}")
        } catch (t: Throwable) {
            android.util.Log.e("ZameraPortrait", "MLKit SelfieSegmenter Pass1 error: ${t.message}", t)
        }

        // Locate human candidate bounding box (using 0.30 threshold so distant/lying humans in wide shots are also localized for Pass 2!)
        var minHx = segW
        var maxHx = 0
        var minHy = segH
        var maxHy = 0
        val locateThresh = if (maxSelfieConf >= 0.60f) 0.45f else 0.28f
        for (y in 0 until segH) {
            val row = y * segW
            for (x in 0 until segW) {
                if (selfieMask[row + x] >= locateThresh) {
                    if (x < minHx) minHx = x
                    if (x > maxHx) maxHx = x
                    if (y < minHy) minHy = y
                    if (y > maxHy) maxHy = y
                }
            }
        }
        if (maxSelfieConf < 0.28f || maxHx <= minHx || maxHy <= minHy) {
            return NeuralSegResult(selfieMask, 0f, false, 0f)
        }

        // Pass 2: High-Resolution Zoomed-In ROI Neural Pass around Head, Ears, Shoulders & Raised Hands/Fingers
        // Also boosts distant human portraits (like a person lying on a couch across the room) to full 384x384 neural resolution!
        var usedRoiPass = false
        try {
            val bodyW = (maxHx - minHx).coerceAtLeast(24)
            val bodyH = (maxHy - minHy).coerceAtLeast(24)
            val roiX0 = (minHx - (bodyW * 0.35f).toInt()).coerceIn(0, segW - 32)
            val roiX1 = (maxHx + (bodyW * 0.35f).toInt()).coerceIn(roiX0 + 32, segW - 1)
            val roiY0 = (minHy - (bodyH * 0.16f).toInt()).coerceIn(0, segH - 32)
            val roiY1 = (minHy + (bodyH * 0.88f).toInt()).coerceIn(roiY0 + 32, segH - 1)
            val roiW = roiX1 - roiX0 + 1
            val roiH = roiY1 - roiY0 + 1

            if (roiW * roiH < (n * 88) / 100) {
                val fullW = srcBmp.width
                val fullH = srcBmp.height
                val cropX = (roiX0 * fullW / segW).coerceIn(0, fullW - 32)
                val cropY = (roiY0 * fullH / segH).coerceIn(0, fullH - 32)
                val cropW = (roiW * fullW / segW).coerceIn(32, fullW - cropX)
                val cropH = (roiH * fullH / segH).coerceIn(32, fullH - cropY)
                val cropBmp = Bitmap.createBitmap(srcBmp, cropX, cropY, cropW, cropH)
                val roiScaled = Bitmap.createScaledBitmap(cropBmp, 384, 384, true)
                if (roiScaled !== cropBmp) cropBmp.recycle()

                val roiMask = Tasks.await(
                    getOrCreateSelfieSegmenter().process(InputImage.fromBitmap(roiScaled, 0)),
                    1800,
                    java.util.concurrent.TimeUnit.MILLISECONDS
                )
                roiScaled.recycle()
                if (roiMask != null) {
                    val mw = roiMask.width
                    val mh = roiMask.height
                    val buf = roiMask.buffer
                    buf.order(ByteOrder.nativeOrder())
                    buf.rewind()
                    val rawRoi = FloatArray(mw * mh)
                    buf.asFloatBuffer().get(rawRoi)
                    var maxRoiConf = 0f
                    var roiCoreCount = 0
                    for (v in rawRoi) {
                        if (!v.isNaN()) {
                            if (v > maxRoiConf) maxRoiConf = v
                            if (v >= 0.78f) roiCoreCount++
                        }
                    }
                    // Only merge Pass 2 if the zoomed ROI confirms a genuine high-confidence human core (rejects non-human objects like laptops!)
                    if (maxRoiConf >= 0.78f && roiCoreCount >= (mw * mh) / 45) {
                        val marginX = (roiW * 0.08f).coerceAtLeast(4f)
                        val marginY = (roiH * 0.08f).coerceAtLeast(4f)
                        for (y in roiY0..roiY1) {
                            val ly = (y - roiY0).toFloat() / (roiH - 1).coerceAtLeast(1)
                            val gy = ly * (mh - 1)
                            val y0 = gy.toInt().coerceIn(0, mh - 2)
                            val fy = gy - y0
                            val wy = kotlin.math.min((y - roiY0) / marginY, (roiY1 - y) / marginY).coerceIn(0f, 1f)
                            val rowOff = y * segW
                            for (x in roiX0..roiX1) {
                                val lx = (x - roiX0).toFloat() / (roiW - 1).coerceAtLeast(1)
                                val gx = lx * (mw - 1)
                                val x0 = gx.toInt().coerceIn(0, mw - 2)
                                val fx = gx - x0
                                val wx = kotlin.math.min((x - roiX0) / marginX, (roiX1 - x) / marginX).coerceIn(0f, 1f)
                                val wBlend = (wx * wy).coerceIn(0f, 1f)
                                val rc = (rawRoi[y0 * mw + x0] * (1f - fx) * (1f - fy) +
                                    rawRoi[y0 * mw + x0 + 1] * fx * (1f - fy) +
                                    rawRoi[(y0 + 1) * mw + x0] * (1f - fx) * fy +
                                    rawRoi[(y0 + 1) * mw + x0 + 1] * fx * fy).let { if (it.isNaN()) 0f else it.coerceIn(0f, 1f) }
                                val gc = selfieMask[rowOff + x]
                                val merged = if (rc > gc) {
                                    gc + (rc - gc) * wBlend
                                } else {
                                    gc * (1f - 0.80f * wBlend) + rc * (0.80f * wBlend)
                                }
                                val mv = merged.coerceIn(0f, 1f)
                                selfieMask[rowOff + x] = mv
                                if (mv > maxSelfieConf) maxSelfieConf = mv
                            }
                        }
                        usedRoiPass = true
                    }
                }
            }
        } catch (t: Throwable) {
            android.util.Log.w("ZameraPortrait", "MLKit ROI Pass2 warning: ${t.message}")
        }

        var selfieStrong = 0
        var selfieCore = 0
        for (i in 0 until n) {
            val sc = selfieMask[i]
            if (sc >= 0.50f) {
                selfieStrong++
                if (sc >= 0.74f) selfieCore++
            }
        }
        val selfieAreaRatio = selfieStrong.toFloat() / n.coerceAtLeast(1).toFloat()
        val selfieCoreRatio = selfieCore.toFloat() / selfieStrong.coerceAtLeast(1).toFloat()
        val hasValidSelfie = maxSelfieConf > 0.74f && selfieAreaRatio >= 0.008f && selfieCoreRatio >= 0.36f
        if (!hasValidSelfie) {
            return NeuralSegResult(selfieMask, 0f, false, 0f)
        }
        return NeuralSegResult(selfieMask, maxSelfieConf, usedRoiPass, selfieAreaRatio)
    }

    /**
     * Suppresses secondary background bystanders (e.g. a second person sitting on a couch behind the main portrait subject)
     * by identifying the primary tallest/focused head lobe and cutting along strong clothing/background edges separating
     * the primary foreground person from any smaller lower head lobe in the background.
     */
    private fun isolatePrimaryHumanSubject(
        mlMask: FloatArray,
        luma255: FloatArray,
        chA: FloatArray,
        chB: FloatArray,
        segW: Int,
        segH: Int,
        focusX: Float
    ) {
        var minHx = segW; var maxHx = 0; var minHy = segH; var maxHy = 0
        for (y in 0 until segH) {
            val row = y * segW
            for (x in 0 until segW) {
                if (mlMask[row + x] >= 0.52f) {
                    if (x < minHx) minHx = x
                    if (x > maxHx) maxHx = x
                    if (y < minHy) minHy = y
                    if (y > maxHy) maxHy = y
                }
            }
        }
        val bodyW = maxHx - minHx
        val bodyH = maxHy - minHy
        if (bodyW < segW / 3 || bodyH < segH / 3) return

        // Compute topmost human pixel y for each column x
        val colTopY = IntArray(segW) { segH }
        for (x in minHx..maxHx) {
            for (y in minHy..maxHy) {
                if (mlMask[y * segW + x] >= 0.58f) {
                    colTopY[x] = y
                    break
                }
            }
        }
        // Locate primary head column (highest head near center/focus)
        var primX = (minHx + maxHx) / 2
        var primTopY = segH
        val fxPx = (focusX * segW).toInt().coerceIn(minHx, maxHx)
        for (x in minHx..maxHx) {
            val score = colTopY[x] + (kotlin.math.abs(x - fxPx) * 0.15f).toInt()
            if (score < primTopY) {
                primTopY = score
                primX = x
            }
        }
        val actualPrimTop = colTopY[primX]

        // Check if there is a secondary background person lobe to the left separated by a neck/shoulder valley
        var leftValleyX = -1
        var maxValleyY = actualPrimTop
        var foundLeftSecHead = false
        for (x in (primX - 12) downTo (minHx + 16)) {
            val ty = colTopY[x]
            if (!foundLeftSecHead) {
                if (ty > maxValleyY) {
                    maxValleyY = ty
                    leftValleyX = x
                } else if (leftValleyX > 0 && maxValleyY - actualPrimTop >= (segH * 0.14f).toInt() && maxValleyY - ty >= 10) {
                    // Check that the secondary head lobe is wide enough (>= 34px) to be a person's head, not a raised finger!
                    var lobeWidth = 0
                    for (kx in x downTo minHx) {
                        if (colTopY[kx] < maxValleyY - 4) lobeWidth++ else break
                    }
                    if (lobeWidth >= 32 && ty - actualPrimTop >= (segH * 0.10f).toInt()) {
                        foundLeftSecHead = true
                    }
                }
            }
        }
        if (foundLeftSecHead && leftValleyX > minHx + segW / 9) {
            var cutX = leftValleyX
            for (y in actualPrimTop..maxHy) {
                val row = y * segW
                if (y >= maxValleyY - 6) {
                    var bestEdgeX = cutX
                    var bestEdgeScore = -1f
                    val searchL = (cutX - 8).coerceAtLeast(minHx + 4)
                    val searchR = (cutX + 8).coerceAtMost(primX - 10)
                    for (x in searchL..searchR) {
                        val i = row + x
                        val edge = kotlin.math.abs(luma255[i + 1] - luma255[i - 1]) +
                            1.3f * kotlin.math.abs(chA[i + 1] - chA[i - 1]) +
                            1.1f * kotlin.math.abs(chB[i + 1] - chB[i - 1]) -
                            0.9f * kotlin.math.abs(x - cutX)
                        if (edge > bestEdgeScore) {
                            bestEdgeScore = edge
                            bestEdgeX = x
                        }
                    }
                    cutX = bestEdgeX
                }
                for (x in 0 until cutX) {
                    val atten = ((x - (cutX - 6)).toFloat() / 6.0f).coerceIn(0f, 1f)
                    mlMask[row + x] *= atten
                }
            }
        }
    }

    /**
     * Checks whether a human mask contains a secondary background bystander head lobe separated by a neck/shoulder valley.
     * Used by Smart Selective Orchestration so `Depth-Anything-V2` is only invoked on human portraits when a background
     * bystander needs 3D depth rejection!
     */
    private fun hasSecondaryBystanderLobe(mask: FloatArray, segW: Int, segH: Int, focusX: Float): Boolean {
        var minHx = segW; var maxHx = 0; var minHy = segH; var maxHy = 0
        for (y in 0 until segH) {
            val row = y * segW
            for (x in 0 until segW) {
                if (mask[row + x] >= 0.52f) {
                    if (x < minHx) minHx = x
                    if (x > maxHx) maxHx = x
                    if (y < minHy) minHy = y
                    if (y > maxHy) maxHy = y
                }
            }
        }
        if (maxHx - minHx < segW / 3 || maxHy - minHy < segH / 3) return false
        val colTopY = IntArray(segW) { segH }
        for (x in minHx..maxHx) {
            for (y in minHy..maxHy) {
                if (mask[y * segW + x] >= 0.58f) {
                    colTopY[x] = y
                    break
                }
            }
        }
        var primX = (minHx + maxHx) / 2
        var primTopY = segH
        val fxPx = (focusX * segW).toInt().coerceIn(minHx, maxHx)
        for (x in minHx..maxHx) {
            val score = colTopY[x] + (kotlin.math.abs(x - fxPx) * 0.15f).toInt()
            if (score < primTopY) {
                primTopY = score
                primX = x
            }
        }
        val actualPrimTop = colTopY[primX]
        var leftValleyX = -1
        var maxValleyY = actualPrimTop
        for (x in (primX - 12) downTo (minHx + 16)) {
            val ty = colTopY[x]
            if (ty > maxValleyY) {
                maxValleyY = ty
                leftValleyX = x
            } else if (leftValleyX > 0 && maxValleyY - actualPrimTop >= (segH * 0.14f).toInt() && maxValleyY - ty >= 10) {
                var lobeWidth = 0
                for (kx in x downTo minHx) {
                    if (colTopY[kx] < maxValleyY - 4) lobeWidth++ else break
                }
                if (lobeWidth >= 32 && ty - actualPrimTop >= (segH * 0.10f).toInt()) {
                    return true
                }
            }
        }
        return false
    }

    private fun refineNeuralSubjectMask(
        mlMask: FloatArray,
        multiclass: MulticlassSegResult?,
        depthGate: FloatArray,
        pixels: IntArray,
        luma255: FloatArray,
        chA: FloatArray,
        chB: FloatArray,
        segW: Int,
        segH: Int,
        focusX: Float
    ): FloatArray {
        val n = segW * segH
        val combinedHuman = FloatArray(n)
        val humanBodySeed = FloatArray(n)
        val sureSkinSeed = FloatArray(n)
        val sureSkinL = FloatArray(n)
        val sureSkinA = FloatArray(n)
        val sureSkinB = FloatArray(n)

        for (i in 0 until n) {
            val s = mlMask[i]
            val mcH = multiclass?.humanProb?.get(i) ?: s
            val sk = multiclass?.skinProb?.get(i) ?: 0f
            val cl = multiclass?.clothesProb?.get(i) ?: 0f
            val hr = multiclass?.hairProb?.get(i) ?: 0f
            // Prioritize 6-Class MediaPipe Selfie Multiclass (`16.4 MB`) while preserving high-confidence SelfieSegmenter core
            val hProb = if (multiclass != null) {
                kotlin.math.max(mcH, (0.68f * mcH + 0.32f * s))
            } else {
                s
            }
            combinedHuman[i] = hProb
            if (sk + cl + hr >= 0.42f || hProb >= 0.65f) {
                humanBodySeed[i] = 1.0f
            }
            val p = pixels[i]
            val r = ((p shr 16) and 0xFF).toFloat()
            val g = ((p shr 8) and 0xFF).toFloat()
            val b = (p and 0xFF).toFloat()
            val isSkinChrom = r > g + 4f && g > 0.50f * r && g > b - 10f &&
                chA[i] > 5.5f && chB[i] > 3.5f && luma255[i] in 40f..246f
            val wSk = if (isSkinChrom) {
                val sp = if (multiclass != null) kotlin.math.max(sk, s * 0.65f) else s
                ((sp - 0.35f) / 0.45f).coerceIn(0f, 1f)
            } else 0f
            sureSkinSeed[i] = wSk
            sureSkinL[i] = luma255[i] * wSk
            sureSkinA[i] = chA[i] * wSk
            sureSkinB[i] = chB[i] * wSk
        }

        isolatePrimaryHumanSubject(combinedHuman, luma255, chA, chB, segW, segH, focusX)

        // Proximity gate for Class 5 (Held Accessories: Phone held in hand, Eyeglasses) so independent floor objects are rejected
        val nearHumanBody = boxFilterFloat(humanBodySeed, segW, segH, (segW / 18).coerceIn(18, 30))
        // Local hand/face skin color model for razor-sharp spread fingers and inter-finger V-webbing suppression
        val skinRad = (segW / 34).coerceIn(10, 16)
        val locSkinW = boxFilterFloat(sureSkinSeed, segW, segH, skinRad)
        val locSkinL = boxFilterFloat(sureSkinL, segW, segH, skinRad)
        val locSkinA = boxFilterFloat(sureSkinA, segW, segH, skinRad)
        val locSkinB = boxFilterFloat(sureSkinB, segW, segH, skinRad)

        val rawAlpha = FloatArray(n)
        var minHx = segW
        var maxHx = 0
        var minHy = segH
        var maxHy = 0
        for (y in 0 until segH) {
            val row = y * segW
            for (x in 0 until segW) {
                val idx = row + x
                if (combinedHuman[idx] * depthGate[idx] >= 0.42f) {
                    if (x < minHx) minHx = x
                    if (x > maxHx) maxHx = x
                    if (y < minHy) minHy = y
                    if (y > maxHy) maxHy = y
                }
            }
        }
        val bodyW = (maxHx - minHx).coerceAtLeast(16)
        val bodyH = (maxHy - minHy).coerceAtLeast(16)
        val anatLeft = (minHx - (bodyW * 0.36f).toInt()).coerceAtLeast(0)
        val anatRight = (maxHx + (bodyW * 0.36f).toInt()).coerceAtMost(segW - 1)
        val anatTop = (minHy - (bodyH * 0.12f).toInt()).coerceAtLeast(0)
        val anatBottom = (maxHy + (bodyH * 0.34f).toInt()).coerceAtMost(segH - 1)

        // Compute local sure-FG and sure-BG color statistics strictly for non-skin/non-clothes concave pocket cleanup
        val wFgSeed = FloatArray(n)
        val wBgSeed = FloatArray(n)
        val fgSeedL = FloatArray(n)
        val fgSeedA = FloatArray(n)
        val fgSeedB = FloatArray(n)
        val bgSeedL = FloatArray(n)
        val bgSeedA = FloatArray(n)
        val bgSeedB = FloatArray(n)
        for (i in 0 until n) {
            val m = combinedHuman[i] * depthGate[i]
            val wf = ((m - 0.76f) / 0.24f).coerceIn(0f, 1f).let { it * it }
            val wb = ((0.22f - m) / 0.22f).coerceIn(0f, 1f).let { it * it }
            wFgSeed[i] = wf
            wBgSeed[i] = wb
            fgSeedL[i] = luma255[i] * wf
            fgSeedA[i] = chA[i] * wf
            fgSeedB[i] = chB[i] * wf
            bgSeedL[i] = luma255[i] * wb
            bgSeedA[i] = chA[i] * wb
            bgSeedB[i] = chB[i] * wb
        }
        val rad = (segW / 24).coerceIn(10, 22)
        val locFgW = boxFilterFloat(wFgSeed, segW, segH, rad)
        val locFgL = boxFilterFloat(fgSeedL, segW, segH, rad)
        val locFgA = boxFilterFloat(fgSeedA, segW, segH, rad)
        val locFgB = boxFilterFloat(fgSeedB, segW, segH, rad)
        val locBgW = boxFilterFloat(wBgSeed, segW, segH, rad)
        val locBgL = boxFilterFloat(bgSeedL, segW, segH, rad)
        val locBgA = boxFilterFloat(bgSeedA, segW, segH, rad)
        val locBgB = boxFilterFloat(bgSeedB, segW, segH, rad)
        val bgPresence = boxFilterFloat(wBgSeed, segW, segH, (segW / 54).coerceIn(5, 10))

        for (y in 0 until segH) {
            val row = y * segW
            for (x in 0 until segW) {
                val i = row + x
                val dg = depthGate[i]
                val hProb = combinedHuman[i]
                val skinP = multiclass?.skinProb?.get(i) ?: 0f
                val hairP = multiclass?.hairProb?.get(i) ?: 0f
                val clothesP = multiclass?.clothesProb?.get(i) ?: 0f
                val rawAccessP = multiclass?.accessProb?.get(i) ?: 0f
                // Keep Class 5 (held phone / eyeglasses) sharp when attached to hands/face/clothes
                val validAccessP = rawAccessP * ((nearHumanBody[i] / 0.10f).coerceIn(0f, 1f))

                val p = pixels[i]
                val r = ((p shr 16) and 0xFF).toFloat()
                val g = ((p shr 8) and 0xFF).toFloat()
                val b = (p and 0xFF).toFloat()
                val inAnat = x in anatLeft..anatRight && y in anatTop..anatBottom
                // Require g > 0.50f * r and neural skin support so dark red/amber tea glasses on the floor are never mistaken for skin!
                val isSkinChrom = inAnat && dg >= 0.50f && r > g + 4f && g > 0.50f * r && g > b - 10f &&
                    chA[i] > 5.5f && chB[i] > 3.8f && luma255[i] in 40f..246f
                val isSkinLike = isSkinChrom && (skinP >= 0.05f || (multiclass == null && hProb >= 0.14f))

                val m = (kotlin.math.max(hProb, validAccessP) * dg).coerceIn(0f, 1f)

                var subjAlpha = when {
                    clothesP >= 0.34f || validAccessP >= 0.36f -> {
                        // Lock sweater sleeves, vest, eyeglasses, and held phone at full sharpness
                        ((kotlin.math.max(m, kotlin.math.max(clothesP, validAccessP)) - 0.24f) / 0.28f).coerceIn(0f, 1f)
                    }
                    isSkinLike -> {
                        ((kotlin.math.max(m, skinP) - 0.12f) / 0.28f).coerceIn(0f, 1f)
                    }
                    else -> {
                        ((m - 0.44f) / 0.30f).coerceIn(0f, 1f)
                    }
                }

                // Hand/Finger & Inter-Finger V-Gap Precision Filter:
                // Near skin regions (hands/fingers), boost true skin-colored finger pixels and crush non-skin V-gap webbing!
                val skW = locSkinW[i]
                if (skW > 0.025f && clothesP < 0.32f && hairP < 0.32f && validAccessP < 0.32f) {
                    val sl = locSkinL[i] / skW
                    val sa = locSkinA[i] / skW
                    val sb = locSkinB[i] / skW
                    val dLocalSkin = 0.45f * kotlin.math.abs(luma255[i] - sl) +
                        1.55f * kotlin.math.abs(chA[i] - sa) +
                        1.35f * kotlin.math.abs(chB[i] - sb)
                    if (isSkinChrom && dLocalSkin < 14.5f && (skinP >= 0.06f || hProb >= 0.15f)) {
                        // True finger/thumb pixel: lock fingertip and finger edges sharp!
                        val fingerBoost = ((15.5f - dLocalSkin) / 8.0f).coerceIn(0f, 1f)
                        subjAlpha = kotlin.math.max(subjAlpha, (0.82f + 0.18f * fingerBoost) * dg)
                    } else if ((!isSkinChrom || dLocalSkin > 16.5f) && skinP < 0.72f) {
                        // Background wall/curtain visible inside the V-gap between spread fingers: suppress webbing!
                        val webAtten = if (!isSkinChrom) {
                            0.04f
                        } else {
                            ((16.5f / dLocalSkin.coerceAtLeast(16.5f)).let { it * it } * 0.15f).coerceIn(0.02f, 0.25f)
                        }
                        subjAlpha *= webAtten
                    }
                }

                // Clean non-skin, non-clothes background leaks in concave pockets (e.g. wall/pillow next to ear/neck)
                val fw = locFgW[i]
                val bw = locBgW[i]
                if (!isSkinLike && clothesP < 0.38f && hairP < 0.45f && validAccessP < 0.35f &&
                    subjAlpha > 0.02f && m < 0.76f && bgPresence[i] > 0.025f && fw > 1e-3f && bw > 1e-3f
                ) {
                    val fl = locFgL[i] / fw
                    val fa = locFgA[i] / fw
                    val fb = locFgB[i] / fw
                    val bl = locBgL[i] / bw
                    val ba = locBgA[i] / bw
                    val bb = locBgB[i] / bw

                    val dFg = 0.55f * kotlin.math.abs(luma255[i] - fl) +
                        1.35f * kotlin.math.abs(chA[i] - fa) +
                        1.15f * kotlin.math.abs(chB[i] - fb)
                    val dBg = 0.55f * kotlin.math.abs(luma255[i] - bl) +
                        1.35f * kotlin.math.abs(chA[i] - ba) +
                        1.15f * kotlin.math.abs(chB[i] - bb)

                    if (dBg < 15.5f && dFg > 1.85f * dBg + 12.0f) {
                        val pocketAtten = (dBg / 15.5f).coerceIn(0.02f, 1.0f)
                        subjAlpha *= pocketAtten
                    }
                }
                rawAlpha[i] = (subjAlpha * dg).coerceIn(0f, 1f)
            }
        }

        // Connected Skin-Extremity Geodesic Recovery (Recovers spread fingertips & thumbs strictly on neural skin candidates!)
        val skinProtoL = FloatArray(n)
        val skinProtoA = FloatArray(n)
        val skinProtoB = FloatArray(n)
        for (i in 0 until n) {
            skinProtoL[i] = luma255[i]
            skinProtoA[i] = chA[i]
            skinProtoB[i] = chB[i]
        }
        repeat(6) {
            for (y in (anatTop + 1) until anatBottom) {
                val row = y * segW
                for (x in (anatLeft + 1) until anatRight) {
                    val i = row + x
                    if (rawAlpha[i] >= 0.92f || depthGate[i] < 0.58f) continue
                    val skinP = multiclass?.skinProb?.get(i) ?: combinedHuman[i]
                    if (skinP < 0.04f) continue
                    val p = pixels[i]
                    val r = ((p shr 16) and 0xFF).toFloat()
                    val g = ((p shr 8) and 0xFF).toFloat()
                    if (r <= g + 5f || g <= 0.52f * r || chA[i] <= 6.5f || chB[i] <= 4.5f || luma255[i] !in 45f..244f) continue
                    val bw = locBgW[i]
                    val dBg = if (bw > 1e-3f) {
                        0.55f * kotlin.math.abs(luma255[i] - locBgL[i] / bw) +
                            1.35f * kotlin.math.abs(chA[i] - locBgA[i] / bw) +
                            1.15f * kotlin.math.abs(chB[i] - locBgB[i] / bw)
                    } else 30f
                    if (dBg < 14.0f) continue

                    val neighbors = intArrayOf(i - 1, i + 1, i - segW, i + segW)
                    for (nb in neighbors) {
                        if (rawAlpha[nb] >= 0.72f) {
                            val dSkin = 0.50f * kotlin.math.abs(luma255[i] - skinProtoL[nb]) +
                                1.45f * kotlin.math.abs(chA[i] - skinProtoA[nb]) +
                                1.25f * kotlin.math.abs(chB[i] - skinProtoB[nb])
                            val edgeJump = kotlin.math.abs(luma255[i] - luma255[nb]) +
                                1.4f * kotlin.math.abs(chA[i] - chA[nb])
                            if (dSkin < 13.0f && edgeJump < 19.0f && dBg > 1.75f * dSkin + 9.0f) {
                                val cand = (rawAlpha[nb] * 0.96f * depthGate[i]).coerceIn(0f, 1f)
                                if (cand > rawAlpha[i]) {
                                    rawAlpha[i] = cand
                                    skinProtoL[i] = 0.7f * skinProtoL[nb] + 0.3f * luma255[i]
                                    skinProtoA[i] = 0.7f * skinProtoA[nb] + 0.3f * chA[i]
                                    skinProtoB[i] = 0.7f * skinProtoB[nb] + 0.3f * chB[i]
                                }
                            }
                        }
                    }
                }
            }
        }
        return rawAlpha
    }

    private data class PortraitRenderOutcome(
        val wroteOutput: Boolean,
        val depthActive: Boolean,
        val focusDepth: Float
    )

    private fun computeGuidedAlphaCoefficients(
        srcBmp: Bitmap,
        segW: Int,
        segH: Int,
        focusX: Float,
        focusY: Float,
        subjectRadiusRatio: Float,
        cacheSourceFile: File? = null,
        isFrontCamera: Boolean = false
    ): PortraitMatteResult {
        val segBmp = Bitmap.createScaledBitmap(srcBmp, segW, segH, true)
        val n = segW * segH

        val pixels = IntArray(n)
        segBmp.getPixels(pixels, 0, segW, 0, 0, segW, segH)

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

        val cachedEntry = if (cacheSourceFile != null && cacheSourceFile.exists()) {
            portraitSessionCache.get(
                sourceJpegPath = cacheSourceFile.absolutePath,
                lastModified = cacheSourceFile.lastModified(),
                fileLength = cacheSourceFile.length(),
                isFrontCamera = isFrontCamera
            )?.takeIf { it.segW == segW && it.segH == segH }
        } else {
            null
        }

        val neuralRes: NeuralSegResult
        val multiclassRes: MulticlassSegResult?
        val depthMap: FloatArray?
        val u2netMask: FloatArray?
        var globalU2Net320: FloatArray?

        if (cachedEntry != null) {
            segBmp.recycle()
            neuralRes = NeuralSegResult(
                mask = cachedEntry.mlSelfieMask ?: FloatArray(n),
                maxConf = cachedEntry.mlMaxConf,
                usedSubjectSeg = false,
                areaRatio = cachedEntry.mlAreaRatio
            )
            multiclassRes = if (
                cachedEntry.humanProb != null &&
                cachedEntry.skinProb != null &&
                cachedEntry.hairProb != null &&
                cachedEntry.clothesProb != null &&
                cachedEntry.accessProb != null
            ) {
                MulticlassSegResult(
                    humanProb = cachedEntry.humanProb,
                    skinProb = cachedEntry.skinProb,
                    hairProb = cachedEntry.hairProb,
                    clothesProb = cachedEntry.clothesProb,
                    accessProb = cachedEntry.accessProb,
                    maxHumanConf = cachedEntry.maxHumanConf,
                    humanAreaRatio = cachedEntry.humanAreaRatio
                )
            } else {
                null
            }
            depthMap = cachedEntry.depthMap
            globalU2Net320 = cachedEntry.globalU2Net320

            val hasStrongMc = multiclassRes != null && multiclassRes.maxHumanConf >= 0.68f && multiclassRes.humanAreaRatio >= 0.008f
            val hasStrongHu = hasStrongMc || (neuralRes.maxConf > 0.72f && neuralRes.areaRatio >= 0.008f)
            if (!hasStrongHu) {
                val u2Res = runU2NetSalientMatting(
                    srcBmp = srcBmp,
                    segW = segW,
                    segH = segH,
                    focusX = focusX,
                    focusY = focusY,
                    cachedGlobal320 = globalU2Net320
                )
                if (u2Res != null) {
                    globalU2Net320 = u2Res.first
                    u2netMask = u2Res.second
                    if (cachedEntry.globalU2Net320 == null && cacheSourceFile != null) {
                        portraitSessionCache.put(cachedEntry.copy(globalU2Net320 = globalU2Net320))
                    }
                } else {
                    u2netMask = null
                }
            } else {
                u2netMask = null
            }
        } else {
            // Parallel Orchestration on ispWorkerPool:
            // DepthAnythingV2 runs concurrently for BOTH human AND object portraits alongside SelfieMulticlass + MLKit!
            val depthFuture = ispWorkerPool.submit<FloatArray?> {
                runDepthAnything3dMap(srcBmp, segW, segH)
            }
            val multiclassFuture = ispWorkerPool.submit<MulticlassSegResult?> {
                runMulticlassSegmentation(srcBmp, segW, segH)
            }
            neuralRes = try {
                runNeuralPortraitSegmentation(srcBmp, segBmp, segW, segH, focusX, focusY)
            } finally {
                segBmp.recycle()
            }
            multiclassRes = try {
                multiclassFuture.get(3500, java.util.concurrent.TimeUnit.MILLISECONDS)
            } catch (t: Throwable) {
                android.util.Log.w("ZameraPortrait", "Multiclass future warning: ${t.message}")
                null
            }

            val hasStrongMc = multiclassRes != null && multiclassRes.maxHumanConf >= 0.68f && multiclassRes.humanAreaRatio >= 0.008f
            val hasStrongHu = hasStrongMc || (neuralRes.maxConf > 0.72f && neuralRes.areaRatio >= 0.008f)

            if (!hasStrongHu) {
                val u2Res = runU2NetSalientMatting(srcBmp, segW, segH, focusX, focusY)
                globalU2Net320 = u2Res?.first
                u2netMask = u2Res?.second
            } else {
                globalU2Net320 = null
                u2netMask = null
            }

            depthMap = try {
                depthFuture.get(4500, java.util.concurrent.TimeUnit.MILLISECONDS)
            } catch (t: Throwable) {
                android.util.Log.w("ZameraPortrait", "DepthAnythingV2 future warning: ${t.message}")
                null
            }

            if (cacheSourceFile != null && cacheSourceFile.exists()) {
                portraitSessionCache.put(
                    PortraitSessionCache.Entry(
                        sourceJpegPath = cacheSourceFile.absolutePath,
                        lastModified = cacheSourceFile.lastModified(),
                        fileLength = cacheSourceFile.length(),
                        isFrontCamera = isFrontCamera,
                        segW = segW,
                        segH = segH,
                        depthMap = depthMap,
                        mlSelfieMask = neuralRes.mask,
                        mlMaxConf = neuralRes.maxConf,
                        mlAreaRatio = neuralRes.areaRatio,
                        humanProb = multiclassRes?.humanProb,
                        skinProb = multiclassRes?.skinProb,
                        hairProb = multiclassRes?.hairProb,
                        clothesProb = multiclassRes?.clothesProb,
                        accessProb = multiclassRes?.accessProb,
                        maxHumanConf = multiclassRes?.maxHumanConf ?: 0f,
                        humanAreaRatio = multiclassRes?.humanAreaRatio ?: 0f,
                        globalU2Net320 = globalU2Net320
                    )
                )
            }
        }

        val hasStrongMulticlass = multiclassRes != null && multiclassRes.maxHumanConf >= 0.68f && multiclassRes.humanAreaRatio >= 0.008f
        val hasStrongNeural = hasStrongMulticlass || (neuralRes.maxConf > 0.72f && neuralRes.areaRatio >= 0.008f)
        val primaryMaskForCheck = multiclassRes?.humanProb ?: neuralRes.mask

        val (focusDepth, depthGate) = computeSubjectDepthGate(
            depthMap = depthMap,
            mlMask = primaryMaskForCheck,
            u2netMask = u2netMask,
            segW = segW,
            segH = segH,
            focusX = focusX,
            focusY = focusY,
            hasStrongHuman = hasStrongNeural
        )

        val rawAlpha = if (hasStrongNeural) {
            refineNeuralSubjectMask(
                mlMask = neuralRes.mask,
                multiclass = multiclassRes,
                depthGate = depthGate,
                pixels = pixels,
                luma255 = luma255,
                chA = chA,
                chB = chB,
                segW = segW,
                segH = segH,
                focusX = focusX
            )
        } else {
            PortraitOpticalEngine.extractFocusedObjectMatte(
                u2netProb = u2netMask,
                depthMap = depthMap,
                focusDepth = focusDepth,
                luma255 = luma255,
                chA = chA,
                chB = chB,
                segW = segW,
                segH = segH,
                focusX = focusX,
                focusY = focusY
            )
        }

        // Sub-Finger Edge-Preserving Joint Guided Filter at 512x682 resolution:
        // gfRadius = 2 (5x5 window — narrower than a single 5px finger!) with eps = 0.0035f and slope 'ai' in [-0.68..0.68]
        val gfRadius = 2
        val eps = 0.0035f
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
            val mp = meanP[i]
            if (mp <= 0.02f || mp >= 0.98f) {
                a[i] = 0f
                b[i] = if (mp >= 0.98f) 1.0f else 0.0f
            } else {
                val varI = (corrI[i] - meanI[i] * meanI[i]).coerceAtLeast(0f)
                val covIp = corrIp[i] - meanI[i] * mp
                val ai = (covIp / (varI + eps)).coerceIn(-0.68f, 0.68f)
                a[i] = ai
                b[i] = mp - ai * meanI[i]
            }
        }
        val meanA = boxFilterFloat(a, segW, segH, gfRadius)
        val meanB = boxFilterFloat(b, segW, segH, gfRadius)
        val effArea = multiclassRes?.humanAreaRatio?.takeIf { it >= 0.01f } ?: neuralRes.areaRatio
        return PortraitMatteResult(
            meanA = meanA,
            meanB = meanB,
            humanAreaRatio = if (hasStrongNeural) effArea.coerceAtLeast(0.16f) else 0.24f,
            depthMap = depthMap,
            focusDepth = focusDepth
        )
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
    ): PortraitRenderOutcome {
        return try {
            val exif = ExifInterface(sourceJpeg.absolutePath)
            val orientAttr = exif.getAttributeInt(
                ExifInterface.TAG_ORIENTATION,
                ExifInterface.ORIENTATION_NORMAL
            )
            // Decode at full 12.6MP resolution (4096x3072 -> inSampleSize = 1); only subsample 50MP+ (>= 4200px)
            val boundsOpts = android.graphics.BitmapFactory.Options().apply {
                inJustDecodeBounds = true
            }
            android.graphics.BitmapFactory.decodeFile(sourceJpeg.absolutePath, boundsOpts)
            val decodeOpts = android.graphics.BitmapFactory.Options().apply {
                inSampleSize = if (kotlin.math.max(boundsOpts.outWidth, boundsOpts.outHeight) > 4200) 2 else 1
                inPreferredConfig = Bitmap.Config.ARGB_8888
            }
            var srcBmp = android.graphics.BitmapFactory.decodeFile(sourceJpeg.absolutePath, decodeOpts)
                ?: return PortraitRenderOutcome(wroteOutput = false, depthActive = false, focusDepth = 0.70f)

            val rotDeg = when (orientAttr) {
                ExifInterface.ORIENTATION_ROTATE_90 -> 90f
                ExifInterface.ORIENTATION_ROTATE_180 -> 180f
                ExifInterface.ORIENTATION_ROTATE_270 -> 270f
                else -> 0f
            }
            if (rotDeg != 0f || isFrontCamera) {
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
            val segW = 512
            val segH = (512 * h / w.coerceAtLeast(1)).coerceIn(360, 768)

            // 1. Compute Joint Guided Filter Alpha Matting Coefficients + 3D Depth Map (backed by LRU=1 PortraitSessionCache)
            val (meanA, meanB, _, depthMap, focusDepth) = computeGuidedAlphaCoefficients(
                srcBmp = srcBmp,
                segW = segW,
                segH = segH,
                focusX = focusX,
                focusY = focusY,
                subjectRadiusRatio = subjectRadiusRatio,
                cacheSourceFile = sourceJpeg,
                isFrontCamera = isFrontCamera
            )

            val totalPx = w * h
            val srcPixels = IntArray(totalPx)
            srcBmp.getPixels(srcPixels, 0, w, 0, 0, w, h)
            srcBmp.recycle()

            // 2. Post-Capture 3D Rack-Focus: if user taps background in editor, shift optical focal plane to tapped 3D depth
            var tappedBackgroundPlane = false
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
                tappedBackgroundPlane = tapAlpha < 0.30f
            }

            val effectiveFocusDepth: Float
            val cocMap: FloatArray
            val activeMeanA: FloatArray?
            val activeMeanB: FloatArray?
            val activeFgAlpha: FloatArray?

            if (depthMap != null) {
                if (tappedBackgroundPlane) {
                    val tapGx = (focusX * (segW - 1)).toInt().coerceIn(0, segW - 1)
                    val tapGy = (focusY * (segH - 1)).toInt().coerceIn(0, segH - 1)
                    effectiveFocusDepth = depthMap[tapGy * segW + tapGx].coerceIn(0f, 1f)
                    cocMap = PortraitOpticalEngine.computeCoCMap(
                        depthMap = depthMap,
                        focusDepth = effectiveFocusDepth,
                        aperture = aperture,
                        fgAlpha = null,
                        width = segW,
                        height = segH
                    )
                    activeMeanA = null
                    activeMeanB = null
                    activeFgAlpha = null
                } else {
                    effectiveFocusDepth = focusDepth
                    // Unmasked 3D CoC map; full-resolution Guided Filter (meanA, meanB) applies (1 - fgAlpha) at 12.6MP precision
                    cocMap = PortraitOpticalEngine.computeCoCMap(
                        depthMap = depthMap,
                        focusDepth = effectiveFocusDepth,
                        aperture = aperture,
                        fgAlpha = null,
                        width = segW,
                        height = segH
                    )
                    activeMeanA = meanA
                    activeMeanB = meanB
                    activeFgAlpha = null
                }
            } else {
                effectiveFocusDepth = focusDepth
                val segFg = FloatArray(segW * segH)
                for (gy in 0 until segH) {
                    val sy = (gy * (h - 1) / (segH - 1).coerceAtLeast(1)).coerceIn(0, h - 1)
                    val sRow = sy * w
                    val gRow = gy * segW
                    for (gx in 0 until segW) {
                        val sx = (gx * (w - 1) / (segW - 1).coerceAtLeast(1)).coerceIn(0, w - 1)
                        val sp = srcPixels[sRow + sx]
                        val lum = (0.299f * ((sp shr 16) and 0xFF) +
                            0.587f * ((sp shr 8) and 0xFF) +
                            0.114f * (sp and 0xFF)) / 255.0f
                        val idx = gRow + gx
                        val cleanFg = PortraitOpticalEngine.smoothstep(
                            0.24f,
                            0.78f,
                            (meanA[idx] * lum + meanB[idx]).coerceIn(0f, 1f)
                        )
                        segFg[idx] = if (tappedBackgroundPlane) (1.0f - cleanFg) else cleanFg
                    }
                }
                cocMap = PortraitOpticalEngine.computeCoCMap(
                    depthMap = null,
                    focusDepth = effectiveFocusDepth,
                    aperture = aperture,
                    fgAlpha = segFg,
                    width = segW,
                    height = segH
                )
                activeMeanA = null
                activeMeanB = null
                activeFgAlpha = segFg
            }

            // 3. Render Linear-sRGB Circular-Disc Bokeh (L0 -> B1 -> B2 -> B3) + OCP PortraitLightingRegistry
            val renderedPixels = PortraitOpticalEngine.renderLinearDiscBokeh(
                srcPixels = srcPixels,
                width = w,
                height = h,
                cocMap = cocMap,
                fgAlphaMap = activeFgAlpha,
                mapW = segW,
                mapH = segH,
                aperture = aperture,
                lightingMode = lightingMode,
                lightIntensity = lightIntensity,
                focusX = focusX,
                focusY = focusY,
                meanA = activeMeanA,
                meanB = activeMeanB,
                invertFocusPlane = false,
                rowExecutor = this::parallelForRows
            )

            val outBmp = Bitmap.createBitmap(renderedPixels, w, h, Bitmap.Config.ARGB_8888)
            FileOutputStream(outJpeg).use { fos ->
                outBmp.compress(Bitmap.CompressFormat.JPEG, 95, fos)
            }
            outBmp.recycle()
            PortraitRenderOutcome(
                wroteOutput = outJpeg.exists(),
                depthActive = (depthMap != null),
                focusDepth = effectiveFocusDepth
            )
        } catch (t: Throwable) {
            android.util.Log.e("ZameraPortrait", "Portrait pipeline error: ${t.message}", t)
            PortraitRenderOutcome(wroteOutput = false, depthActive = false, focusDepth = 0.70f)
        }
    }

    /**
     * Post-capture interactive Portrait Re-Focus, Aperture (f/1.4..f/16), Portrait On/Off toggle, and Studio Lighting reprocessing.
     */
    private fun reprocessPortraitPhoto(args: Map<String, Any?>, result: Result) {
        val sourcePath = args["sourceJpegPath"]?.toString()
        val sourceFile = if (!sourcePath.isNullOrEmpty()) File(sourcePath) else null
        if (sourceFile == null || !sourceFile.exists()) {
            result.error("NO_SOURCE", "Source JPEG not found for portrait reprocessing", null)
            return
        }
        val portraitEnabled = (args["portraitEnabled"] as? Boolean) ?: true
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
                if (!portraitEnabled) {
                    val cachedDepthActive = portraitSessionCache.get(
                        sourceJpegPath = sourceFile.absolutePath,
                        lastModified = sourceFile.lastModified(),
                        fileLength = sourceFile.length(),
                        isFrontCamera = isFrontCamera
                    )?.depthMap != null

                    var mediaUri: String? = null
                    if (saveToGallery) {
                        mediaUri = saveFileToMediaStoreDcim(
                            sourceFile = sourceFile,
                            displayName = "ZAM_${ts}_PORTRAIT_ORIG.jpg",
                            mimeType = "image/jpeg"
                        )
                    }
                    mainHandler.post {
                        result.success(
                            mapOf(
                                "jpegPath" to sourceFile.absolutePath,
                                "reprocessedJpegPath" to sourceFile.absolutePath,
                                "mediaStoreUri" to mediaUri,
                                "portraitEnabled" to false,
                                "portraitDepthActive" to cachedDepthActive
                            )
                        )
                    }
                    return@execute
                }

                val outFile = File(appContext.cacheDir, "ZAM_REFOCUS_${ts}.jpg")
                val outcome = applyPortraitBokehAndLighting(
                    sourceJpeg = sourceFile,
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
                val finalFile = if (outFile.exists()) outFile else sourceFile
                var mediaUri: String? = null
                if (saveToGallery && finalFile.exists()) {
                    mediaUri = saveFileToMediaStoreDcim(
                        sourceFile = finalFile,
                        displayName = "ZAM_${ts}_PORTRAIT_EDIT.jpg",
                        mimeType = "image/jpeg"
                    )
                }
                mainHandler.post {
                    result.success(
                        mapOf(
                            "jpegPath" to finalFile.absolutePath,
                            "reprocessedJpegPath" to finalFile.absolutePath,
                            "mediaStoreUri" to mediaUri,
                            "portraitEnabled" to true,
                            "portraitDepthActive" to outcome.depthActive
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
        videoAeAfLocked = false
        photoAeAfLocked = false
        photoManualIso = false
        photoManualShutter = false
        fallbackSmoothedAudioPower = 0.0
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
                    configureVideoPreviewOrRecordSession(
                        cam,
                        chars,
                        null,
                        { startAudioFloatMeterMonitor(videoPreferredAudioDeviceId) },
                        {}
                    )
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
            if (rec.recordingState != android.media.AudioRecord.RECORDSTATE_RECORDING) {
                rec.release()
                return
            }
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
                try {
                    while (audioMeterActive) {
                        val readCount = rec.read(chunkBuf, 0, chunkLen, android.media.AudioRecord.READ_BLOCKING)
                        if (readCount > 0) {
                            val peakPair = ZameraRustBridge.computeAudioPeakAndRmsDbfs(chunkBuf, readCount)
                            System.arraycopy(chunkBuf, 0, rmsRing, ringWriteChunk * chunkLen, readCount.coerceAtMost(chunkLen))
                            ringWriteChunk = (ringWriteChunk + 1) % ringChunks
                            if (filledChunks < ringChunks) filledChunks++
                            val rmsPair = ZameraRustBridge.computeAudioPeakAndRmsDbfs(rmsRing, filledChunks * chunkLen)
                            videoSamplePeakDbfs = peakPair.first.toDouble()
                            videoRmsDbfs = rmsPair.second.toDouble()
                        } else if (readCount < 0) {
                            break
                        }
                    }
                } catch (e: Throwable) {
                    android.util.Log.w("ZameraCapture", "AudioRecord float read warning: ${e.message}")
                } finally {
                    if (audioRecordMonitor === rec) {
                        audioMeterActive = false
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
            videoAeAfLocked = false
            videoPreferredAudioDeviceId = args["audioDeviceId"]?.toString()
            fallbackSmoothedAudioPower = 0.0
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
                            startAudioFloatMeterMonitor(videoPreferredAudioDeviceId)
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

        builder.set(CaptureRequest.CONTROL_AE_LOCK, videoAeAfLocked)
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
            if (args.containsKey("aeAfLocked")) {
                videoAeAfLocked = args["aeAfLocked"] as? Boolean ?: false
            }
            videoEvCompensation = ((args["evCompensation"] as? Number)?.toDouble() ?: 0.0).coerceIn(-3.0, 3.0)
            videoProfileName = args["profile"]?.toString() ?: videoProfileName

            val reqAudioId = args["audioDeviceId"]?.toString()
            if (reqAudioId != null && reqAudioId != videoPreferredAudioDeviceId) {
                videoPreferredAudioDeviceId = reqAudioId
                if (!isVideoRecording && videoSessionActive) {
                    startAudioFloatMeterMonitor(videoPreferredAudioDeviceId)
                }
            }

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
            } else if (videoAeAfLocked && minFocus > 0.0f) {
                activeFocusPullRunnable?.let { backgroundHandler?.removeCallbacks(it) }
                activeFocusPullRunnable = null
                if (builder.get(CaptureRequest.CONTROL_AF_MODE) != CaptureRequest.CONTROL_AF_MODE_AUTO) {
                    builder.set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_AUTO)
                    builder.set(CaptureRequest.CONTROL_AF_TRIGGER, CameraMetadata.CONTROL_AF_TRIGGER_START)
                    session.capture(builder.build(), videoCaptureCallback, backgroundHandler)
                    builder.set(CaptureRequest.CONTROL_AF_TRIGGER, CameraMetadata.CONTROL_AF_TRIGGER_IDLE)
                }
            } else {
                activeFocusPullRunnable?.let { backgroundHandler?.removeCallbacks(it) }
                activeFocusPullRunnable = null
                if (builder.get(CaptureRequest.CONTROL_AF_MODE) == CaptureRequest.CONTROL_AF_MODE_AUTO) {
                    builder.set(CaptureRequest.CONTROL_AF_TRIGGER, CameraMetadata.CONTROL_AF_TRIGGER_CANCEL)
                    session.capture(builder.build(), videoCaptureCallback, backgroundHandler)
                    builder.set(CaptureRequest.CONTROL_AF_TRIGGER, CameraMetadata.CONTROL_AF_TRIGGER_IDLE)
                }
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
            val reqAudioDeviceId = args["audioDeviceId"]?.toString()
            if (reqAudioDeviceId != null) {
                videoPreferredAudioDeviceId = reqAudioDeviceId
            }
            // Release standby AudioRecord before MediaRecorder.prepare()/start() to prevent single-client OEM HAL conflicts
            stopAudioFloatMeterMonitor()
            fallbackSmoothedAudioPower = 0.0

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
                        startAudioFloatMeterMonitor(videoPreferredAudioDeviceId)
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
                        if (videoSessionActive && cameraDevice != null) {
                            startAudioFloatMeterMonitor(videoPreferredAudioDeviceId)
                        }
                        mainHandler.post {
                            result.error("RECORDER_START_ERR", e.message, null)
                        }
                    }
                },
                onFail = { errMsg ->
                    stopVideoRecordingSilent()
                    if (videoSessionActive && cameraDevice != null) {
                        startAudioFloatMeterMonitor(videoPreferredAudioDeviceId)
                    }
                    mainHandler.post {
                        result.error("RECORD_SESSION_ERR", errMsg, null)
                    }
                }
            )
        } catch (e: Exception) {
            stopVideoRecordingSilent()
            if (videoSessionActive && cameraDevice != null) {
                startAudioFloatMeterMonitor(videoPreferredAudioDeviceId)
            }
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

        // Resume clean preview session and standby live audio dBFS metering on the open camera
        val cam = cameraDevice
        if (cam != null && videoSessionActive) {
            try {
                val manager = appContext.getSystemService(Context.CAMERA_SERVICE) as CameraManager
                val chars = manager.getCameraCharacteristics(activePhysicalCameraId ?: activeCameraId)
                configureVideoPreviewOrRecordSession(cam, chars, null, {}, {})
            } catch (e: Throwable) {
                android.util.Log.w("ZameraCapture", "Resume video preview warning: ${e.message}")
            }
            startAudioFloatMeterMonitor(videoPreferredAudioDeviceId)
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
        stopAudioFloatMeterMonitor()
        videoSamplePeakDbfs = -96.0
        videoRmsDbfs = -96.0
        fallbackSmoothedAudioPower = 0.0
        videoAeAfLocked = false
        videoPreferredAudioDeviceId = null
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
            if (!audioMeterActive) {
                videoSamplePeakDbfs = -96.0
                videoRmsDbfs = -96.0
            }
        } else if (!audioMeterActive || videoSamplePeakDbfs <= -95.5) {
            // OEM AudioRecord + MediaRecorder concurrency fallback via MediaRecorder.maxAmplitude
            val amp = try {
                mediaRecorder?.maxAmplitude ?: 0
            } catch (_: Throwable) {
                0
            }
            if (amp > 0) {
                val normPeak = (amp.toDouble() / 32767.0).coerceIn(1e-5, 1.0)
                val peakDb = (20.0 * log10(normPeak)).coerceIn(-96.0, 0.0)
                val instPower = (normPeak * normPeak) * 0.5
                fallbackSmoothedAudioPower = if (fallbackSmoothedAudioPower <= 1e-10) {
                    instPower
                } else {
                    0.60 * fallbackSmoothedAudioPower + 0.40 * instPower
                }
                val rmsDb = (10.0 * log10(fallbackSmoothedAudioPower.coerceAtLeast(1e-10)))
                    .coerceIn(-96.0, peakDb)
                videoSamplePeakDbfs = peakDb
                videoRmsDbfs = rmsDb
            } else if (!audioMeterActive) {
                fallbackSmoothedAudioPower *= 0.35
                videoSamplePeakDbfs = -96.0
                videoRmsDbfs = if (fallbackSmoothedAudioPower > 1e-9) {
                    (10.0 * log10(fallbackSmoothedAudioPower)).coerceIn(-96.0, 0.0)
                } else {
                    -96.0
                }
            }
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
        val meanLumaNorm = latestMeanSceneLumaNorm.coerceIn(0.005, 1.0)
        val fallbackMeteredEv = (ln(meanLumaNorm.coerceAtLeast(0.005) / 0.42) / ln(2.0)).coerceIn(-3.0, 3.0)
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
            "activePhysicalLensId" to (activePhysicalCameraId ?: activeCameraId),
            "liveZebraGrid16x12" to (baseTel["liveZebraGrid16x12"] ?: latestLiveZebraGrid16x12),
            "livePeakingGrid16x12" to (baseTel["livePeakingGrid16x12"] ?: latestLivePeakingGrid16x12),
            "liveFocusPeakingScore" to (baseTel["liveFocusPeakingScore"] ?: latestLiveFocusPeakingScore),
            "solvedCctKelvin" to (baseTel["solvedCctKelvin"] ?: 5500.0),
            "meteredEvDelta" to (baseTel["meteredEvDelta"] ?: fallbackMeteredEv),
            "aeAfLocked" to (baseTel["aeAfLocked"] ?: videoAeAfLocked)
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
        portraitSessionCache.clear()
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
        synchronized(multiclassModelLock) {
            try {
                multiclassInterpreterInstance?.close()
                multiclassInterpreterInstance = null
            } catch (e: Throwable) {
                android.util.Log.w("ZameraCapture", "MulticlassInterpreter close warning: ${e.message}")
            }
        }
        synchronized(depthModelLock) {
            try {
                depthInterpreterInstance?.close()
                depthInterpreterInstance = null
            } catch (e: Throwable) {
                android.util.Log.w("ZameraCapture", "DepthInterpreter close warning: ${e.message}")
            }
        }
        synchronized(u2netModelLock) {
            try {
                u2netInterpreterInstance?.close()
                u2netInterpreterInstance = null
            } catch (e: Throwable) {
                android.util.Log.w("ZameraCapture", "U2NetInterpreter close warning: ${e.message}")
            }
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

    private fun measureJpegTrimmedLinearLuminance(jpegBytes: ByteArray): Float {
        if (jpegBytes.isEmpty()) return 0.0f
        var bmp: Bitmap? = null
        return try {
            val opts = BitmapFactory.Options().apply {
                inSampleSize = 32
                inPreferredConfig = Bitmap.Config.ARGB_8888
            }
            bmp = BitmapFactory.decodeByteArray(jpegBytes, 0, jpegBytes.size, opts)
            val decoded = bmp ?: return 0.0f
            val w = decoded.width
            val h = decoded.height
            if (w <= 0 || h <= 0) return 0.0f
            val pixels = IntArray(w * h)
            decoded.getPixels(pixels, 0, w, 0, 0, w, h)
            computeTrimmedLinearLuminanceFromArgbPixels(pixels)
        } catch (e: Throwable) {
            android.util.Log.w("ZameraCapture", "measureJpegTrimmedLinearLuminance warning: ${e.message}")
            0.0f
        } finally {
            bmp?.recycle()
        }
    }
}

private val SRGB_TO_LINEAR_LUT: FloatArray = FloatArray(256) { idx ->
    val c = idx / 255.0f
    if (c <= 0.04045f) {
        c / 12.92f
    } else {
        ((c + 0.055f) / 1.055f).toDouble().pow(2.4).toFloat()
    }
}

internal fun resolveArtworkExposureMode(explicitMode: Int?, normalizeExposure: Boolean): Int {
    if (explicitMode != null) return explicitMode.coerceIn(0, 2)
    return if (normalizeExposure) 1 else 0
}

internal fun computeTrimmedLinearLuminanceFromArgbPixels(pixels: IntArray): Float {
    if (pixels.isEmpty()) return 0.0f
    val lums = FloatArray(pixels.size)
    for (i in pixels.indices) {
        val px = pixels[i]
        val rLin = SRGB_TO_LINEAR_LUT[(px ushr 16) and 0xFF]
        val gLin = SRGB_TO_LINEAR_LUT[(px ushr 8) and 0xFF]
        val bLin = SRGB_TO_LINEAR_LUT[px and 0xFF]
        lums[i] = 0.2126729f * rLin + 0.7151522f * gLin + 0.0721750f * bLin
    }
    lums.sort()
    val lenM1 = lums.size - 1
    val i15 = (lenM1 * 150) / 1000
    val i85 = ((lenM1 * 850) / 1000).coerceAtLeast(i15)
    var sum = 0.0
    for (i in i15..i85) {
        sum += lums[i]
    }
    return (sum / (i85 - i15 + 1)).toFloat()
}

data class RustRawDevelopOutput(
    val rustIspSucceeded: Boolean,
    val outWidth: Int,
    val outHeight: Int,
    val meanRgb: List<Double>,
    val centerLinearCamRgb: List<Double>,
    val centerLabD50: List<Double>,
    val highlightClippedRatio: Double,
    val gamutClippedRatio: Double,
    val exposureNormGain: Double,
    val solvedCctKelvin: Double,
    val zebraRatio: Double,
    val focusPeakingScore: Double,
    val rawHistogram32: List<Double>,
    val measuredFlatField8x6: List<Double>
)

data class RustColorCheckerCalibOutput(
    val wbGains: FloatArray,
    val camToXyzD50Flat: FloatArray,
    val reportMap: Map<String, Any>
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
        exposureMode: Int,
        outRgbaBuffer: ByteBuffer,
        outStatsBuffer: ByteBuffer
    ): Int

    @JvmStatic
    private external fun nativeCalibrateColorChecker24Direct(
        rawBuffer: ByteBuffer,
        width: Int,
        height: Int,
        rowStride: Int,
        cfaPattern: Int,
        paramsBuffer: ByteBuffer,
        outReportBuffer: ByteBuffer
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

    fun calibrateColorChecker24(
        rawDirectBuffer: ByteBuffer,
        width: Int,
        height: Int,
        rowStride: Int,
        cfaPattern: Int,
        blackLevel: FloatArray,
        whiteLevel: Float,
        cornersNorm: FloatArray,
        flatField8x6: FloatArray?,
        rggbShading4x48: FloatArray?
    ): RustColorCheckerCalibOutput? {
        if (!loaded || cornersNorm.size < 8) return null
        val paramFloats = when {
            rggbShading4x48 != null && rggbShading4x48.size == 192 -> 253
            flatField8x6 != null && flatField8x6.size == 48 -> 61
            else -> 13
        }
        val paramsBuffer = ByteBuffer.allocateDirect(paramFloats * 4).order(ByteOrder.nativeOrder())
        val pf = paramsBuffer.asFloatBuffer()
        pf.put(blackLevel[0])
        pf.put(blackLevel[1])
        pf.put(blackLevel[2])
        pf.put(blackLevel[3])
        pf.put(whiteLevel)
        for (i in 0 until 8) pf.put(cornersNorm[i])
        if (paramFloats >= 61) {
            if (flatField8x6 != null && flatField8x6.size == 48) {
                for (i in 0 until 48) pf.put(flatField8x6[i])
            } else {
                for (i in 0 until 48) pf.put(0.0f)
            }
        }
        if (paramFloats >= 253 && rggbShading4x48 != null) {
            for (i in 0 until 192) pf.put(rggbShading4x48[i])
        }

        val outReportBuffer = ByteBuffer.allocateDirect(63 * 4).order(ByteOrder.nativeOrder())
        val rc = try {
            nativeCalibrateColorChecker24Direct(
                rawDirectBuffer,
                width,
                height,
                rowStride,
                cfaPattern,
                paramsBuffer,
                outReportBuffer
            )
        } catch (t: Throwable) {
            android.util.Log.w("ZameraRustBridge", "nativeCalibrateColorChecker24Direct error: ${t.message}")
            return null
        }
        if (rc != 0) return null

        val rf = outReportBuffer.asFloatBuffer()
        val wb = floatArrayOf(rf.get(0), rf.get(1), rf.get(2))
        val ccmFlat = FloatArray(9) { i -> rf.get(3 + i) }
        val ccmRows = listOf(
            listOf(ccmFlat[0].toDouble(), ccmFlat[1].toDouble(), ccmFlat[2].toDouble()),
            listOf(ccmFlat[3].toDouble(), ccmFlat[4].toDouble(), ccmFlat[5].toDouble()),
            listOf(ccmFlat[6].toDouble(), ccmFlat[7].toDouble(), ccmFlat[8].toDouble())
        )
        val meanBefore = rf.get(12).toDouble()
        val meanAfter = rf.get(13).toDouble()
        val maxAfter = rf.get(14).toDouble()
        val patchBefore = List(24) { i -> rf.get(15 + i).toDouble() }
        val patchAfter = List(24) { i -> rf.get(39 + i).toDouble() }

        val map = mapOf<String, Any>(
            "wbGains" to wb.map { it.toDouble() },
            "camToXyzD50" to ccmRows,
            "meanDeltaEBefore" to meanBefore,
            "meanDeltaEAfter" to meanAfter,
            "maxDeltaEAfter" to maxAfter,
            "patchDeltaEBefore" to patchBefore,
            "patchDeltaEAfter" to patchAfter,
            "isMeasuredFromSensor" to true
        )
        return RustColorCheckerCalibOutput(
            wbGains = wb,
            camToXyzD50Flat = ccmFlat,
            reportMap = map
        )
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
        rggbShading4x48: FloatArray? = null,
        useDisplayP3: Boolean,
        exposureMode: Int,
        fullResolution: Boolean,
        writeTrueColorBitmap: Boolean,
        sensorOrientationDegrees: Int,
        isFrontCamera: Boolean = false,
        applyPerspectiveWarp: Boolean = false,
        perspectiveCornersNorm: FloatArray? = null,
        losslessPng: Boolean = false,
        iso: Int? = null,
        exposureTimeNs: Long? = null,
        aperture: Float? = null,
        focalLengthMm: Float? = null,
        referenceMidY: Float = 0.0f,
        sensorBaselineGain: Float = 1.0f,
        outFile: File
    ): RustRawDevelopOutput {
        if (!loaded) {
            return RustRawDevelopOutput(
                rustIspSucceeded = false,
                outWidth = 0,
                outHeight = 0,
                meanRgb = listOf(0.0, 0.0, 0.0),
                centerLinearCamRgb = listOf(0.18, 0.18, 0.18),
                centerLabD50 = listOf(50.0, 0.0, 0.0),
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

        val hasBaseline = referenceMidY > 0.0f || sensorBaselineGain > 1.005f
        val paramFloats = when {
            hasBaseline -> 289
            rggbShading4x48 != null && rggbShading4x48.size == 192 -> 287
            flatField8x6 != null && flatField8x6.size == 48 -> 95
            else -> 47
        }
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
        if (paramFloats >= 95) {
            if (flatField8x6 != null && flatField8x6.size == 48) {
                for (i in 0 until 48) pf.put(flatField8x6[i])
            } else {
                for (i in 0 until 48) pf.put(0.0f)
            }
        }
        if (paramFloats >= 287) {
            if (rggbShading4x48 != null && rggbShading4x48.size == 192) {
                for (i in 0 until 192) pf.put(rggbShading4x48[i])
            } else {
                for (i in 0 until 192) pf.put(0.0f)
            }
        }
        if (paramFloats >= 289) {
            pf.put(referenceMidY)
            pf.put(sensorBaselineGain)
        }

        val outRgbaBuffer = ByteBuffer.allocateDirect(outW * outH * 4)
        val outStatsBuffer = ByteBuffer.allocateDirect(95 * 4).order(ByteOrder.nativeOrder())

        val rc = nativeDevelopBayer16Direct(
            rawDirectBuffer,
            width,
            height,
            rowStride,
            cfaPattern,
            paramsBuffer,
            if (useDisplayP3) 1 else 0,
            exposureMode.coerceIn(0, 2),
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
                centerLabD50 = listOf(50.0, 0.0, 0.0),
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

            val rotatedBitmap = if (sensorOrientationDegrees != 0 || isFrontCamera) {
                val matrix = Matrix().apply {
                    if (sensorOrientationDegrees != 0) postRotate(sensorOrientationDegrees.toFloat())
                    if (isFrontCamera) postScale(-1f, 1f)
                }
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
                    val warped = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && colorSpace != null) {
                        Bitmap.createBitmap(
                            rotatedBitmap.width,
                            rotatedBitmap.height,
                            Bitmap.Config.ARGB_8888,
                            false,
                            colorSpace
                        )
                    } else {
                        Bitmap.createBitmap(
                            rotatedBitmap.width,
                            rotatedBitmap.height,
                            rotatedBitmap.config ?: Bitmap.Config.ARGB_8888
                        )
                    }
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
                if (losslessPng) {
                    finalBitmap.compress(Bitmap.CompressFormat.PNG, 100, fos)
                } else {
                    finalBitmap.compress(Bitmap.CompressFormat.JPEG, 100, fos)
                }
            }
            finalBitmap.recycle()

            if (!losslessPng) {
                try {
                    val exif = ExifInterface(outFile.absolutePath)
                    exif.setAttribute(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL.toString())
                    // EXIF 2.31 ColorSpace tag: 1 = sRGB, 65535 = Uncalibrated (Display P3 ICC profile embedded)
                    exif.setAttribute(
                        ExifInterface.TAG_COLOR_SPACE,
                        if (useDisplayP3) "65535" else "1"
                    )
                    exif.setAttribute(ExifInterface.TAG_MAKE, Build.MANUFACTURER)
                    exif.setAttribute(ExifInterface.TAG_MODEL, Build.MODEL)
                    exif.setAttribute(ExifInterface.TAG_SOFTWARE, "Zamera TrueColor ISP (D50)")
                    exif.setAttribute(ExifInterface.TAG_IMAGE_WIDTH, finalW.toString())
                    exif.setAttribute(ExifInterface.TAG_IMAGE_LENGTH, finalH.toString())
                    iso?.let { exif.setAttribute(ExifInterface.TAG_ISO_SPEED_RATINGS, it.toString()) }
                    exposureTimeNs?.let {
                        val sec = it.toDouble() / 1_000_000_000.0
                        exif.setAttribute(
                            ExifInterface.TAG_EXPOSURE_TIME,
                            String.format(java.util.Locale.US, "%.6f", sec)
                        )
                    }
                    aperture?.let {
                        exif.setAttribute(
                            ExifInterface.TAG_F_NUMBER,
                            String.format(java.util.Locale.US, "%.2f", it)
                        )
                    }
                    focalLengthMm?.let {
                        exif.setAttribute(ExifInterface.TAG_FOCAL_LENGTH, "${(it * 100f).roundToInt()}/100")
                    }
                    exif.saveAttributes()
                } catch (e: Throwable) {
                    android.util.Log.w("ZameraRustBridge", "EXIF write warning: ${e.message}")
                }
            }
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
        val centerLab = listOf(sf.get(92).toDouble(), sf.get(93).toDouble(), sf.get(94).toDouble())

        return RustRawDevelopOutput(
            rustIspSucceeded = true,
            outWidth = finalW,
            outHeight = finalH,
            meanRgb = listOf(meanR, meanG, meanB),
            centerLinearCamRgb = listOf(centerR, centerG, centerB),
            centerLabD50 = centerLab,
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
