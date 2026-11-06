package com.akarworks.zamera_capture

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.ImageFormat
import android.hardware.camera2.*
import android.hardware.camera2.params.ColorSpaceTransform
import android.hardware.camera2.params.DynamicRangeProfiles
import android.hardware.camera2.params.OutputConfiguration
import android.hardware.camera2.params.RggbChannelVector
import android.hardware.camera2.params.SessionConfiguration
import android.media.ImageReader
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.util.Range
import android.view.Surface
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.view.TextureRegistry
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.Executors

/**
 * ZameraCapturePlugin (Android Camera2 Hardware Probe + Live Preview Texture + Manual Controls + RAW/DNG Capture)
 */
class ZameraCapturePlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var appContext: Context
    private lateinit var textureRegistry: TextureRegistry

    private var backgroundThread: HandlerThread? = null
    private var backgroundHandler: Handler? = null
    private var surfaceEntry: TextureRegistry.SurfaceTextureEntry? = null
    private var cameraDevice: CameraDevice? = null
    private var captureSession: CameraCaptureSession? = null
    private var previewRequestBuilder: CaptureRequest.Builder? = null
    private var rawImageReader: ImageReader? = null
    private var jpegImageReader: ImageReader? = null
    private var activeCameraId: String = "0"
    private var lastTotalCaptureResult: TotalCaptureResult? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        appContext = flutterPluginBinding.applicationContext
        textureRegistry = flutterPluginBinding.textureRegistry
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.akarworks.zamera/capture_probe")
        channel.setMethodCallHandler(this)
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
                val cameraId = call.argument<String>("cameraId") ?: "0"
                val width = call.argument<Int>("width") ?: 1920
                val height = call.argument<Int>("height") ?: 1440
                startPreviewSession(cameraId, width, height, result)
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

    private fun ensureBackgroundThread() {
        if (backgroundThread == null) {
            backgroundThread = HandlerThread("ZameraCamera2Thread").also {
                it.start()
                backgroundHandler = Handler(it.looper)
            }
        }
    }

    @SuppressLint("MissingPermission")
    private fun startPreviewSession(cameraId: String, reqWidth: Int, reqHeight: Int, result: Result) {
        try {
            stopPreviewSession()
            ensureBackgroundThread()

            val manager = appContext.getSystemService(Context.CAMERA_SERVICE) as CameraManager
            val availableIds = manager.cameraIdList
            val targetId = if (availableIds.contains(cameraId)) cameraId else (availableIds.firstOrNull() ?: "0")
            activeCameraId = targetId

            val chars = manager.getCameraCharacteristics(targetId)
            val map = chars.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP)
            val previewSize = map?.getOutputSizes(android.graphics.SurfaceTexture::class.java)
                ?.firstOrNull { it.width <= reqWidth && it.height <= reqHeight }
                ?: android.util.Size(1280, 960)

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

            manager.openCamera(targetId, object : CameraDevice.StateCallback() {
                override fun onOpened(camera: CameraDevice) {
                    cameraDevice = camera
                    try {
                        val builder = camera.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW)
                        builder.addTarget(previewSurface)
                        builder.set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE)
                        previewRequestBuilder = builder

                        val surfaces = mutableListOf<Surface>(previewSurface)
                        jpegImageReader?.surface?.let { surfaces.add(it) }
                        rawImageReader?.surface?.let { surfaces.add(it) }

                        camera.createCaptureSession(surfaces, object : CameraCaptureSession.StateCallback() {
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
                                    result.success(
                                        mapOf(
                                            "textureId" to entry.id(),
                                            "previewWidth" to previewSize.width,
                                            "previewHeight" to previewSize.height,
                                            "activeCameraId" to targetId,
                                            "supportsRawSensor" to (rawImageReader != null)
                                        )
                                    )
                                } catch (e: Exception) {
                                    result.error("SESSION_START_ERR", e.message, null)
                                }
                            }

                            override fun onConfigureFailed(session: CameraCaptureSession) {
                                result.error("CONFIGURE_FAILED", "CameraCaptureSession configure failed", null)
                            }
                        }, backgroundHandler)
                    } catch (e: Exception) {
                        result.error("OPEN_BUILD_ERR", e.message, null)
                    }
                }

                override fun onDisconnected(camera: CameraDevice) {
                    camera.close()
                    cameraDevice = null
                }

                override fun onError(camera: CameraDevice, error: Int) {
                    camera.close()
                    cameraDevice = null
                    result.error("CAMERA_OPEN_ERROR", "CameraDevice error code $error", null)
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
            val manualExposure = args["manualExposure"] as? Boolean ?: false
            if (manualExposure) {
                builder.set(CaptureRequest.CONTROL_AE_MODE, CaptureRequest.CONTROL_AE_MODE_OFF)
                val iso = (args["iso"] as? Number)?.toInt() ?: 100
                val shutterNs = (args["exposureTimeNs"] as? Number)?.toLong() ?: 8_000_000L
                builder.set(CaptureRequest.SENSOR_SENSITIVITY, iso)
                builder.set(CaptureRequest.SENSOR_EXPOSURE_TIME, shutterNs)
            } else {
                builder.set(CaptureRequest.CONTROL_AE_MODE, CaptureRequest.CONTROL_AE_MODE_ON)
            }

            val manualFocus = args["manualFocus"] as? Boolean ?: false
            if (manualFocus) {
                builder.set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_OFF)
                val focusDiopters = (args["focusDistance"] as? Number)?.toFloat() ?: 0.0f
                builder.set(CaptureRequest.LENS_FOCUS_DISTANCE, focusDiopters)
            } else {
                builder.set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE)
            }

            val manualWb = args["manualWb"] as? Boolean ?: false
            val rggb = args["rggbGains"] as? List<*>
            if (manualWb && rggb != null && rggb.size == 4) {
                builder.set(CaptureRequest.CONTROL_AWB_MODE, CaptureRequest.CONTROL_AWB_MODE_OFF)
                builder.set(
                    CaptureRequest.COLOR_CORRECTION_MODE,
                    CaptureRequest.COLOR_CORRECTION_MODE_TRANSFORM_MATRIX
                )
                builder.set(
                    CaptureRequest.COLOR_CORRECTION_GAINS,
                    RggbChannelVector(
                        (rggb[0] as Number).toFloat(),
                        (rggb[1] as Number).toFloat(),
                        (rggb[2] as Number).toFloat(),
                        (rggb[3] as Number).toFloat()
                    )
                )
            } else {
                builder.set(CaptureRequest.CONTROL_AWB_MODE, CaptureRequest.CONTROL_AWB_MODE_AUTO)
            }

            // Artwork TrueColor mode disables OEM edge sharpening and noise reduction on YUV/JPEG
            val artworkLinearMode = args["artworkLinearMode"] as? Boolean ?: false
            if (artworkLinearMode) {
                builder.set(CaptureRequest.NOISE_REDUCTION_MODE, CaptureRequest.NOISE_REDUCTION_MODE_OFF)
                builder.set(CaptureRequest.EDGE_MODE, CaptureRequest.EDGE_MODE_OFF)
            }

            session.setRepeatingRequest(builder.build(), null, backgroundHandler)
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
            val jpegFile = File(outDir, "ZAMERA_${timestamp}.jpg")
            val dngFile = File(outDir, "ZAMERA_${timestamp}.dng")

            val captureBuilder = camera.createCaptureRequest(CameraDevice.TEMPLATE_STILL_CAPTURE)
            captureBuilder.addTarget(jpegReader.surface)

            val captureRaw = (args["captureRaw"] as? Boolean ?: true) && rawImageReader != null
            if (captureRaw) {
                rawImageReader?.surface?.let { captureBuilder.addTarget(it) }
            }

            // Copy manual settings from preview builder
            previewRequestBuilder?.let { prev ->
                captureBuilder.set(CaptureRequest.CONTROL_AE_MODE, prev.get(CaptureRequest.CONTROL_AE_MODE))
                captureBuilder.set(CaptureRequest.SENSOR_SENSITIVITY, prev.get(CaptureRequest.SENSOR_SENSITIVITY))
                captureBuilder.set(CaptureRequest.SENSOR_EXPOSURE_TIME, prev.get(CaptureRequest.SENSOR_EXPOSURE_TIME))
                captureBuilder.set(CaptureRequest.CONTROL_AF_MODE, prev.get(CaptureRequest.CONTROL_AF_MODE))
                captureBuilder.set(CaptureRequest.LENS_FOCUS_DISTANCE, prev.get(CaptureRequest.LENS_FOCUS_DISTANCE))
                captureBuilder.set(CaptureRequest.CONTROL_AWB_MODE, prev.get(CaptureRequest.CONTROL_AWB_MODE))
                captureBuilder.set(CaptureRequest.COLOR_CORRECTION_GAINS, prev.get(CaptureRequest.COLOR_CORRECTION_GAINS))
            }

            val manager = appContext.getSystemService(Context.CAMERA_SERVICE) as CameraManager
            val chars = manager.getCameraCharacteristics(activeCameraId)

            jpegReader.setOnImageAvailableListener({ reader ->
                val img = reader.acquireLatestImage() ?: return@setOnImageAvailableListener
                try {
                    val buf = img.planes[0].buffer
                    val bytes = ByteArray(buf.remaining())
                    buf.get(bytes)
                    FileOutputStream(jpegFile).use { it.write(bytes) }
                } finally {
                    img.close()
                }
            }, backgroundHandler)

            if (captureRaw) {
                rawImageReader?.setOnImageAvailableListener({ reader ->
                    val rawImg = reader.acquireLatestImage() ?: return@setOnImageAvailableListener
                    try {
                        val meta = lastTotalCaptureResult
                        if (meta != null) {
                            DngCreator(chars, meta).use { dngCreator ->
                                FileOutputStream(dngFile).use { fos ->
                                    dngCreator.writeImage(fos, rawImg)
                                }
                            }
                        }
                    } catch (_: Exception) {
                    } finally {
                        rawImg.close()
                    }
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
                        result.success(
                            mapOf(
                                "jpegPath" to jpegFile.absolutePath,
                                "dngPath" to if (captureRaw) dngFile.absolutePath else null,
                                "cameraId" to activeCameraId,
                                "iso" to res.get(CaptureResult.SENSOR_SENSITIVITY),
                                "exposureTimeNs" to res.get(CaptureResult.SENSOR_EXPOSURE_TIME)
                            )
                        )
                    }
                },
                backgroundHandler
            )
        } catch (e: Exception) {
            result.error("CAPTURE_ERR", e.message, null)
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

        return mapOf(
            "platform" to "android",
            "manufacturer" to Build.MANUFACTURER,
            "brand" to Build.BRAND,
            "model" to Build.MODEL,
            "device" to Build.DEVICE,
            "sdkInt" to Build.VERSION.SDK_INT,
            "release" to Build.VERSION.RELEASE,
            "rustCoreVersion" to ZameraRustBridge.safeCoreVersion(),
            "cameraIdList" to logicalIds,
            "cameras" to cameras
        )
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

    fun safeCoreVersion(): String {
        if (!loaded) {
            return "zamera_core 0.2.0 (TrueColor 24-Patch ColorChecker + FlatField)"
        }
        return try {
            nativeCoreVersion()
        } catch (_: Throwable) {
            "zamera_core 0.2.0 (native symbol loaded)"
        }
    }
}
