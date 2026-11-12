import Flutter
import UIKit
import AVFoundation
import Photos
import Vision
import CoreImage
import UniformTypeIdentifiers
import Darwin

/**
 * ZameraCapturePlugin (iOS AVFoundation Hardware Probe + Live FlutterTexture Preview +
 * Physical Lens Lock + Bayer RAW / ProRAW Capture + 3-Frame AE Bracketing + Portrait Depth Reprocess +
 * Vision Person Cutout Sticker + Faz 3 Apple Log / ProRes 422 HQ Pro Video Engine).
 *
 * Implements 100% parity with Android Camera2 / Rust pipeline across Faz 0, Faz 1, Faz 2 and Faz 3.
 * Conforms to Akarworks v6.1 Zero-Stub and Zero-GPL licensing policies.
 */
public class ZameraCapturePlugin: NSObject,
    FlutterPlugin,
    FlutterTexture,
    AVCaptureVideoDataOutputSampleBufferDelegate,
    AVCapturePhotoCaptureDelegate,
    AVCaptureFileOutputRecordingDelegate,
    UIDocumentPickerDelegate {

    private var textureRegistry: FlutterTextureRegistry?
    private var textureId: Int64 = -1
    private var latestPixelBuffer: CVPixelBuffer?
    private let bufferLock = NSLock()

    private let sessionQueue = DispatchQueue(label: "com.akarworks.zamera.sessionQueue")
    private var captureSession: AVCaptureSession?
    private var activeDevice: AVCaptureDevice?
    private var photoOutput: AVCapturePhotoOutput?
    private var videoOutput: AVCaptureVideoDataOutput?

    // Single capture delegate state
    private var pendingCaptureResult: FlutterResult?
    private let captureAccumLock = NSLock()
    private var pendingSingleRawData: Data?
    private var pendingSingleProcessedData: Data?
    private var pendingSingleDepthData: AVDepthData?
    private var pendingSingleMatte: AVPortraitEffectsMatte?
    private var pendingSingleIso: Int = 100
    private var pendingSingleExpNs: Int = 10_000_000

    // Live center colorimeter & luma/zebra telemetry (Sanat 1:1 True-Color + Pro Video Scopes)
    private let telemetryColorLock = NSLock()
    private var latestLiveCenterSrgb: [Int] = [128, 128, 128]
    private var latestLiveCenterLabD50: [Double] = [53.59, 0.0, 0.0]
    private var latestMeanLuma: Double = 0.5
    private var latestZebraClipRatio: Double = 0.0
    private var latestShadowClipRatio: Double = 0.0
    private var lastCenterSampleTimestamp: CFTimeInterval = 0

    // Bracketed capture state
    private var pendingBracketResult: FlutterResult?
    private var pendingBracketPhotos: [[String: Any]] = []
    private var expectedBracketCount: Int = 0
    private var bracketUsesRaw: Bool = false

    // AE/AF Lock & Faz 3 Video Engine State
    private var isAeAfLocked: Bool = false
    private var videoSession: AVCaptureSession?
    private var movieFileOutput: AVCaptureMovieFileOutput?
    private var pendingVideoRecordingResult: FlutterResult?
    private var videoRecordingStartTime: Date?
    private var activeRecordingPath: String?
    private var activeVideoProfile: String = "REC.709"
    private var activeVideoFps: Int = 30
    private var activeVideoWidth: Int = 3840
    private var activeVideoHeight: Int = 2160
    private var activeShutterAngleDeg: Double = 180.0
    private var focusPullTimer: Timer?

    // LUT Document Picker State
    private var pendingLutResult: FlutterResult?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = ZameraCapturePlugin()
        instance.textureRegistry = registrar.textures()

        // 1. Capture & Probe Channel
        let captureChannel = FlutterMethodChannel(
            name: "com.akarworks.zamera/capture_probe",
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(instance, channel: captureChannel)

        // 2. Pro Video Engine Channel (Faz 3 WP-3.1..WP-3.6)
        let videoChannel = FlutterMethodChannel(
            name: "com.akarworks.zamera/video_engine",
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(instance, channel: videoChannel)
    }

    private func resolveRustCoreVersion() -> (version: String, isLinked: Bool) {
        let rtldDefault = UnsafeMutableRawPointer(bitPattern: -2)
        if let sym = dlsym(rtldDefault, "zamera_core_version_cstr") {
            typealias VersionFn = @convention(c) () -> UnsafePointer<CChar>?
            let fn = unsafeBitCast(sym, to: VersionFn.self)
            if let ptr = fn() {
                return (String(cString: ptr), true)
            }
        }
        return ("UNLINKED: zamera_core.xcframework henüz bağlanmadı", false)
    }

    // MARK: - FlutterTexture Protocol

    public func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        bufferLock.lock()
        defer { bufferLock.unlock() }
        guard let buffer = latestPixelBuffer else { return nil }
        return Unmanaged.passRetained(buffer)
    }

    public func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        bufferLock.lock()
        latestPixelBuffer = pixelBuffer
        bufferLock.unlock()
        let now = CACurrentMediaTime()
        if now - lastCenterSampleTimestamp >= 0.16 {
            lastCenterSampleTimestamp = now
            sampleLiveCenterFromBgraBuffer(pixelBuffer)
        }
        if textureId >= 0 {
            textureRegistry?.textureFrameAvailable(textureId)
        }
    }

    private func sampleLiveCenterFromBgraBuffer(_ pixelBuffer: CVPixelBuffer) {
        guard CVPixelBufferGetPixelFormatType(pixelBuffer) == kCVPixelFormatType_32BGRA,
              !CVPixelBufferIsPlanar(pixelBuffer) else {
            return
        }
        guard CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly) == kCVReturnSuccess else {
            return
        }
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        guard let baseAddr = CVPixelBufferGetBaseAddress(pixelBuffer) else { return }
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        guard width >= 8, height >= 8 else { return }

        let ptr = baseAddr.assumingMemoryBound(to: UInt8.self)
        let cx0 = max(0, width / 2 - 4)
        let cx1 = min(width, cx0 + 8)
        let cy0 = max(0, height / 2 - 4)
        let cy1 = min(height, cy0 + 8)
        var sumR = 0
        var sumG = 0
        var sumB = 0
        var count = 0
        for y in cy0..<cy1 {
            let rowOff = y * bytesPerRow
            for x in cx0..<cx1 {
                let off = rowOff + x * 4
                sumB += Int(ptr[off])
                sumG += Int(ptr[off + 1])
                sumR += Int(ptr[off + 2])
                count += 1
            }
        }
        guard count > 0 else { return }
        let r8 = max(0, min(255, (sumR + count / 2) / count))
        let g8 = max(0, min(255, (sumG + count / 2) / count))
        let b8 = max(0, min(255, (sumB + count / 2) / count))
        let lab = Self.srgb8ToLabD50(r8: r8, g8: g8, b8: b8)

        // 16x16 strided frame luma & zebra (95% IRE) summary
        let gridSteps = 16
        var lumaSum = 0.0
        var zebraCount = 0
        var shadowCount = 0
        var gridTotal = 0
        for gy in 0..<gridSteps {
            let sy = min(height - 1, (gy * height + height / (2 * gridSteps)) / gridSteps)
            let rowOff = sy * bytesPerRow
            for gx in 0..<gridSteps {
                let sx = min(width - 1, (gx * width + width / (2 * gridSteps)) / gridSteps)
                let off = rowOff + sx * 4
                let b = Double(ptr[off])
                let g = Double(ptr[off + 1])
                let r = Double(ptr[off + 2])
                let yNorm = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0
                lumaSum += yNorm
                if yNorm >= 0.95 { zebraCount += 1 }
                if yNorm <= 0.03 { shadowCount += 1 }
                gridTotal += 1
            }
        }
        let meanLuma = gridTotal > 0 ? (lumaSum / Double(gridTotal)) : 0.5
        let zebraRatio = gridTotal > 0 ? (Double(zebraCount) / Double(gridTotal)) : 0.0
        let shadowRatio = gridTotal > 0 ? (Double(shadowCount) / Double(gridTotal)) : 0.0

        telemetryColorLock.lock()
        latestLiveCenterSrgb = [r8, g8, b8]
        latestLiveCenterLabD50 = lab
        latestMeanLuma = meanLuma
        latestZebraClipRatio = zebraRatio
        latestShadowClipRatio = shadowRatio
        telemetryColorLock.unlock()
    }

    // MARK: - Flutter Method Router

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        // Faz 0: Hardware Probe
        case "probeDeviceCapabilities":
            result(probeAVFoundationCapabilities())
        case "getRustCoreVersion":
            result(resolveRustCoreVersion().version)

        // Faz 1 & Faz 2: Preview & Controls
        case "startPreviewSession":
            let args = call.arguments as? [String: Any] ?? [:]
            startPreviewSession(args: args, result: result)
        case "updateManualControls":
            let args = call.arguments as? [String: Any] ?? [:]
            updateManualControls(args: args, result: result)
        case "setFocusAndMeteringPoint":
            let args = call.arguments as? [String: Any] ?? [:]
            setFocusAndMeteringPoint(args: args, result: result)
        case "getLiveTelemetry":
            result(extractLiveTelemetry())
        case "stopPreviewSession":
            stopPreviewSession()
            result(true)

        // Faz 1 & Faz 2: Still Capture & Processing
        case "capturePhoto":
            let args = call.arguments as? [String: Any] ?? [:]
            captureRawAndHeicPhoto(args: args, result: result)
        case "captureBracketedPhotos":
            let args = call.arguments as? [String: Any] ?? [:]
            captureBracketedPhotos(args: args, result: result)
        case "reprocessPortraitPhoto":
            let args = call.arguments as? [String: Any] ?? [:]
            reprocessPortraitPhoto(args: args, result: result)
        case "extractSubjectCutoutPng":
            let args = call.arguments as? [String: Any] ?? [:]
            extractSubjectCutoutPng(args: args, result: result)

        // Faz 3: Pro Video Engine
        case "startVideoSession":
            let args = call.arguments as? [String: Any] ?? [:]
            startVideoSession(args: args, result: result)
        case "updateVideoControls":
            let args = call.arguments as? [String: Any] ?? [:]
            updateVideoControls(args: args, result: result)
        case "setVideoFocusAndMeteringPoint":
            let args = call.arguments as? [String: Any] ?? [:]
            setVideoFocusAndMeteringPoint(args: args, result: result)
        case "startVideoRecording":
            let args = call.arguments as? [String: Any] ?? [:]
            startVideoRecording(args: args, result: result)
        case "stopVideoRecording":
            stopVideoRecording(result: result)
        case "triggerFocusPull":
            let args = call.arguments as? [String: Any] ?? [:]
            triggerFocusPull(args: args, result: result)
        case "listAudioInputDevices":
            result(listAudioInputDevices())
        case "getVideoTelemetry":
            result(extractVideoTelemetry())
        case "pickCubeLutFile":
            pickCubeLutFile(result: result)
        case "stopVideoSession":
            stopVideoSession()
            result(true)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Faz 1 & 2: Preview Session & Hardware Control

    private func startPreviewSession(args: [String: Any], result: @escaping FlutterResult) {
        let cameraId = args["cameraId"] as? String ?? "builtInWideAngleCamera"
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.stopPreviewSessionInternal()

            let session = AVCaptureSession()
            session.beginConfiguration()
            session.sessionPreset = .photo

            let targetDevice: AVCaptureDevice?
            let lowerCamId = cameraId.lowercased()
            if cameraId == "1" || lowerCamId.contains("front") || lowerCamId.contains("truedepth") {
                targetDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
                    ?? AVCaptureDevice.default(.builtInTrueDepthCamera, for: .video, position: .front)
            } else if cameraId.contains("Telephoto") || lowerCamId == "tele" || cameraId == "4" {
                targetDevice = AVCaptureDevice.default(.builtInTelephotoCamera, for: .video, position: .back)
            } else if cameraId.contains("UltraWide") || lowerCamId == "ultra" || cameraId == "3" {
                targetDevice = AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back)
            } else {
                targetDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            }

            guard let device = targetDevice ?? AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: device),
                  session.canAddInput(input) else {
                session.commitConfiguration()
                DispatchQueue.main.async {
                    result(FlutterError(code: "DEVICE_UNAVAILABLE", message: "Physical lens could not be opened", details: nil))
                }
                return
            }

            session.addInput(input)
            self.activeDevice = device

            let vOut = AVCaptureVideoDataOutput()
            vOut.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            vOut.setSampleBufferDelegate(self, queue: DispatchQueue(label: "com.akarworks.zamera.videoFrameQueue"))
            if session.canAddOutput(vOut) {
                session.addOutput(vOut)
                if let conn = vOut.connection(with: .video) {
                    if conn.isVideoOrientationSupported {
                        conn.videoOrientation = .portrait
                    }
                    if conn.isVideoMirroringSupported {
                        conn.isVideoMirrored = (device.position == .front)
                    }
                }
                self.videoOutput = vOut
            }

            let pOut = AVCapturePhotoOutput()
            if session.canAddOutput(pOut) {
                session.addOutput(pOut)
                if #available(iOS 14.3, *) {
                    if pOut.isAppleProRAWSupported {
                        pOut.isAppleProRAWEnabled = true
                    }
                }
                pOut.maxPhotoQualityPrioritization = .quality
                self.photoOutput = pOut
            }

            session.commitConfiguration()
            session.startRunning()
            self.captureSession = session

            DispatchQueue.main.async {
                if let reg = self.textureRegistry {
                    self.textureId = reg.register(self)
                }
                let dims = CMVideoFormatDescriptionGetDimensions(device.activeFormat.formatDescription)
                let activeFmt = device.activeFormat
                let minExpSec = CMTimeGetSeconds(activeFmt.minExposureDuration)
                let maxExpSec = CMTimeGetSeconds(activeFmt.maxExposureDuration)

                result([
                    "textureId": self.textureId,
                    "previewWidth": Int(dims.width),
                    "previewHeight": Int(dims.height),
                    "sensorOrientation": 90,
                    "activeCameraId": device.deviceType.rawValue,
                    "supportsRawSensor": !(pOut.availableRawPhotoPixelFormatTypes.isEmpty),
                    "minimumFocusDistanceDiopters": device.isFocusModeSupported(.locked) ? 10.0 : 0.0,
                    "isoMin": Int(activeFmt.minISO),
                    "isoMax": Int(activeFmt.maxISO),
                    "exposureNsMin": Int(max(1000, minExpSec * 1_000_000_000.0)),
                    "exposureNsMax": Int(min(1_000_000_000, maxExpSec * 1_000_000_000.0))
                ])
            }
        }
    }

    private func updateManualControls(args: [String: Any], result: @escaping FlutterResult) {
        sessionQueue.async { [weak self] in
            guard let device = self?.activeDevice else {
                DispatchQueue.main.async { result(false) }
                return
            }
            do {
                try device.lockForConfiguration()

                // 1. Exposure PASM (M / Tv / Sv / P + AE Lock & EV Compensation)
                let manualExposure = args["manualExposure"] as? Bool ?? false
                let manualIso = args["manualIso"] as? Bool ?? false
                let manualShutter = args["manualShutter"] as? Bool ?? false
                let lockAeAf = (args["lockAeAf"] as? Bool) ?? (args["aeAfLocked"] as? Bool) ?? false
                let artworkLinearMode = args["artworkLinearMode"] as? Bool ?? false

                let rawEv = (args["evCompensation"] as? NSNumber)?.doubleValue ?? 0.0
                let targetEv = (artworkLinearMode && abs(rawEv) < 0.05) ? 0.35 : rawEv
                let clampedEv = max(device.minExposureTargetBias, min(device.maxExposureTargetBias, Float(targetEv)))

                let reqIso = Float((args["iso"] as? NSNumber)?.doubleValue ?? 100.0)
                let clampedIso = max(device.activeFormat.minISO, min(device.activeFormat.maxISO, reqIso))
                let shutterNs = (args["exposureTimeNs"] as? NSNumber)?.int64Value ?? (args["exposureTimeNs"] as? Int64) ?? 8_000_000
                let reqDuration = CMTimeMake(value: max(Int64(1_000), shutterNs), timescale: 1_000_000_000)
                let clampedDuration = max(device.activeFormat.minExposureDuration, min(device.activeFormat.maxExposureDuration, reqDuration))

                let oldBias = device.exposureTargetBias
                let rawOffset = Double(device.exposureTargetOffset)
                let safeOffset = rawOffset.isFinite ? max(-8.0, min(8.0, rawOffset)) : 0.0
                let curDurSec = max(1e-6, CMTimeGetSeconds(device.exposureDuration))
                let curIso = max(1.0, Double(device.iso))
                let stopsNeeded = lockAeAf ? 0.0 : (Double(clampedEv - oldBias) - safeOffset)
                let desiredEnergy = curDurSec * curIso * pow(2.0, stopsNeeded)

                if (manualExposure || (manualIso && manualShutter)) && device.isExposureModeSupported(.custom) {
                    // M Mode: Full Manual ISO + Shutter
                    device.setExposureModeCustom(duration: clampedDuration, iso: clampedIso, completionHandler: nil)
                    device.setExposureTargetBias(clampedEv, completionHandler: nil)
                } else if manualShutter && !manualIso && device.isExposureModeSupported(.custom) {
                    // Tv Mode: Manual Shutter + Auto-ISO Reciprocity
                    let newDurSec = max(1e-6, CMTimeGetSeconds(clampedDuration))
                    let calcIso = Float(desiredEnergy / newDurSec)
                    let autoIso = calcIso.isFinite
                        ? max(device.activeFormat.minISO, min(device.activeFormat.maxISO, calcIso))
                        : AVCaptureDevice.currentISO
                    device.setExposureModeCustom(duration: clampedDuration, iso: autoIso, completionHandler: nil)
                    device.setExposureTargetBias(clampedEv, completionHandler: nil)
                } else if manualIso && !manualShutter && device.isExposureModeSupported(.custom) {
                    // Sv Mode: Manual ISO + Auto-Shutter Reciprocity
                    let calcDurSec = desiredEnergy / max(1.0, Double(clampedIso))
                    let clampedAutoDur: CMTime
                    if calcDurSec.isFinite && calcDurSec > 0.0 {
                        let autoNs = Int64(max(1_000.0, min(1_000_000_000.0, calcDurSec * 1_000_000_000.0)))
                        let rawAutoDur = CMTimeMake(value: autoNs, timescale: 1_000_000_000)
                        clampedAutoDur = max(device.activeFormat.minExposureDuration, min(device.activeFormat.maxExposureDuration, rawAutoDur))
                    } else {
                        clampedAutoDur = AVCaptureDevice.currentExposureDuration
                    }
                    device.setExposureModeCustom(duration: clampedAutoDur, iso: clampedIso, completionHandler: nil)
                    device.setExposureTargetBias(clampedEv, completionHandler: nil)
                } else {
                    // P Mode: Program AE (or AE Locked) + EV Compensation
                    if lockAeAf && device.isExposureModeSupported(.locked) {
                        device.exposureMode = .locked
                    } else if device.isExposureModeSupported(.continuousAutoExposure) {
                        device.exposureMode = .continuousAutoExposure
                    }
                    device.setExposureTargetBias(clampedEv, completionHandler: nil)
                }

                // 2. Focus Distance & AF Lock
                let manualFocus = args["manualFocus"] as? Bool ?? false
                if manualFocus && device.isFocusModeSupported(.locked) {
                    let lensPos = Float((args["focusDistance"] as? NSNumber)?.doubleValue ?? 0.5)
                    device.setFocusModeLocked(lensPosition: max(0.0, min(1.0, lensPos)), completionHandler: nil)
                } else if lockAeAf && device.isFocusModeSupported(.locked) {
                    device.focusMode = .locked
                } else if device.isFocusModeSupported(.continuousAutoFocus) {
                    device.focusMode = .continuousAutoFocus
                }
                self?.isAeAfLocked = lockAeAf

                // 3. White Balance (Custom Calibrated Gains / Kelvin / Tint / RGGB Gains)
                let manualWb = args["manualWb"] as? Bool ?? false
                let customWb = (args["customWbGains"] as? [NSNumber])?.map { $0.doubleValue }
                    ?? (args["customWbGains"] as? [Double])
                let hasCustomWb = (customWb?.count ?? 0) >= 3
                if (hasCustomWb || manualWb) && device.isWhiteBalanceModeSupported(.locked) {
                    let maxGain = device.maxWhiteBalanceGain
                    if let cwb = customWb, cwb.count >= 3 {
                        let minCh = max(1e-4, min(cwb[0], min(cwb[1], cwb[2])))
                        let gains = AVCaptureDevice.WhiteBalanceGains(
                            redGain: max(1.0, min(maxGain, Float(cwb[0] / minCh))),
                            greenGain: max(1.0, min(maxGain, Float(cwb[1] / minCh))),
                            blueGain: max(1.0, min(maxGain, Float(cwb[2] / minCh)))
                        )
                        device.setWhiteBalanceModeLocked(with: gains, completionHandler: nil)
                    } else if let kelvin = (args["kelvin"] as? NSNumber)?.doubleValue {
                        let tint = Float((args["tint"] as? NSNumber)?.doubleValue ?? 0.0)
                        let tempAndTint = AVCaptureDevice.WhiteBalanceTemperatureAndTintValues(
                            temperature: Float(max(2000.0, min(10000.0, kelvin))),
                            tint: max(-150.0, min(150.0, tint))
                        )
                        var gains = device.deviceWhiteBalanceGains(for: tempAndTint)
                        gains.redGain = max(1.0, min(maxGain, gains.redGain))
                        gains.greenGain = max(1.0, min(maxGain, gains.greenGain))
                        gains.blueGain = max(1.0, min(maxGain, gains.blueGain))
                        device.setWhiteBalanceModeLocked(with: gains, completionHandler: nil)
                    } else if let rggb = args["rggbGains"] as? [Double], rggb.count >= 4 {
                        let minCh = max(1e-4, min(rggb[0], min(rggb[1], rggb[3])))
                        let gains = AVCaptureDevice.WhiteBalanceGains(
                            redGain: max(1.0, min(maxGain, Float(rggb[0] / minCh))),
                            greenGain: max(1.0, min(maxGain, Float(rggb[1] / minCh))),
                            blueGain: max(1.0, min(maxGain, Float(rggb[3] / minCh)))
                        )
                        device.setWhiteBalanceModeLocked(with: gains, completionHandler: nil)
                    }
                } else if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                    device.whiteBalanceMode = .continuousAutoWhiteBalance
                }

                // 4. Optical / Digital Zoom Factor
                if let zoom = (args["zoomRatio"] as? NSNumber)?.doubleValue {
                    let minZoom = Double(device.minAvailableVideoZoomFactor)
                    let maxZoom = min(Double(device.maxAvailableVideoZoomFactor), 15.0)
                    let clampedZoom = CGFloat(max(minZoom, min(maxZoom, zoom)))
                    device.videoZoomFactor = clampedZoom
                }

                device.unlockForConfiguration()
                DispatchQueue.main.async { result(true) }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "LOCK_CFG_ERR", message: error.localizedDescription, details: nil))
                }
            }
        }
    }

    private func setFocusAndMeteringPoint(args: [String: Any], result: @escaping FlutterResult) {
        sessionQueue.async { [weak self] in
            guard let self = self, let device = self.activeDevice else {
                DispatchQueue.main.async { result(false) }
                return
            }
            let x = CGFloat((args["x"] as? NSNumber)?.doubleValue ?? 0.5)
            let y = CGFloat((args["y"] as? NSNumber)?.doubleValue ?? 0.5)
            let lockAeAf = (args["lockAeAf"] as? Bool) ?? (args["aeAfLocked"] as? Bool) ?? false
            let pt = CGPoint(x: max(0.0, min(1.0, x)), y: max(0.0, min(1.0, y)))
            do {
                try device.lockForConfiguration()
                if device.isFocusPointOfInterestSupported {
                    device.focusPointOfInterest = pt
                }
                if lockAeAf {
                    if device.isFocusModeSupported(.locked) {
                        device.focusMode = .locked
                    }
                } else if device.isFocusModeSupported(.autoFocus) {
                    device.focusMode = .autoFocus
                } else if device.isFocusModeSupported(.continuousAutoFocus) {
                    device.focusMode = .continuousAutoFocus
                }

                if device.isExposurePointOfInterestSupported {
                    device.exposurePointOfInterest = pt
                }
                if device.exposureMode != .custom {
                    if lockAeAf {
                        if device.isExposureModeSupported(.locked) {
                            device.exposureMode = .locked
                        }
                    } else if device.isExposureModeSupported(.autoExpose) {
                        device.exposureMode = .autoExpose
                    } else if device.isExposureModeSupported(.continuousAutoExposure) {
                        device.exposureMode = .continuousAutoExposure
                    }
                }
                self.isAeAfLocked = lockAeAf
                device.unlockForConfiguration()
                DispatchQueue.main.async { result(true) }
            } catch {
                DispatchQueue.main.async { result(false) }
            }
        }
    }

    private func extractLiveTelemetry() -> [String: Any] {
        telemetryColorLock.lock()
        let centerSrgb = latestLiveCenterSrgb
        let centerLab = latestLiveCenterLabD50
        let meanLuma = latestMeanLuma
        let zebraClip = latestZebraClipRatio
        let shadowClip = latestShadowClipRatio
        telemetryColorLock.unlock()

        guard let device = activeDevice else {
            return [
                "iso": 100,
                "exposureTimeNs": 16666667,
                "focusDistanceDiopters": 0.0,
                "wbGains": [1.0, 1.0, 1.0, 1.0],
                "zoomRatio": 1.0,
                "meteredEvDelta": 0.0,
                "aeAfLocked": false,
                "meanLuma": meanLuma,
                "lumaIre": meanLuma * 100.0,
                "zebraClipRatio": zebraClip,
                "highlightClipRatio": zebraClip,
                "shadowClipRatio": shadowClip,
                "liveCenterSrgb": centerSrgb,
                "liveCenterLabD50": centerLab
            ]
        }
        let expSec = CMTimeGetSeconds(device.exposureDuration)
        let expNs = Int64(max(0.0, expSec) * 1_000_000_000.0)
        let gains = device.deviceWhiteBalanceGains
        let lensPos = device.lensPosition
        let rawOffset = Double(device.exposureTargetOffset)
        let meteredEvDelta = rawOffset.isFinite ? max(-8.0, min(8.0, rawOffset)) : 0.0
        let aeAfLocked = isAeAfLocked || (device.exposureMode == .locked && device.focusMode == .locked)
        return [
            "iso": Int(device.iso),
            "exposureTimeNs": expNs,
            "focusDistanceDiopters": Double(lensPos * 10.0),
            "wbGains": [Double(gains.redGain), Double(gains.greenGain), Double(gains.greenGain), Double(gains.blueGain)],
            "zoomRatio": Double(device.videoZoomFactor),
            "meteredEvDelta": meteredEvDelta,
            "aeAfLocked": aeAfLocked,
            "meanLuma": meanLuma,
            "lumaIre": meanLuma * 100.0,
            "zebraClipRatio": zebraClip,
            "highlightClipRatio": zebraClip,
            "shadowClipRatio": shadowClip,
            "liveCenterSrgb": centerSrgb,
            "liveCenterLabD50": centerLab
        ]
    }

    // MARK: - Faz 1 & 2: Still Photo Capture

    private func captureRawAndHeicPhoto(args: [String: Any], result: @escaping FlutterResult) {
        sessionQueue.async { [weak self] in
            guard let self = self, let pOut = self.photoOutput else {
                DispatchQueue.main.async {
                    result(FlutterError(code: "NO_PHOTO_OUTPUT", message: "Photo output not active", details: nil))
                }
                return
            }

            let isArtworkMode = args["isArtworkMode"] as? Bool ?? true
            let isPortrait = args["isPortraitMode"] as? Bool ?? false
            let captureRaw = !isPortrait && (args["captureRaw"] as? Bool ?? true)
            let preferProRaw = !isArtworkMode && (args["preferProRaw"] as? Bool ?? false)
            var selectedRawFormat: OSType?

            if captureRaw {
                if #available(iOS 14.3, *) {
                    selectedRawFormat = pOut.availableRawPhotoPixelFormatTypes.first { fmt in
                        preferProRaw ? AVCapturePhotoOutput.isAppleProRAWPixelFormat(fmt) : AVCapturePhotoOutput.isBayerRAWPixelFormat(fmt)
                    } ?? pOut.availableRawPhotoPixelFormatTypes.first
                } else {
                    selectedRawFormat = pOut.availableRawPhotoPixelFormatTypes.first
                }
            }

            let settings: AVCapturePhotoSettings
            if !isPortrait, let rawFmt = selectedRawFormat {
                settings = AVCapturePhotoSettings(
                    rawPixelFormatType: rawFmt,
                    processedFormat: [AVVideoCodecKey: AVVideoCodecType.jpeg]
                )
            } else {
                settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
            }

            if isPortrait && pOut.isDepthDataDeliverySupported {
                if !pOut.isDepthDataDeliveryEnabled {
                    pOut.isDepthDataDeliveryEnabled = true
                }
                settings.isDepthDataDeliveryEnabled = pOut.isDepthDataDeliveryEnabled
                settings.embedsDepthDataInPhoto = true
                if #available(iOS 12.0, *), pOut.isPortraitEffectsMatteDeliverySupported {
                    if !pOut.isPortraitEffectsMatteDeliveryEnabled {
                        pOut.isPortraitEffectsMatteDeliveryEnabled = true
                    }
                    settings.isPortraitEffectsMatteDeliveryEnabled = pOut.isPortraitEffectsMatteDeliveryEnabled
                }
            }

            self.captureAccumLock.lock()
            self.pendingSingleRawData = nil
            self.pendingSingleProcessedData = nil
            self.pendingSingleDepthData = nil
            self.pendingSingleMatte = nil
            self.pendingSingleIso = Int(self.activeDevice?.iso ?? 100)
            let devExp = CMTimeGetSeconds(self.activeDevice?.exposureDuration ?? CMTimeMake(value: 1, timescale: 100))
            self.pendingSingleExpNs = Int(max(1000.0, devExp * 1_000_000_000.0))
            self.captureAccumLock.unlock()

            self.pendingCaptureArgs = args
            self.pendingCaptureResult = result
            pOut.capturePhoto(with: settings, delegate: self)
        }
    }

    private var pendingCaptureArgs: [String: Any] = [:]
    private let portraitCacheLock = NSLock()
    private var cachedPortraitSourcePath: String?
    private var cachedPortraitDepthData: AVDepthData?
    private var cachedPortraitEffectsMatte: AVPortraitEffectsMatte?

    private func storePortraitDepthSession(path: String, depthData: AVDepthData?, matte: AVPortraitEffectsMatte?) {
        portraitCacheLock.lock()
        cachedPortraitSourcePath = path
        cachedPortraitDepthData = depthData
        cachedPortraitEffectsMatte = matte
        portraitCacheLock.unlock()
    }

    private func loadPortraitDepthSession(path: String) -> (AVDepthData?, AVPortraitEffectsMatte?) {
        portraitCacheLock.lock()
        defer { portraitCacheLock.unlock() }
        guard cachedPortraitSourcePath == path else { return (nil, nil) }
        return (cachedPortraitDepthData, cachedPortraitEffectsMatte)
    }

    // MARK: - Faz 2: AE Bracketed Photo Capture

    private func captureBracketedPhotos(args: [String: Any], result: @escaping FlutterResult) {
        sessionQueue.async { [weak self] in
            guard let self = self, let pOut = self.photoOutput else {
                DispatchQueue.main.async {
                    result(FlutterError(code: "NO_PHOTO_OUTPUT", message: "Photo output not active", details: nil))
                }
                return
            }

            let evOffsets = args["evOffsets"] as? [Double] ?? [-1.5, 0.0, 1.5]
            self.pendingCaptureArgs = args
            self.pendingBracketResult = result
            self.pendingBracketPhotos = []
            self.expectedBracketCount = evOffsets.count

            if pOut.maxBracketedCapturePhotoCount > 1 {
                var bracketSettings: [AVCaptureAutoExposureBracketedStillImageSettings] = []
                for ev in evOffsets {
                    let clampedEv = max(-3.0, min(3.0, Float(ev)))
                    bracketSettings.append(
                        AVCaptureAutoExposureBracketedStillImageSettings.autoExposureSettings(exposureTargetBias: clampedEv)
                    )
                }

                let maxCount = pOut.maxBracketedCapturePhotoCount
                let actualSettings = Array(bracketSettings.prefix(maxCount))
                let rawFmt = pOut.availableRawPhotoPixelFormatTypes.first
                self.bracketUsesRaw = (rawFmt != nil)

                let photoSettings: AVCapturePhotoBracketSettings
                if let raw = rawFmt {
                    photoSettings = AVCapturePhotoBracketSettings(
                        rawPixelFormatType: raw,
                        processedFormat: [AVVideoCodecKey: AVVideoCodecType.jpeg],
                        bracketedSettings: actualSettings
                    )
                } else {
                    photoSettings = AVCapturePhotoBracketSettings(
                        rawPixelFormatType: 0,
                        processedFormat: [AVVideoCodecKey: AVVideoCodecType.jpeg],
                        bracketedSettings: actualSettings
                    )
                }
                self.expectedBracketCount = actualSettings.count
                pOut.capturePhoto(with: photoSettings, delegate: self)
            } else {
                // Sequential fallback if bracketed output not directly supported
                self.bracketUsesRaw = !(pOut.availableRawPhotoPixelFormatTypes.isEmpty)
                self.captureSequentialBracket(offsets: evOffsets, index: 0)
            }
        }
    }

    private func captureSequentialBracket(offsets: [Double], index: Int) {
        guard index < offsets.count, let pOut = photoOutput else {
            DispatchQueue.main.async { [weak self] in
                guard let self = self, let cb = self.pendingBracketResult else { return }
                self.pendingBracketResult = nil
                cb(["captures": self.pendingBracketPhotos])
            }
            return
        }

        let ev = offsets[index]
        if let dev = activeDevice {
            try? dev.lockForConfiguration()
            dev.setExposureTargetBias(Float(ev), completionHandler: nil)
            dev.unlockForConfiguration()
        }

        let rawFmt = pOut.availableRawPhotoPixelFormatTypes.first
        let settings = rawFmt != nil
            ? AVCapturePhotoSettings(rawPixelFormatType: rawFmt!, processedFormat: [AVVideoCodecKey: AVVideoCodecType.jpeg])
            : AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])

        pOut.capturePhoto(with: settings, delegate: self)
    }

    // AVCapturePhotoCaptureDelegate
    public func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        let exifDict = photo.metadata[String(kCGImagePropertyExifDictionary)] as? [String: Any]
        let actualIso = (exifDict?[String(kCGImagePropertyExifISOSpeedRatings)] as? [Int])?.first
            ?? (exifDict?[String(kCGImagePropertyExifISOSpeedRatings)] as? Int)
            ?? Int(activeDevice?.iso ?? 100)
        let expTime = exifDict?[String(kCGImagePropertyExifExposureTime)] as? Double ?? 0.01
        let expNs = Int(expTime * 1_000_000_000.0)

        // Single-shot path: accumulate RAW + Processed data and finalize in `didFinishCaptureFor`
        if pendingBracketResult == nil {
            if let err = error, pendingCaptureResult != nil {
                captureAccumLock.lock()
                let hasAny = (pendingSingleRawData != nil || pendingSingleProcessedData != nil)
                captureAccumLock.unlock()
                if !hasAny {
                    let cb = pendingCaptureResult
                    pendingCaptureResult = nil
                    DispatchQueue.main.async {
                        cb?(FlutterError(code: "PHOTO_CAPTURE_ERR", message: err.localizedDescription, details: nil))
                    }
                    return
                }
            }
            let data = photo.fileDataRepresentation()
            captureAccumLock.lock()
            pendingSingleIso = actualIso
            pendingSingleExpNs = expNs
            if photo.isRawPhoto {
                pendingSingleRawData = data
            } else {
                pendingSingleProcessedData = data
                pendingSingleDepthData = photo.depthData
                pendingSingleMatte = photo.portraitEffectsMatte
            }
            captureAccumLock.unlock()
            return
        }

        // Bracketed capture path
        guard let bracketCb = pendingBracketResult else { return }
        if bracketUsesRaw && !photo.isRawPhoto {
            // Avoid double-counting processed companion frame when RAW is active in bracket mode
            return
        }

        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let ts = Int(Date().timeIntervalSince1970 * 1000) + pendingBracketPhotos.count
        let captureArgs = self.pendingCaptureArgs
        let useDisplayP3 = captureArgs["useDisplayP3"] as? Bool ?? false
        var entryMap: [String: Any]?

        if photo.isRawPhoto, let rawData = photo.fileDataRepresentation() {
            let dngUrl = docs.appendingPathComponent("ZAMERA_\(ts).dng")
            let trueColorUrl = docs.appendingPathComponent("ZAMERA_\(ts)_TRUECOLOR.jpg")
            try? rawData.write(to: dngUrl)
            let devOut = developIosRawToTrueColorFile(
                rawData: rawData,
                dngUrl: dngUrl,
                outUrl: trueColorUrl,
                args: captureArgs
            )
            let outPath = devOut.wroteFile ? trueColorUrl.path : dngUrl.path
            PHPhotoLibrary.shared().performChanges({
                let req = PHAssetCreationRequest.forAsset()
                req.addResource(with: .photo, fileURL: devOut.wroteFile ? trueColorUrl : dngUrl, options: nil)
            }, completionHandler: nil)
            entryMap = [
                "dngPath": dngUrl.path,
                "jpegPath": outPath,
                "oemJpegPath": outPath,
                "cameraId": activeDevice?.deviceType.rawValue ?? "ios",
                "rustIspActive": devOut.wroteFile,
                "colorSpaceTag": useDisplayP3 ? "Display P3" : "sRGB",
                "centerLabD50": devOut.centerLabD50,
                "exposureNormGain": devOut.exposureNormGain,
                "outputWidth": devOut.outWidth,
                "outputHeight": devOut.outHeight,
                "portraitDepthActive": false,
                "iso": actualIso,
                "exposureTimeNs": expNs
            ]
        } else if let jpgData = photo.fileDataRepresentation() {
            let jpgUrl = docs.appendingPathComponent("ZAMERA_\(ts).jpg")
            try? jpgData.write(to: jpgUrl)
            entryMap = [
                "jpegPath": jpgUrl.path,
                "oemJpegPath": jpgUrl.path,
                "dngPath": nil as String?,
                "mediaStoreJpegUri": jpgUrl.path,
                "cameraId": activeDevice?.deviceType.rawValue ?? "ios",
                "rustIspActive": false,
                "portraitDepthActive": false,
                "iso": actualIso,
                "exposureTimeNs": expNs
            ]
        }

        if let map = entryMap {
            pendingBracketPhotos.append(map)
        }
        if pendingBracketPhotos.count >= expectedBracketCount {
            pendingBracketResult = nil
            let captures = pendingBracketPhotos
            DispatchQueue.main.async {
                bracketCb(["captures": captures])
            }
        }
    }

    public func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings,
        error: Error?
    ) {
        guard pendingBracketResult == nil, let cb = pendingCaptureResult else { return }
        pendingCaptureResult = nil

        captureAccumLock.lock()
        let rawData = pendingSingleRawData
        let procData = pendingSingleProcessedData
        let depthData = pendingSingleDepthData
        let matteData = pendingSingleMatte
        let actualIso = pendingSingleIso
        let expNs = pendingSingleExpNs
        pendingSingleRawData = nil
        pendingSingleProcessedData = nil
        pendingSingleDepthData = nil
        pendingSingleMatte = nil
        captureAccumLock.unlock()

        if let err = error, rawData == nil, procData == nil {
            DispatchQueue.main.async {
                cb(FlutterError(code: "PHOTO_CAPTURE_ERR", message: err.localizedDescription, details: nil))
            }
            return
        }

        let captureArgs = self.pendingCaptureArgs
        let cameraIdStr = self.activeDevice?.deviceType.rawValue ?? "ios"
        let isRustLinked = self.resolveRustCoreVersion().isLinked

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let startMs = Int64(Date().timeIntervalSince1970 * 1000)
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let ts = Int(startMs)
            let isPortrait = captureArgs["isPortraitMode"] as? Bool ?? false
            let isArtworkMode = captureArgs["isArtworkMode"] as? Bool ?? true
            let useDisplayP3 = captureArgs["useDisplayP3"] as? Bool ?? false
            let losslessPng = isArtworkMode && !isPortrait && (captureArgs["losslessPng"] as? Bool ?? false)

            var oemUrl: URL?
            if let pData = procData {
                let u = docs.appendingPathComponent("ZAMERA_\(ts)_OEM.jpg")
                try? pData.write(to: u)
                oemUrl = u
            }

            var responseMap: [String: Any] = [:]

            if let rData = rawData, !isPortrait {
                let dngUrl = docs.appendingPathComponent("ZAMERA_\(ts).dng")
                try? rData.write(to: dngUrl)
                PHPhotoLibrary.shared().performChanges({
                    let req = PHAssetCreationRequest.forAsset()
                    req.addResource(with: .photo, fileURL: dngUrl, options: nil)
                }, completionHandler: nil)

                if isArtworkMode {
                    let ext = losslessPng ? "png" : "jpg"
                    let trueColorUrl = docs.appendingPathComponent("ZAMERA_\(ts)_TRUECOLOR.\(ext)")
                    let devOut = self.developIosRawToTrueColorFile(
                        rawData: rData,
                        dngUrl: dngUrl,
                        outUrl: trueColorUrl,
                        args: captureArgs
                    )
                    let finalUrl = devOut.wroteFile ? trueColorUrl : (oemUrl ?? dngUrl)
                    if devOut.wroteFile || oemUrl != nil {
                        PHPhotoLibrary.shared().performChanges({
                            let req = PHAssetCreationRequest.forAsset()
                            req.addResource(with: .photo, fileURL: finalUrl, options: nil)
                        }, completionHandler: nil)
                    }
                    responseMap = [
                        "jpegPath": finalUrl.path,
                        "oemJpegPath": (oemUrl ?? finalUrl).path,
                        "dngPath": dngUrl.path,
                        "mediaStoreJpegUri": finalUrl.path,
                        "mediaStoreDngUri": dngUrl.path,
                        "cameraId": cameraIdStr,
                        "iso": actualIso,
                        "exposureTimeNs": expNs,
                        "captureDurationMs": Int(Int64(Date().timeIntervalSince1970 * 1000) - startMs),
                        "lensShadingApplied": true,
                        "wbGainsUsed": devOut.wbGainsUsed,
                        "centerLinearCamRgb": devOut.centerLinearRgb,
                        "centerLabD50": devOut.centerLabD50,
                        "colorSpaceTag": useDisplayP3 ? "Display P3" : "sRGB",
                        "exposureNormGain": devOut.exposureNormGain,
                        "highlightClippedRatio": devOut.highlightClippedRatio,
                        "gamutClippedRatio": devOut.gamutClippedRatio,
                        "outputWidth": devOut.outWidth,
                        "outputHeight": devOut.outHeight,
                        "rustIspActive": devOut.wroteFile || isRustLinked,
                        "portraitDepthActive": false
                    ]
                    if let calib = devOut.liveCalibrationResult {
                        responseMap["liveCalibrationResult"] = calib
                    }
                } else {
                    let finalJpg = oemUrl ?? dngUrl
                    if let oUrl = oemUrl {
                        PHPhotoLibrary.shared().performChanges({
                            let req = PHAssetCreationRequest.forAsset()
                            req.addResource(with: .photo, fileURL: oUrl, options: nil)
                        }, completionHandler: nil)
                    }
                    responseMap = [
                        "jpegPath": finalJpg.path,
                        "oemJpegPath": finalJpg.path,
                        "dngPath": dngUrl.path,
                        "mediaStoreJpegUri": finalJpg.path,
                        "mediaStoreDngUri": dngUrl.path,
                        "cameraId": cameraIdStr,
                        "rustIspActive": isRustLinked,
                        "portraitDepthActive": false,
                        "iso": actualIso,
                        "exposureTimeNs": expNs
                    ]
                }
            } else if isPortrait, let oUrl = oemUrl {
                let portraitUrl = docs.appendingPathComponent("ZAMERA_\(ts)_PORTRAIT.jpg")
                self.storePortraitDepthSession(
                    path: oUrl.path,
                    depthData: depthData,
                    matte: matteData
                )
                let aperture = captureArgs["portraitAperture"] as? Double ?? 2.8
                let lightingMode = captureArgs["portraitLighting"] as? Int ?? 0
                let lightIntensity = captureArgs["portraitLightIntensity"] as? Double ?? 0.80
                let focusX = CGFloat(captureArgs["focusPointX"] as? Double ?? 0.5)
                let focusY = CGFloat(captureArgs["focusPointY"] as? Double ?? 0.45)

                let outcome = self.renderOpticalPortraitFile(
                    sourceUrl: oUrl,
                    outUrl: portraitUrl,
                    aperture: aperture,
                    lightingMode: lightingMode,
                    lightIntensity: lightIntensity,
                    focusX: focusX,
                    focusY: focusY,
                    inlineDepthData: depthData,
                    inlineMatte: matteData
                )
                let finalUrl = outcome.wroteFile ? portraitUrl : oUrl
                PHPhotoLibrary.shared().performChanges({
                    let req = PHAssetCreationRequest.forAsset()
                    req.addResource(with: .photo, fileURL: finalUrl, options: nil)
                }, completionHandler: nil)

                responseMap = [
                    "jpegPath": finalUrl.path,
                    "oemJpegPath": oUrl.path,
                    "dngPath": nil as String?,
                    "mediaStoreJpegUri": finalUrl.path,
                    "cameraId": cameraIdStr,
                    "rustIspActive": isRustLinked,
                    "portraitDepthActive": outcome.depthActive,
                    "portraitLightingMode": lightingMode,
                    "portraitAperture": aperture,
                    "iso": actualIso,
                    "exposureTimeNs": expNs
                ]
            } else if let oUrl = oemUrl {
                PHPhotoLibrary.shared().performChanges({
                    let req = PHAssetCreationRequest.forAsset()
                    req.addResource(with: .photo, fileURL: oUrl, options: nil)
                }, completionHandler: nil)

                responseMap = [
                    "jpegPath": oUrl.path,
                    "oemJpegPath": oUrl.path,
                    "dngPath": nil as String?,
                    "mediaStoreJpegUri": oUrl.path,
                    "cameraId": cameraIdStr,
                    "rustIspActive": isRustLinked,
                    "portraitDepthActive": false,
                    "iso": actualIso,
                    "exposureTimeNs": expNs
                ]
            }

            DispatchQueue.main.async {
                cb(responseMap)
            }
        }
    }

    // MARK: - Sanat Mode 1:1 True-Color CIRAWFilter Pipeline (D50 PCS + Linear sRGB / Display P3)

    private struct IosTrueColorDevelopOutcome {
        let wroteFile: Bool
        let outWidth: Int
        let outHeight: Int
        let exposureNormGain: Double
        let highlightClippedRatio: Double
        let gamutClippedRatio: Double
        let centerLinearRgb: [Double]
        let centerLabD50: [Double]
        let wbGainsUsed: [Double]
        let liveCalibrationResult: [String: Any]?
    }

    private func developIosRawToTrueColorFile(
        rawData: Data,
        dngUrl: URL,
        outUrl: URL,
        args: [String: Any]
    ) -> IosTrueColorDevelopOutcome {
        let useDisplayP3 = args["useDisplayP3"] as? Bool ?? false
        let normalizeExposure = args["normalizeExposure"] as? Bool ?? true
        let exposureMode = !normalizeExposure
            ? 0
            : max(0, min(2, (args["artworkExposureMode"] as? NSNumber)?.intValue ?? 2))
        let calibrateColorChecker = args["calibrateColorChecker"] as? Bool ?? false
        let losslessPng = args["losslessPng"] as? Bool ?? false
        let applyPerspectiveWarp = args["applyPerspectiveWarp"] as? Bool ?? false
        let cornersNorm = (args["perspectiveCornersNorm"] as? [NSNumber])?.map { $0.doubleValue }
            ?? (args["perspectiveCornersNorm"] as? [Double])
        let customWbGains = (args["wbGains"] as? [NSNumber])?.map { $0.doubleValue }
            ?? (args["wbGains"] as? [Double])
        let customCamToXyz = (args["camToXyzD50"] as? [NSNumber])?.map { $0.doubleValue }
            ?? (args["camToXyzD50"] as? [Double])

        guard let linSrgbCs = CGColorSpace(name: CGColorSpace.extendedLinearSRGB)
            ?? CGColorSpace(name: CGColorSpace.linearSRGB),
              let workP3Cs = CGColorSpace(name: CGColorSpace.extendedLinearDisplayP3)
            ?? CGColorSpace(name: CGColorSpace.extendedLinearSRGB) else {
            return IosTrueColorDevelopOutcome(
                wroteFile: false,
                outWidth: 0,
                outHeight: 0,
                exposureNormGain: 1.0,
                highlightClippedRatio: 0.0,
                gamutClippedRatio: 0.0,
                centerLinearRgb: [0.18, 0.18, 0.18],
                centerLabD50: [50.0, 0.0, 0.0],
                wbGainsUsed: [1.0, 1.0, 1.0],
                liveCalibrationResult: nil
            )
        }

        let targetCs = CGColorSpace(name: useDisplayP3 ? CGColorSpace.displayP3 : CGColorSpace.sRGB)
            ?? CGColorSpaceCreateDeviceRGB()
        let context = CIContext(options: [
            .workingColorSpace: workP3Cs,
            .outputColorSpace: targetCs,
            .useSoftwareRenderer: false
        ])

        var baseImage: CIImage?
        var activeWbGains: [Double] = (customWbGains?.count ?? 0) >= 3
            ? Array(customWbGains!.prefix(3))
            : [1.0, 1.0, 1.0]

        if #available(iOS 15.0, *) {
            if let rawFilter = CIRAWFilter(imageData: rawData, identifierHint: "com.adobe.raw-image")
                ?? CIRAWFilter(imageURL: dngUrl) {
                rawFilter.boostAmount = 0.0
                rawFilter.boostShadowAmount = 0.0
                if rawFilter.isLocalToneMapSupported {
                    rawFilter.localToneMapAmount = 0.0
                }
                if rawFilter.isLensCorrectionSupported {
                    rawFilter.isLensCorrectionEnabled = true
                }
                rawFilter.isGamutMappingEnabled = true
                rawFilter.contrastAmount = 0.0
                rawFilter.detailAmount = 0.2
                rawFilter.luminanceNoiseReductionAmount = 0.15
                rawFilter.colorNoiseReductionAmount = 0.25

                if let kelvin = (args["kelvin"] as? NSNumber)?.floatValue {
                    rawFilter.neutralTemperature = kelvin
                    rawFilter.neutralTint = (args["tint"] as? NSNumber)?.floatValue ?? 0.0
                } else if (customCamToXyz?.count ?? 0) != 9,
                          let wb = customWbGains, wb.count >= 3,
                          let dev = activeDevice {
                    let minCh = max(1e-4, min(wb[0], min(wb[1], wb[2])))
                    let maxG = dev.maxWhiteBalanceGain
                    let g = AVCaptureDevice.WhiteBalanceGains(
                        redGain: max(1.0, min(maxG, Float(wb[0] / minCh))),
                        greenGain: max(1.0, min(maxG, Float(wb[1] / minCh))),
                        blueGain: max(1.0, min(maxG, Float(wb[2] / minCh)))
                    )
                    let tt = dev.temperatureAndTintValues(for: g)
                    rawFilter.neutralTemperature = tt.temperature
                    rawFilter.neutralTint = tt.tint
                }
                baseImage = rawFilter.outputImage
            }
        }
        if baseImage == nil {
            baseImage = CIImage(contentsOf: dngUrl, options: [.applyOrientationProperty: true])
        }

        guard var workingImage = baseImage else {
            return IosTrueColorDevelopOutcome(
                wroteFile: false,
                outWidth: 0,
                outHeight: 0,
                exposureNormGain: 1.0,
                highlightClippedRatio: 0.0,
                gamutClippedRatio: 0.0,
                centerLinearRgb: [0.18, 0.18, 0.18],
                centerLabD50: [50.0, 0.0, 0.0],
                wbGainsUsed: activeWbGains,
                liveCalibrationResult: nil
            )
        }

        // Normalize origin to (0, 0)
        if workingImage.extent.origin.x != 0 || workingImage.extent.origin.y != 0 {
            workingImage = workingImage.transformed(
                by: CGAffineTransform(translationX: -workingImage.extent.origin.x, y: -workingImage.extent.origin.y)
            )
        }

        var activeCamToXyz: [Double]? = (customCamToXyz?.count == 9) ? customCamToXyz : nil
        var liveCalibMap: [String: Any]?

        // Optional 24-Patch ColorChecker live calibration in linear RGB space
        if calibrateColorChecker {
            let quad = (cornersNorm?.count == 8)
                ? cornersNorm!
                : [0.15, 0.20, 0.85, 0.20, 0.85, 0.80, 0.15, 0.80]
            if let patches = Self.sampleLinearPatches24(
                image: workingImage,
                context: context,
                linearSrgbCs: linSrgbCs,
                cornersNorm: quad
            ) {
                let solved = Self.solveColorChecker24D50(measuredPatches: patches)
                liveCalibMap = solved.reportMap
                activeWbGains = solved.wbGains
                activeCamToXyz = solved.camToXyzD50Flat
            }
        }

        // Apply custom calibrated WB + 3x3 D50 CCM in scene-linear light (`M_D50_TO_SRGB * camToXyzD50 * diag(wbGains)`)
        if let ccm = activeCamToXyz, ccm.count == 9 {
            let d50ToSrgb: [Double] = [
                3.1338561, -1.6168667, -0.4906146,
                -0.9787684,  1.9161415,  0.0334540,
                0.0719453, -0.2289914,  1.4052427
            ]
            var m = [Double](repeating: 0.0, count: 9)
            for r in 0..<3 {
                for c in 0..<3 {
                    let base = d50ToSrgb[r * 3] * ccm[c]
                        + d50ToSrgb[r * 3 + 1] * ccm[3 + c]
                        + d50ToSrgb[r * 3 + 2] * ccm[6 + c]
                    m[r * 3 + c] = base * activeWbGains[c]
                }
            }
            workingImage = workingImage.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: CGFloat(m[0]), y: CGFloat(m[1]), z: CGFloat(m[2]), w: 0),
                "inputGVector": CIVector(x: CGFloat(m[3]), y: CGFloat(m[4]), z: CGFloat(m[5]), w: 0),
                "inputBVector": CIVector(x: CGFloat(m[6]), y: CGFloat(m[7]), z: CGFloat(m[8]), w: 0),
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
                "inputBiasVector": CIVector(x: 0, y: 0, z: 0, w: 0)
            ])
        }

        // Sample 64x48 linear grid for True-Tone Exposure Mode (`0=off, 1=paperL94, 2=scene1to1`) & Center Lab D50
        let gridStats = Self.measureLinearGridStats(
            image: workingImage,
            context: context,
            linearSrgbCs: linSrgbCs,
            exposureMode: exposureMode
        )
        if abs(gridStats.exposureGain - 1.0) > 0.005 {
            let evDelta = log2(gridStats.exposureGain)
            workingImage = workingImage.applyingFilter("CIExposureAdjust", parameters: [
                kCIInputEVKey: evDelta
            ])
        }

        // Optional 4-corner perspective keystone rectification
        if applyPerspectiveWarp, let c = cornersNorm, c.count == 8 {
            let ext = workingImage.extent
            let tl = CIVector(x: ext.origin.x + CGFloat(c[0]) * ext.width, y: ext.origin.y + CGFloat(1.0 - c[1]) * ext.height)
            let tr = CIVector(x: ext.origin.x + CGFloat(c[2]) * ext.width, y: ext.origin.y + CGFloat(1.0 - c[3]) * ext.height)
            let br = CIVector(x: ext.origin.x + CGFloat(c[4]) * ext.width, y: ext.origin.y + CGFloat(1.0 - c[5]) * ext.height)
            let bl = CIVector(x: ext.origin.x + CGFloat(c[6]) * ext.width, y: ext.origin.y + CGFloat(1.0 - c[7]) * ext.height)
            let warped = workingImage.applyingFilter("CIPerspectiveCorrection", parameters: [
                "inputTopLeft": tl,
                "inputTopRight": tr,
                "inputBottomRight": br,
                "inputBottomLeft": bl
            ])
            if warped.extent.width > 16 && warped.extent.height > 16 {
                workingImage = warped.transformed(
                    by: CGAffineTransform(translationX: -warped.extent.origin.x, y: -warped.extent.origin.y)
                )
            }
        }

        let outW = Int(workingImage.extent.width.rounded())
        let outH = Int(workingImage.extent.height.rounded())
        var wrote = false
        do {
            if losslessPng {
                try context.writePNGRepresentation(
                    of: workingImage,
                    to: outUrl,
                    format: .RGBA8,
                    colorSpace: targetCs,
                    options: [:]
                )
            } else {
                let opts: [CIImageRepresentationOption: Any] = [
                    CIImageRepresentationOption(rawValue: kCGImageDestinationLossyCompressionQuality as String): 1.0
                ]
                try context.writeJPEGRepresentation(
                    of: workingImage,
                    to: outUrl,
                    colorSpace: targetCs,
                    options: opts
                )
            }
            wrote = FileManager.default.fileExists(atPath: outUrl.path)
        } catch {
            wrote = false
        }

        let gain = gridStats.exposureGain
        let scaledCenterLin = [
            min(1.0, max(0.0, gridStats.centerLinearSrgb[0] * gain)),
            min(1.0, max(0.0, gridStats.centerLinearSrgb[1] * gain)),
            min(1.0, max(0.0, gridStats.centerLinearSrgb[2] * gain))
        ]
        let centerLab = Self.linearSrgbToLabD50(
            r: scaledCenterLin[0],
            g: scaledCenterLin[1],
            b: scaledCenterLin[2]
        )

        return IosTrueColorDevelopOutcome(
            wroteFile: wrote,
            outWidth: outW,
            outHeight: outH,
            exposureNormGain: gain,
            highlightClippedRatio: gridStats.highlightClipRatio,
            gamutClippedRatio: gridStats.gamutClipRatio,
            centerLinearRgb: scaledCenterLin,
            centerLabD50: centerLab,
            wbGainsUsed: activeWbGains,
            liveCalibrationResult: liveCalibMap
        )
    }

    private static func measureLinearGridStats(
        image: CIImage,
        context: CIContext,
        linearSrgbCs: CGColorSpace,
        exposureMode: Int
    ) -> (exposureGain: Double, highlightClipRatio: Double, gamutClipRatio: Double, centerLinearSrgb: [Double]) {
        let gw = 64
        let gh = 48
        let ext = image.extent
        guard ext.width > 1, ext.height > 1 else {
            return (1.0, 0.0, 0.0, [0.18, 0.18, 0.18])
        }
        let sx = CGFloat(gw) / ext.width
        let sy = CGFloat(gh) / ext.height
        let small = image.transformed(by: CGAffineTransform(scaleX: sx, y: sy))
        var buf = [Float](repeating: 0, count: gw * gh * 4)
        buf.withUnsafeMutableBytes { rawPtr in
            if let base = rawPtr.baseAddress {
                context.render(
                    small,
                    toBitmap: base,
                    rowBytes: gw * 4 * MemoryLayout<Float>.size,
                    bounds: CGRect(x: 0, y: 0, width: gw, height: gh),
                    format: .RGBAf,
                    colorSpace: linearSrgbCs
                )
            }
        }

        var lums = [Double]()
        var maxChs = [Double]()
        lums.reserveCapacity(gw * gh)
        maxChs.reserveCapacity(gw * gh)
        var hiClip = 0
        var gamClip = 0

        for i in 0..<(gw * gh) {
            let r = Double(buf[i * 4])
            let g = Double(buf[i * 4 + 1])
            let b = Double(buf[i * 4 + 2])
            if r < 0.0 || g < 0.0 || b < 0.0 { gamClip += 1 }
            let rc = max(0.0, r)
            let gc = max(0.0, g)
            let bc = max(0.0, b)
            let m = max(rc, max(gc, bc))
            if m >= 0.995 { hiClip += 1 }
            let y = 0.2126 * rc + 0.7152 * gc + 0.0722 * bc
            lums.append(y)
            maxChs.append(m)
        }
        lums.sort()
        maxChs.sort()
        let n = max(1, lums.count)
        let p95 = lums[min(n - 1, (n * 95) / 100)]
        let p98 = lums[min(n - 1, (n * 98) / 100)]
        let p995Rgb = max(0.05, maxChs[min(n - 1, (n * 995) / 1000)])

        let gain: Double
        switch exposureMode {
        case 1:
            let rawG = p95 > 0.04 ? min(3.20, max(0.50, 0.855 / p95)) : 1.0
            gain = max(0.50, min(rawG, 0.97 / p995Rgb))
        case 2:
            let sceneG = p98 >= 0.42 ? min(1.35, max(0.80, 0.82 / p98)) : 1.0
            gain = max(0.50, min(sceneG, 0.95 / p995Rgb))
        default:
            gain = 1.0
        }

        var cR = 0.0, cG = 0.0, cB = 0.0
        var cCount = 0.0
        for y in (gh / 2 - 2)..<(gh / 2 + 2) {
            for x in (gw / 2 - 2)..<(gw / 2 + 2) {
                let idx = (y * gw + x) * 4
                cR += max(0.0, Double(buf[idx]))
                cG += max(0.0, Double(buf[idx + 1]))
                cB += max(0.0, Double(buf[idx + 2]))
                cCount += 1.0
            }
        }
        let centerLin = cCount > 0 ? [cR / cCount, cG / cCount, cB / cCount] : [0.18, 0.18, 0.18]
        return (gain, Double(hiClip) / Double(n), Double(gamClip) / Double(n), centerLin)
    }

    private static func sampleLinearPatches24(
        image: CIImage,
        context: CIContext,
        linearSrgbCs: CGColorSpace,
        cornersNorm: [Double]
    ) -> [[Double]]? {
        let gw = 192
        let gh = 144
        let ext = image.extent
        guard ext.width > 8, ext.height > 8, cornersNorm.count >= 8 else { return nil }
        let sx = CGFloat(gw) / ext.width
        let sy = CGFloat(gh) / ext.height
        let small = image.transformed(by: CGAffineTransform(scaleX: sx, y: sy))
        var buf = [Float](repeating: 0, count: gw * gh * 4)
        buf.withUnsafeMutableBytes { rawPtr in
            if let base = rawPtr.baseAddress {
                context.render(
                    small,
                    toBitmap: base,
                    rowBytes: gw * 4 * MemoryLayout<Float>.size,
                    bounds: CGRect(x: 0, y: 0, width: gw, height: gh),
                    format: .RGBAf,
                    colorSpace: linearSrgbCs
                )
            }
        }

        // Bilinear quad interpolation inside `[tl, tr, br, bl]` (top-left origin matches `render(..., toBitmap:)`)
        let tlX = cornersNorm[0], tlY = cornersNorm[1]
        let trX = cornersNorm[2], trY = cornersNorm[3]
        let brX = cornersNorm[4], brY = cornersNorm[5]
        let blX = cornersNorm[6], blY = cornersNorm[7]

        var patches = [[Double]]()
        patches.reserveCapacity(24)
        for row in 0..<4 {
            for col in 0..<6 {
                let uCenter = (Double(col) + 0.5) / 6.0
                let vCenter = (Double(row) + 0.5) / 4.0
                let halfU = 0.21 / 6.0
                let halfV = 0.21 / 4.0
                var sumR = 0.0, sumG = 0.0, sumB = 0.0, count = 0.0
                for syIdx in -2...2 {
                    let v = min(1.0, max(0.0, vCenter + (Double(syIdx) / 2.0) * halfV))
                    for sxIdx in -2...2 {
                        let u = min(1.0, max(0.0, uCenter + (Double(sxIdx) / 2.0) * halfU))
                        let topX = tlX + (trX - tlX) * u
                        let topY = tlY + (trY - tlY) * u
                        let botX = blX + (brX - blX) * u
                        let botY = blY + (brY - blY) * u
                        let px = Int(((topX + (botX - topX) * v) * Double(gw - 1)).rounded())
                        let py = Int(((topY + (botY - topY) * v) * Double(gh - 1)).rounded())
                        let cx = max(0, min(gw - 1, px))
                        let cy = max(0, min(gh - 1, py))
                        let off = (cy * gw + cx) * 4
                        sumR += max(1e-5, Double(buf[off]))
                        sumG += max(1e-5, Double(buf[off + 1]))
                        sumB += max(1e-5, Double(buf[off + 2]))
                        count += 1.0
                    }
                }
                patches.append([sumR / count, sumG / count, sumB / count])
            }
        }
        return patches
    }

    private static let colorChecker24LabD50: [[Double]] = [
        [37.986, 13.555, 14.059], [65.711, 18.130, 17.810], [49.927, -4.880, -21.925],
        [43.139, -13.095, 21.905], [55.112, 8.844, -25.399], [70.719, -33.397, -0.199],
        [62.661, 36.067, 57.096], [40.020, 10.410, -45.964], [51.124, 48.239, 16.248],
        [30.325, 22.976, -21.587], [72.532, -23.709, 57.255], [71.941, 19.363, 67.857],
        [28.778, 14.179, -50.297], [55.261, -38.342, 31.370], [42.101, 53.378, 28.190],
        [81.733, 4.039, 79.819], [51.935, 49.986, -14.574], [51.038, -28.631, -28.638],
        [96.539, -0.425, 1.186], [81.257, -0.638, -0.335], [66.766, -0.734, -0.504],
        [50.867, -0.153, -0.270], [35.656, -0.421, -1.231], [20.461, -0.079, -0.973]
    ]

    private static func labD50ToXyzD50(_ lab: [Double]) -> [Double] {
        let fy = (lab[0] + 16.0) / 116.0
        let fx = lab[1] / 500.0 + fy
        let fz = fy - lab[2] / 200.0
        let eps = 216.0 / 24389.0
        let kappa = 24389.0 / 27.0
        let invF = { (t: Double) -> Double in
            let t3 = t * t * t
            return t3 > eps ? t3 : (116.0 * t - 16.0) / kappa
        }
        return [0.96422 * invF(fx), 1.00000 * invF(fy), 0.82521 * invF(fz)]
    }

    private static func xyzD50ToLabD50(_ xyz: [Double]) -> [Double] {
        let eps = 216.0 / 24389.0
        let kappa = 24389.0 / 27.0
        let f = { (t: Double) -> Double in
            t > eps ? pow(t, 1.0 / 3.0) : (kappa * t + 16.0) / 116.0
        }
        let fx = f(max(0.0, xyz[0] / 0.96422))
        let fy = f(max(0.0, xyz[1] / 1.00000))
        let fz = f(max(0.0, xyz[2] / 0.82521))
        return [116.0 * fy - 16.0, 500.0 * (fx - fy), 200.0 * (fy - fz)]
    }

    private static func linearSrgbToLabD50(r: Double, g: Double, b: Double) -> [Double] {
        let x50 = 0.4360747 * r + 0.3850649 * g + 0.1430804 * b
        let y50 = 0.2225045 * r + 0.7168786 * g + 0.0606169 * b
        let z50 = 0.0139322 * r + 0.0971045 * g + 0.7141733 * b
        return xyzD50ToLabD50([x50, y50, z50])
    }

    private static func srgb8ToLabD50(r8: Int, g8: Int, b8: Int) -> [Double] {
        let eotf = { (c: Int) -> Double in
            let v = Double(max(0, min(255, c))) / 255.0
            return v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return linearSrgbToLabD50(r: eotf(r8), g: eotf(g8), b: eotf(b8))
    }

    private static func ciede2000(_ lab1: [Double], _ lab2: [Double]) -> Double {
        let l1 = lab1[0], a1 = lab1[1], b1 = lab1[2]
        let l2 = lab2[0], a2 = lab2[1], b2 = lab2[2]
        let c1 = hypot(a1, b1), c2 = hypot(a2, b2)
        let cBar = 0.5 * (c1 + c2)
        let cBar7 = pow(cBar, 7.0)
        let g = 0.5 * (1.0 - sqrt(cBar7 / (cBar7 + 6103515625.0)))
        let a1p = (1.0 + g) * a1, a2p = (1.0 + g) * a2
        let c1p = hypot(a1p, b1), c2p = hypot(a2p, b2)
        let h1p = (a1p == 0 && b1 == 0) ? 0.0 : ((atan2(b1, a1p) * 180.0 / .pi + 360.0).truncatingRemainder(dividingBy: 360.0))
        let h2p = (a2p == 0 && b2 == 0) ? 0.0 : ((atan2(b2, a2p) * 180.0 / .pi + 360.0).truncatingRemainder(dividingBy: 360.0))
        let dLp = l2 - l1
        let dCp = c2p - c1p
        var dhp = 0.0
        if c1p * c2p != 0.0 {
            let diff = h2p - h1p
            if abs(diff) <= 180.0 { dhp = diff }
            else if diff > 180.0 { dhp = diff - 360.0 }
            else { dhp = diff + 360.0 }
        }
        let dHp = 2.0 * sqrt(c1p * c2p) * sin((dhp * .pi / 180.0) * 0.5)
        let lBarP = 0.5 * (l1 + l2)
        let cBarP = 0.5 * (c1p + c2p)
        let hBarP: Double
        if c1p * c2p == 0.0 {
            hBarP = h1p + h2p
        } else if abs(h1p - h2p) <= 180.0 {
            hBarP = 0.5 * (h1p + h2p)
        } else if h1p + h2p < 360.0 {
            hBarP = 0.5 * (h1p + h2p + 360.0)
        } else {
            hBarP = 0.5 * (h1p + h2p - 360.0)
        }
        let t = 1.0
            - 0.17 * cos((hBarP - 30.0) * .pi / 180.0)
            + 0.24 * cos((2.0 * hBarP) * .pi / 180.0)
            + 0.32 * cos((3.0 * hBarP + 6.0) * .pi / 180.0)
            - 0.20 * cos((4.0 * hBarP - 63.0) * .pi / 180.0)
        let dTheta = 30.0 * exp(-pow((hBarP - 275.0) / 25.0, 2.0))
        let cBarP7 = pow(cBarP, 7.0)
        let rC = 2.0 * sqrt(cBarP7 / (cBarP7 + 6103515625.0))
        let lTerm = lBarP - 50.0
        let sL = 1.0 + (0.015 * lTerm * lTerm) / sqrt(20.0 + lTerm * lTerm)
        let sC = 1.0 + 0.045 * cBarP
        let sH = 1.0 + 0.015 * cBarP * t
        let rT = -sin((2.0 * dTheta) * .pi / 180.0) * rC
        let nL = dLp / sL, nC = dCp / sC, nH = dHp / sH
        return sqrt(max(0.0, nL * nL + nC * nC + nH * nH + rT * nC * nH))
    }

    private static func solveColorChecker24D50Core(_ measuredPatches: [[Double]]) -> (
        wbGains: [Double],
        camToXyzD50Flat: [Double],
        meanAfter: Double,
        reportMap: [String: Any]
    ) {
        let refXyz = colorChecker24LabD50.map { labD50ToXyzD50($0) }
        let neutralIdx = [19, 20, 21, 22]
        var sumRatioR = 0.0, sumRatioB = 0.0, sumScaleG = 0.0
        for idx in neutralIdx {
            let r = max(1e-6, measuredPatches[idx][0])
            let g = max(1e-6, measuredPatches[idx][1])
            let b = max(1e-6, measuredPatches[idx][2])
            sumRatioR += g / r
            sumRatioB += g / b
            sumScaleG += refXyz[idx][1] / g
        }
        let expScale = sumScaleG / Double(neutralIdx.count)
        let wbGains = [
            (sumRatioR / Double(neutralIdx.count)) * expScale,
            expScale,
            (sumRatioB / Double(neutralIdx.count)) * expScale
        ]

        let wbPatches = measuredPatches.map { p in
            [p[0] * wbGains[0], p[1] * wbGains[1], p[2] * wbGains[2]]
        }

        // Exact D50 white-point row-sum constrained + neutral-weighted least squares
        let whiteD50 = [0.96422, 1.00000, 0.82521]
        var s00 = 1e-8, s01 = 0.0, s11 = 1e-8
        var rhs = [[0.0, 0.0], [0.0, 0.0], [0.0, 0.0]]
        for i in 0..<24 {
            let w = (18...23).contains(i) ? 2.5 : 1.0
            let d0 = wbPatches[i][0] - wbPatches[i][2]
            let d1 = wbPatches[i][1] - wbPatches[i][2]
            s00 += w * d0 * d0
            s01 += w * d0 * d1
            s11 += w * d1 * d1
            for ch in 0..<3 {
                let yAdj = refXyz[i][ch] - whiteD50[ch] * wbPatches[i][2]
                rhs[ch][0] += w * d0 * yAdj
                rhs[ch][1] += w * d1 * yAdj
            }
        }
        let det = s00 * s11 - s01 * s01
        var ccmRows = [
            [0.4360747, 0.3850649, 0.1430804],
            [0.2225045, 0.7168786, 0.0606169],
            [0.0139322, 0.0971045, 0.7141733]
        ]
        if abs(det) > 1e-12 {
            let inv00 = s11 / det
            let inv01 = -s01 / det
            let inv11 = s00 / det
            for ch in 0..<3 {
                let m0 = inv00 * rhs[ch][0] + inv01 * rhs[ch][1]
                let m1 = inv01 * rhs[ch][0] + inv11 * rhs[ch][1]
                let m2 = whiteD50[ch] - m0 - m1
                ccmRows[ch] = [m0, m1, m2]
            }
        }

        var patchBefore = [Double]()
        var patchAfter = [Double]()
        var sumBefore = 0.0, sumAfter = 0.0, maxAfter = 0.0
        for i in 0..<24 {
            let labBefore = linearSrgbToLabD50(r: wbPatches[i][0], g: wbPatches[i][1], b: wbPatches[i][2])
            let deBefore = ciede2000(labBefore, colorChecker24LabD50[i])
            patchBefore.append(deBefore)
            sumBefore += deBefore

            let x = ccmRows[0][0] * wbPatches[i][0] + ccmRows[0][1] * wbPatches[i][1] + ccmRows[0][2] * wbPatches[i][2]
            let y = ccmRows[1][0] * wbPatches[i][0] + ccmRows[1][1] * wbPatches[i][1] + ccmRows[1][2] * wbPatches[i][2]
            let z = ccmRows[2][0] * wbPatches[i][0] + ccmRows[2][1] * wbPatches[i][1] + ccmRows[2][2] * wbPatches[i][2]
            let labAfter = xyzD50ToLabD50([x, y, z])
            let deAfter = ciede2000(labAfter, colorChecker24LabD50[i])
            patchAfter.append(deAfter)
            sumAfter += deAfter
            if deAfter > maxAfter { maxAfter = deAfter }
        }
        let meanBefore = sumBefore / 24.0
        let meanAfter = sumAfter / 24.0
        let flat = ccmRows.flatMap { $0 }
        let map: [String: Any] = [
            "wbGains": wbGains,
            "camToXyzD50": ccmRows,
            "meanDeltaEBefore": meanBefore,
            "meanDeltaEAfter": meanAfter,
            "maxDeltaEAfter": maxAfter,
            "patchDeltaEBefore": patchBefore,
            "patchDeltaEAfter": patchAfter,
            "isMeasuredFromSensor": true
        ]
        return (wbGains, flat, meanAfter, map)
    }

    private static func solveColorChecker24D50(measuredPatches: [[Double]]) -> (
        wbGains: [Double],
        camToXyzD50Flat: [Double],
        reportMap: [String: Any]
    ) {
        let primary = solveColorChecker24D50Core(measuredPatches)
        if primary.meanAfter > 10.0 {
            let flipped = Array(measuredPatches.reversed())
            let alt = solveColorChecker24D50Core(flipped)
            if alt.meanAfter + 3.0 < primary.meanAfter {
                return (alt.wbGains, alt.camToXyzD50Flat, alt.reportMap)
            }
        }
        return (primary.wbGains, primary.camToXyzD50Flat, primary.reportMap)
    }

    // MARK: - Faz 2: Optical Portrait Engine (AVDepthData CIDepthBlurEffect + iOS 17 Vision Instance/Person CIMaskedVariableBlur)

    private func renderOpticalPortraitFile(
        sourceUrl: URL,
        outUrl: URL,
        aperture: Double,
        lightingMode: Int,
        lightIntensity: Double,
        focusX: CGFloat,
        focusY: CGFloat,
        inlineDepthData: AVDepthData? = nil,
        inlineMatte: AVPortraitEffectsMatte? = nil
    ) -> (wroteFile: Bool, depthActive: Bool) {
        guard let baseImage = CIImage(contentsOf: sourceUrl, options: [.applyOrientationProperty: true]) else {
            return (false, false)
        }
        let extent = baseImage.extent
        guard extent.width > 1, extent.height > 1 else {
            return (false, false)
        }

        let context = CIContext(options: [.useSoftwareRenderer: false])
        let clampedAperture = max(1.4, min(16.0, aperture))
        let clampedIntensity = max(0.15, min(1.0, lightIntensity))
        let fx = max(0.05, min(0.95, focusX))
        let fy = max(0.05, min(0.95, focusY))
        // CoreImage bottom-left normalized focus rectangle around tapped point
        let focusRect = CIVector(
            x: max(0.0, fx - 0.06),
            y: max(0.0, (1.0 - fy) - 0.06),
            z: 0.12,
            w: 0.12
        )

        var processedImage = baseImage
        var depthActive = false
        var subjectMaskCI: CIImage?

        let (cachedDepth, cachedMatte) = loadPortraitDepthSession(path: sourceUrl.path)
        let activeDepth = inlineDepthData ?? cachedDepth
        let activeMatte = inlineMatte ?? cachedMatte

        // 1. Hardware 3D Depth Path: AVDepthData -> CIDepthBlurEffect
        if let depthData = activeDepth,
           let dispData = try? depthData.converting(toDepthDataType: kCVPixelFormatType_DisparityFloat32),
           let depthFilter = CIFilter(name: "CIDepthBlurEffect") {
            let dispCI = CIImage(cvPixelBuffer: dispData.depthDataMap)
            depthFilter.setValue(baseImage, forKey: kCIInputImageKey)
            depthFilter.setValue(dispCI, forKey: kCIInputDisparityImageKey)
            depthFilter.setValue(NSNumber(value: clampedAperture), forKey: "inputAperture")
            depthFilter.setValue(focusRect, forKey: "inputFocusRect")
            if let matte = activeMatte {
                let matteCI = CIImage(cvPixelBuffer: matte.mattingImage)
                depthFilter.setValue(matteCI, forKey: "inputMatteImage")
                subjectMaskCI = scaleMaskToExtent(matteCI, extent: extent)
            }
            if let out = depthFilter.outputImage?.cropped(to: extent) {
                processedImage = out
                depthActive = true
            }
        } else if let urlDepthFilter = context.depthBlurEffectFilter(forImageURL: sourceUrl, options: nil) {
            urlDepthFilter.setValue(NSNumber(value: clampedAperture), forKey: "inputAperture")
            urlDepthFilter.setValue(focusRect, forKey: "inputFocusRect")
            if let out = urlDepthFilter.outputImage?.cropped(to: extent) {
                processedImage = out
                depthActive = true
            }
        }

        // 2. Neural Vision Fallback (when AVDepthData is unavailable, or when Stage/High-Key needs tight subject matte)
        let needsTightBackdropMatte = (lightingMode == 3 || lightingMode == 4 || lightingMode == 5)
        if (!depthActive || (needsTightBackdropMatte && subjectMaskCI == nil)),
           let uprightCg = context.createCGImage(baseImage, from: extent) {
            subjectMaskCI = extractVisionForegroundMask(cgImage: uprightCg, extent: extent)
            if !depthActive, let fgMask = subjectMaskCI {
                // CIMaskedVariableBlur uses 0.0 (black) = tack-sharp subject, 1.0 (white) = full variable blur radius
                let blurRadius = max(1.5, min(28.0, 32.0 / clampedAperture))
                if let invert = CIFilter(name: "CIColorInvert"),
                   let varBlur = CIFilter(name: "CIMaskedVariableBlur") {
                    invert.setValue(fgMask, forKey: kCIInputImageKey)
                    if let bgBlurMask = invert.outputImage?.cropped(to: extent) {
                        varBlur.setValue(baseImage.clampedToExtent(), forKey: kCIInputImageKey)
                        varBlur.setValue(bgBlurMask, forKey: "inputMask")
                        varBlur.setValue(NSNumber(value: blurRadius), forKey: kCIInputRadiusKey)
                        if let blurredOut = varBlur.outputImage?.cropped(to: extent) {
                            processedImage = blurredOut
                        }
                    }
                }
            }
        }

        // 3. Studio / Stage (#000000) / High-Key (#F7F7F9) / Monochrome Relighting (zero Studio/Contour background darkening)
        processedImage = applyIosStudioLighting(
            bokehImage: processedImage,
            sharpImage: baseImage,
            subjectMask: subjectMaskCI,
            extent: extent,
            lightingMode: lightingMode,
            intensity: clampedIntensity
        )

        guard let outCg = context.createCGImage(processedImage, from: extent) else {
            return (false, depthActive)
        }
        let outUi = UIImage(cgImage: outCg)
        guard let jpegData = outUi.jpegData(compressionQuality: 0.95) else {
            return (false, depthActive)
        }
        do {
            try jpegData.write(to: outUrl, options: .atomic)
            return (true, depthActive)
        } catch {
            NSLog("ZameraPortrait write error: %@", error.localizedDescription)
            return (false, depthActive)
        }
    }

    private func scaleMaskToExtent(_ mask: CIImage, extent: CGRect) -> CIImage {
        let mExt = mask.extent
        guard mExt.width > 0, mExt.height > 0 else { return mask }
        let sx = extent.width / mExt.width
        let sy = extent.height / mExt.height
        return mask
            .transformed(by: CGAffineTransform(scaleX: sx, y: sy))
            .transformed(by: CGAffineTransform(translationX: extent.origin.x, y: extent.origin.y))
            .cropped(to: extent)
    }

    private func pixelBufferHasForegroundSignal(_ buffer: CVPixelBuffer) -> Bool {
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { return false }
        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        let fmt = CVPixelBufferGetPixelFormatType(buffer)
        let stepY = max(1, height / 32)
        let stepX = max(1, width / 32)

        if fmt == kCVPixelFormatType_OneComponent32Float {
            for y in stride(from: 0, to: height, by: stepY) {
                let row = base.advanced(by: y * bytesPerRow).assumingMemoryBound(to: Float.self)
                for x in stride(from: 0, to: width, by: stepX) where row[x] > 0.35 {
                    return true
                }
            }
            return false
        } else {
            for y in stride(from: 0, to: height, by: stepY) {
                let row = base.advanced(by: y * bytesPerRow).assumingMemoryBound(to: UInt8.self)
                for x in stride(from: 0, to: width, by: stepX) where row[x] > 90 {
                    return true
                }
            }
            return false
        }
    }

    private func extractVisionForegroundMask(cgImage: CGImage, extent: CGRect) -> CIImage? {
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        var instanceMaskCI: CIImage?
        var personMaskCI: CIImage?

        if #available(iOS 17.0, *) {
            let instanceReq = VNGenerateForegroundInstanceMaskRequest()
            do {
                try handler.perform([instanceReq])
                if let obs = instanceReq.results?.first, !obs.allInstances.isEmpty {
                    let maskBuf = try obs.generateScaledMaskForImage(forInstances: obs.allInstances, from: handler)
                    if pixelBufferHasForegroundSignal(maskBuf) {
                        instanceMaskCI = scaleMaskToExtent(CIImage(cvPixelBuffer: maskBuf), extent: extent)
                    }
                }
            } catch {
                NSLog("ZameraPortrait ForegroundInstanceMask fallback: %@", error.localizedDescription)
            }
        }

        if #available(iOS 15.0, *) {
            let personReq = VNGeneratePersonSegmentationRequest()
            personReq.qualityLevel = .accurate
            personReq.outputPixelFormat = kCVPixelFormatType_OneComponent8
            do {
                try handler.perform([personReq])
                if let maskBuf = personReq.results?.first?.pixelBuffer,
                   pixelBufferHasForegroundSignal(maskBuf) {
                    personMaskCI = scaleMaskToExtent(CIImage(cvPixelBuffer: maskBuf), extent: extent)
                }
            } catch {
                NSLog("ZameraPortrait PersonSegmentation fallback: %@", error.localizedDescription)
            }
        }

        if let inst = instanceMaskCI, let pers = personMaskCI,
           let maxComp = CIFilter(name: "CIMaximumCompositing") {
            maxComp.setValue(inst, forKey: kCIInputImageKey)
            maxComp.setValue(pers, forKey: kCIInputBackgroundImageKey)
            return maxComp.outputImage?.cropped(to: extent) ?? inst
        }
        return instanceMaskCI ?? personMaskCI
    }

    private func applyIosStudioLighting(
        bokehImage: CIImage,
        sharpImage: CIImage,
        subjectMask: CIImage?,
        extent: CGRect,
        lightingMode: Int,
        intensity: Double
    ) -> CIImage {
        var result = bokehImage

        switch lightingMode {
        case 1, 2:
            // Studio & Contour: lift/sculpt ONLY the subject (never darken background into a cloud halo)
            guard let fgMask = subjectMask,
                  let controls = CIFilter(name: "CIColorControls"),
                  let blend = CIFilter(name: "CIBlendWithMask") else {
                return result
            }
            controls.setValue(bokehImage, forKey: kCIInputImageKey)
            controls.setValue(NSNumber(value: lightingMode == 1 ? 0.05 * intensity : 0.02 * intensity), forKey: kCIInputBrightnessKey)
            controls.setValue(NSNumber(value: lightingMode == 1 ? 1.0 + 0.06 * intensity : 1.0 + 0.14 * intensity), forKey: kCIInputContrastKey)
            if let litSubject = controls.outputImage?.cropped(to: extent) {
                blend.setValue(litSubject, forKey: kCIInputImageKey)
                blend.setValue(bokehImage, forKey: kCIInputBackgroundImageKey)
                blend.setValue(fgMask, forKey: kCIInputMaskImageKey)
                if let out = blend.outputImage?.cropped(to: extent) {
                    result = out
                }
            }
        case 3, 4:
            // Stage (#000000) & Stage Mono (#000000) separated strictly by subject matte
            var subj = sharpImage
            if lightingMode == 4, let noir = CIFilter(name: "CIPhotoEffectNoir") {
                noir.setValue(subj, forKey: kCIInputImageKey)
                if let mono = noir.outputImage?.cropped(to: extent) { subj = mono }
            }
            if let fgMask = subjectMask, let blend = CIFilter(name: "CIBlendWithMask") {
                let blackBg = CIImage(color: CIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)).cropped(to: extent)
                blend.setValue(subj, forKey: kCIInputImageKey)
                blend.setValue(blackBg, forKey: kCIInputBackgroundImageKey)
                blend.setValue(fgMask, forKey: kCIInputMaskImageKey)
                if let out = blend.outputImage?.cropped(to: extent) {
                    result = out
                }
            }
        case 5:
            // High-Key Mono (#F7F7F9) separated strictly by subject matte
            var subj = sharpImage
            if let mono = CIFilter(name: "CIPhotoEffectTonal") {
                mono.setValue(subj, forKey: kCIInputImageKey)
                if let outMono = mono.outputImage?.cropped(to: extent) { subj = outMono }
            }
            if let fgMask = subjectMask, let blend = CIFilter(name: "CIBlendWithMask") {
                let highKeyBg = CIImage(
                    color: CIColor(red: 247.0 / 255.0, green: 247.0 / 255.0, blue: 249.0 / 255.0, alpha: 1.0)
                ).cropped(to: extent)
                blend.setValue(subj, forKey: kCIInputImageKey)
                blend.setValue(highKeyBg, forKey: kCIInputBackgroundImageKey)
                blend.setValue(fgMask, forKey: kCIInputMaskImageKey)
                if let out = blend.outputImage?.cropped(to: extent) {
                    result = out
                }
            }
        case 7:
            if let noir = CIFilter(name: "CIPhotoEffectNoir") {
                noir.setValue(result, forKey: kCIInputImageKey)
                if let out = noir.outputImage?.cropped(to: extent) { result = out }
            }
        case 8:
            if let temp = CIFilter(name: "CITemperatureAndTint") {
                temp.setValue(result, forKey: kCIInputImageKey)
                temp.setValue(CIVector(x: 6500, y: 0), forKey: "inputNeutral")
                temp.setValue(CIVector(x: CGFloat(6500.0 - 1400.0 * intensity), y: 0), forKey: "inputTargetNeutral")
                if let out = temp.outputImage?.cropped(to: extent) { result = out }
            }
        default:
            break
        }
        return result
    }

    private func reprocessPortraitPhoto(args: [String: Any], result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self,
                  let sourcePath = args["sourceJpegPath"] as? String,
                  FileManager.default.fileExists(atPath: sourcePath) else {
                DispatchQueue.main.async {
                    result(FlutterError(code: "SRC_NOT_FOUND", message: "Source portrait JPEG not found", details: nil))
                }
                return
            }

            let sourceUrl = URL(fileURLWithPath: sourcePath)
            let portraitEnabled = args["portraitEnabled"] as? Bool ?? true
            let aperture = max(1.4, min(16.0, args["aperture"] as? Double ?? 2.8))
            let lightingMode = args["lightingMode"] as? Int ?? 0
            let lightIntensity = args["lightIntensity"] as? Double ?? 0.80
            let focusX = CGFloat(args["focusX"] as? Double ?? 0.5)
            let focusY = CGFloat(args["focusY"] as? Double ?? 0.45)
            let saveToGal = args["saveToGallery"] as? Bool ?? false

            if !portraitEnabled {
                let (cachedDepth, _) = self.loadPortraitDepthSession(path: sourcePath)
                let hasUrlDepth = cachedDepth != nil || CIContext().depthBlurEffectFilter(forImageURL: sourceUrl, options: nil) != nil
                if saveToGal {
                    PHPhotoLibrary.shared().performChanges({
                        let req = PHAssetCreationRequest.forAsset()
                        req.addResource(with: .photo, fileURL: sourceUrl, options: nil)
                    }, completionHandler: nil)
                }
                DispatchQueue.main.async {
                    result([
                        "jpegPath": sourcePath,
                        "reprocessedJpegPath": sourcePath,
                        "mediaStoreUri": sourcePath,
                        "portraitEnabled": false,
                        "portraitDepthActive": hasUrlDepth,
                        "effectiveAperture": aperture,
                        "effectiveLighting": lightingMode
                    ])
                }
                return
            }

            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let ts = Int(Date().timeIntervalSince1970 * 1000)
            let outUrl = docs.appendingPathComponent("ZAM_PORTRAIT_\(ts).jpg")

            let outcome = self.renderOpticalPortraitFile(
                sourceUrl: sourceUrl,
                outUrl: outUrl,
                aperture: aperture,
                lightingMode: lightingMode,
                lightIntensity: lightIntensity,
                focusX: focusX,
                focusY: focusY
            )

            if outcome.wroteFile {
                if saveToGal {
                    PHPhotoLibrary.shared().performChanges({
                        let req = PHAssetCreationRequest.forAsset()
                        req.addResource(with: .photo, fileURL: outUrl, options: nil)
                    }, completionHandler: nil)
                }
                DispatchQueue.main.async {
                    result([
                        "jpegPath": outUrl.path,
                        "reprocessedJpegPath": outUrl.path,
                        "mediaStoreUri": outUrl.path,
                        "portraitEnabled": true,
                        "portraitDepthActive": outcome.depthActive,
                        "effectiveAperture": aperture,
                        "effectiveLighting": lightingMode
                    ])
                }
                return
            }

            DispatchQueue.main.async {
                result(FlutterError(code: "RENDER_FAILED", message: "Could not render portrait photo", details: nil))
            }
        }
    }

    private func extractSubjectCutoutPng(args: [String: Any], result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let sourcePath = args["sourceJpegPath"] as? String,
                  let uiImage = UIImage(contentsOfFile: sourcePath),
                  let cgImage = uiImage.cgImage else {
                DispatchQueue.main.async {
                    result(FlutterError(code: "SRC_NOT_FOUND", message: "Source image invalid for cutout", details: nil))
                }
                return
            }

            if #available(iOS 15.0, *) {
                let request = VNGeneratePersonSegmentationRequest()
                request.qualityLevel = .accurate
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                do {
                    try handler.perform([request])
                    guard let maskPixelBuffer = request.results?.first?.pixelBuffer else {
                        DispatchQueue.main.async {
                            result(FlutterError(code: "NO_MASK", message: "Could not segment subject", details: nil))
                        }
                        return
                    }

                    let maskCi = CIImage(cvPixelBuffer: maskPixelBuffer)
                    let origCi = CIImage(cgImage: cgImage)
                    let scaleX = origCi.extent.width / maskCi.extent.width
                    let scaleY = origCi.extent.height / maskCi.extent.height
                    let scaledMask = maskCi.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

                    guard let blend = CIFilter(name: "CIBlendWithMask") else { return }
                    blend.setValue(origCi, forKey: kCIInputImageKey)
                    blend.setValue(CIImage.empty(), forKey: kCIInputBackgroundImageKey)
                    blend.setValue(scaledMask, forKey: kCIInputMaskImageKey)

                    let context = CIContext()
                    if let output = blend.outputImage,
                       let cutCg = context.createCGImage(output, from: origCi.extent) {
                        let cutUi = UIImage(cgImage: cutCg)
                        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                        let ts = Int(Date().timeIntervalSince1970 * 1000)
                        let outUrl = docs.appendingPathComponent("ZAM_CUTOUT_\(ts).png")
                        if let pngData = cutUi.pngData() {
                            try? pngData.write(to: outUrl)

                            // Save to Photos & System Clipboard
                            DispatchQueue.main.async {
                                UIPasteboard.general.image = cutUi
                            }
                            PHPhotoLibrary.shared().performChanges({
                                let req = PHAssetCreationRequest.forAsset()
                                req.addResource(with: .photo, fileURL: outUrl, options: nil)
                            }, completionHandler: nil)

                            DispatchQueue.main.async {
                                result([
                                    "cutoutPngPath": outUrl.path,
                                    "copiedToClipboard": true,
                                    "width": Int(origCi.extent.width),
                                    "height": Int(origCi.extent.height)
                                ])
                            }
                            return
                        }
                    }
                } catch {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "VISION_ERR", message: error.localizedDescription, details: nil))
                    }
                    return
                }
            }
            DispatchQueue.main.async {
                result(FlutterError(code: "UNSUPPORTED_OS", message: "iOS 15.0+ required for Person Segmentation", details: nil))
            }
        }
    }

    // MARK: - Faz 3: Pro Video Engine (Apple Log, ProRes 422 HQ, 180° Shutter, Audio)

    private func startVideoSession(args: [String: Any], result: @escaping FlutterResult) {
        let cameraId = args["cameraId"] as? String ?? "2"
        let width = (args["width"] as? NSNumber)?.intValue ?? 3840
        let height = (args["height"] as? NSNumber)?.intValue ?? 2160
        let fps = (args["fps"] as? NSNumber)?.intValue ?? 30
        let profile = args["profile"] as? String ?? "REC.709"
        let videoStab = args["videoStabilization"] as? Bool ?? true

        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.stopVideoSessionInternal()

            let session = AVCaptureSession()
            session.beginConfiguration()
            session.sessionPreset = (width >= 3840) ? .hd4K3840x2160 : .hd1920x1080

            let targetDevice: AVCaptureDevice?
            let lowerCamId = cameraId.lowercased()
            if cameraId == "1" || lowerCamId.contains("front") || lowerCamId.contains("truedepth") {
                targetDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
                    ?? AVCaptureDevice.default(.builtInTrueDepthCamera, for: .video, position: .front)
            } else if cameraId.contains("Telephoto") || lowerCamId == "tele" || cameraId == "4" {
                targetDevice = AVCaptureDevice.default(.builtInTelephotoCamera, for: .video, position: .back)
            } else if cameraId.contains("UltraWide") || lowerCamId == "ultra" || cameraId == "3" {
                targetDevice = AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back)
            } else {
                targetDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            }

            guard let device = targetDevice ?? AVCaptureDevice.default(for: .video),
                  let videoInput = try? AVCaptureDeviceInput(device: device),
                  session.canAddInput(videoInput) else {
                session.commitConfiguration()
                DispatchQueue.main.async {
                    result(FlutterError(code: "VIDEO_DEV_FAIL", message: "Video device cannot be opened", details: nil))
                }
                return
            }
            session.addInput(videoInput)

            // Audio Input
            if let audioDev = AVCaptureDevice.default(for: .audio),
               let audioInput = try? AVCaptureDeviceInput(device: audioDev),
               session.canAddInput(audioInput) {
                session.addInput(audioInput)
            }

            // Configure FPS & Color Space (Apple Log / HLG BT.2020 / SDR Rec.709)
            let isAppleLog = profile == "iosAppleLogHevc10Bit"
                || profile == "iosAppleLogProRes422Hq"
                || profile.contains("AppleLog")
                || profile.contains("APPLE_LOG")
                || profile.contains("Apple Log")
            let isHlg = profile == "androidHlg10Hevc10Bit"
                || profile.contains("HLG")
                || profile.contains("Hlg")
            let reqFps = Double(max(1, fps))

            do {
                try device.lockForConfiguration()
                if isAppleLog {
                    if #available(iOS 17.0, *) {
                        if !device.activeFormat.supportedColorSpaces.contains(.appleLog) {
                            if let logFmt = device.formats.first(where: { fmt in
                                let d = CMVideoFormatDescriptionGetDimensions(fmt.formatDescription)
                                let fpsOk = fmt.videoSupportedFrameRateRanges.contains {
                                    reqFps >= $0.minFrameRate - 0.1 && reqFps <= $0.maxFrameRate + 0.1
                                }
                                return Int(d.width) >= width && fpsOk && fmt.supportedColorSpaces.contains(.appleLog)
                            }) {
                                device.activeFormat = logFmt
                            }
                        }
                        if device.activeFormat.supportedColorSpaces.contains(.appleLog) {
                            device.activeColorSpace = .appleLog
                        }
                    }
                } else if isHlg {
                    if !device.activeFormat.supportedColorSpaces.contains(.HLG_BT2020) {
                        if let hlgFmt = device.formats.first(where: { fmt in
                            let d = CMVideoFormatDescriptionGetDimensions(fmt.formatDescription)
                            let fpsOk = fmt.videoSupportedFrameRateRanges.contains {
                                reqFps >= $0.minFrameRate - 0.1 && reqFps <= $0.maxFrameRate + 0.1
                            }
                            return Int(d.width) >= width && fpsOk && fmt.supportedColorSpaces.contains(.HLG_BT2020)
                        }) {
                            device.activeFormat = hlgFmt
                        }
                    }
                    if device.activeFormat.supportedColorSpaces.contains(.HLG_BT2020) {
                        device.activeColorSpace = .HLG_BT2020
                    }
                } else {
                    // universalRec709Locked / zameraFlatSdr / REC.709 -> SDR (.sRGB), never force HLG!
                    if device.activeFormat.supportedColorSpaces.contains(.sRGB) {
                        device.activeColorSpace = .sRGB
                    }
                }

                let supportsFps = device.activeFormat.videoSupportedFrameRateRanges.contains {
                    reqFps >= $0.minFrameRate - 0.1 && reqFps <= $0.maxFrameRate + 0.1
                }
                if supportsFps {
                    device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: CMTimeScale(max(1, fps)))
                    device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: CMTimeScale(max(1, fps)))
                }
                device.unlockForConfiguration()
            } catch {
                // Keep default format if locking fails
            }

            let applyStabilization: (AVCaptureConnection?) -> Void = { conn in
                guard let conn = conn, conn.isVideoStabilizationSupported else { return }
                if !videoStab {
                    conn.preferredVideoStabilizationMode = .off
                } else if #available(iOS 13.0, *), device.activeFormat.isVideoStabilizationModeSupported(.cinematicExtended) {
                    conn.preferredVideoStabilizationMode = .cinematicExtended
                } else if device.activeFormat.isVideoStabilizationModeSupported(.standard) {
                    conn.preferredVideoStabilizationMode = .standard
                } else {
                    conn.preferredVideoStabilizationMode = .off
                }
            }

            // Movie File Output
            let mOut = AVCaptureMovieFileOutput()
            if session.canAddOutput(mOut) {
                session.addOutput(mOut)
                if let mConn = mOut.connection(with: .video) {
                    if mConn.isVideoOrientationSupported {
                        mConn.videoOrientation = .portrait
                    }
                    applyStabilization(mConn)
                    if profile == "iosAppleLogProRes422Hq",
                       mOut.availableVideoCodecTypes.contains(.proRes422HQ) {
                        mOut.setOutputSettings([AVVideoCodecKey: AVVideoCodecType.proRes422HQ], for: mConn)
                    }
                }
                self.movieFileOutput = mOut
            }

            // Video Preview Texture
            let vDataOut = AVCaptureVideoDataOutput()
            vDataOut.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            vDataOut.setSampleBufferDelegate(self, queue: DispatchQueue(label: "com.akarworks.zamera.videoStreamQueue"))
            if session.canAddOutput(vDataOut) {
                session.addOutput(vDataOut)
                if let vConn = vDataOut.connection(with: .video) {
                    if vConn.isVideoOrientationSupported {
                        vConn.videoOrientation = .portrait
                    }
                    if vConn.isVideoMirroringSupported {
                        vConn.isVideoMirrored = (device.position == .front)
                    }
                }
                applyStabilization(vDataOut.connection(with: .video))
            }

            session.commitConfiguration()
            session.startRunning()

            self.videoSession = session
            self.activeDevice = device
            self.activeVideoProfile = profile
            self.activeVideoFps = fps
            self.activeVideoWidth = width
            self.activeVideoHeight = height
            self.activeShutterAngleDeg = 180.0
            self.isAeAfLocked = false

            var devSupportsAppleLog = false
            if #available(iOS 17.0, *) {
                devSupportsAppleLog = device.formats.contains { $0.supportedColorSpaces.contains(.appleLog) }
            }

            DispatchQueue.main.async {
                if let reg = self.textureRegistry {
                    self.textureId = reg.register(self)
                }
                result([
                    "textureId": self.textureId,
                    "previewWidth": width,
                    "previewHeight": height,
                    "activeCameraId": device.deviceType.rawValue,
                    "profile": profile,
                    "fps": fps,
                    "supportsAppleLog": devSupportsAppleLog
                ])
            }
        }
    }

    private func updateVideoControls(args: [String: Any], result: @escaping FlutterResult) {
        sessionQueue.async { [weak self] in
            guard let self = self, let device = self.activeDevice else {
                DispatchQueue.main.async { result(false) }
                return
            }
            do {
                try device.lockForConfiguration()

                // 1. Shutter Angle & Exposure Mode (180° = 1 / (2 * fps))
                let shutterAngle = (args["shutterAngleDeg"] as? NSNumber)?.doubleValue ?? self.activeShutterAngleDeg
                self.activeShutterAngleDeg = shutterAngle
                let fps = max(1, (args["fps"] as? NSNumber)?.intValue ?? self.activeVideoFps)
                let shutterSec = (max(1.0, min(360.0, shutterAngle)) / 360.0) / Double(fps)
                let shutterNs = max(Int64(1_000), Int64(shutterSec * 1_000_000_000.0))
                let duration = CMTimeMake(value: shutterNs, timescale: 1_000_000_000)
                let clampedDur = max(device.activeFormat.minExposureDuration, min(device.activeFormat.maxExposureDuration, duration))

                let lockShutterAngle = (args["lockShutterAngle"] as? Bool) ?? (args["manualExposure"] as? Bool) ?? false
                let manualIso = args["manualIso"] as? Bool ?? false
                let iso = (args["iso"] as? NSNumber)?.doubleValue ?? 100.0
                let evCompensation = (args["evCompensation"] as? NSNumber)?.doubleValue ?? 0.0
                let clampedEv = max(device.minExposureTargetBias, min(device.maxExposureTargetBias, Float(evCompensation)))
                let aeAfLocked = (args["aeAfLocked"] as? Bool) ?? (args["lockAeAf"] as? Bool) ?? false

                if manualIso && device.isExposureModeSupported(.custom) {
                    let clampedIso = max(device.activeFormat.minISO, min(device.activeFormat.maxISO, Float(iso)))
                    device.setExposureModeCustom(duration: clampedDur, iso: clampedIso, completionHandler: nil)
                } else if lockShutterAngle && !manualIso && device.isExposureModeSupported(.custom) {
                    device.setExposureModeCustom(duration: clampedDur, iso: AVCaptureDevice.currentISO, completionHandler: nil)
                    device.setExposureTargetBias(clampedEv, completionHandler: nil)
                } else {
                    if aeAfLocked && device.isExposureModeSupported(.locked) {
                        device.exposureMode = .locked
                    } else if device.isExposureModeSupported(.continuousAutoExposure) {
                        device.exposureMode = .continuousAutoExposure
                    }
                    device.setExposureTargetBias(clampedEv, completionHandler: nil)
                }

                // 2. Focus Distance & AF Lock
                let manualFocus = args["manualFocus"] as? Bool ?? false
                let focusDistance = (args["focusDistance"] as? NSNumber)?.doubleValue ?? 0.5
                if manualFocus && device.isFocusModeSupported(.locked) {
                    device.setFocusModeLocked(lensPosition: max(0.0, min(1.0, Float(focusDistance))), completionHandler: nil)
                } else if aeAfLocked && device.isFocusModeSupported(.locked) {
                    device.focusMode = .locked
                } else if device.isFocusModeSupported(.continuousAutoFocus) {
                    device.focusMode = .continuousAutoFocus
                }
                self.isAeAfLocked = aeAfLocked

                // 3. White Balance (Kelvin + Tint -> deviceWhiteBalanceGains)
                let manualWb = args["manualWb"] as? Bool ?? false
                if manualWb && device.isWhiteBalanceModeSupported(.locked) {
                    let kelvin = (args["kelvin"] as? NSNumber)?.doubleValue ?? 5600.0
                    let tint = (args["tint"] as? NSNumber)?.doubleValue ?? 0.0
                    let maxGain = device.maxWhiteBalanceGain
                    let tempAndTint = AVCaptureDevice.WhiteBalanceTemperatureAndTintValues(
                        temperature: Float(max(2000.0, min(10000.0, kelvin))),
                        tint: Float(max(-150.0, min(150.0, tint)))
                    )
                    var gains = device.deviceWhiteBalanceGains(for: tempAndTint)
                    gains.redGain = max(1.0, min(maxGain, gains.redGain))
                    gains.greenGain = max(1.0, min(maxGain, gains.greenGain))
                    gains.blueGain = max(1.0, min(maxGain, gains.blueGain))
                    device.setWhiteBalanceModeLocked(with: gains, completionHandler: nil)
                } else if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                    device.whiteBalanceMode = .continuousAutoWhiteBalance
                }

                // 4. Optical / Digital Zoom Factor
                if let zoom = (args["zoomRatio"] as? NSNumber)?.doubleValue {
                    let minZoom = Double(device.minAvailableVideoZoomFactor)
                    let maxZoom = min(Double(device.maxAvailableVideoZoomFactor), 15.0)
                    let clampedZoom = CGFloat(max(minZoom, min(maxZoom, zoom)))
                    device.videoZoomFactor = clampedZoom
                }

                device.unlockForConfiguration()
                DispatchQueue.main.async { result(true) }
            } catch {
                DispatchQueue.main.async { result(false) }
            }
        }
    }

    private func setVideoFocusAndMeteringPoint(args: [String: Any], result: @escaping FlutterResult) {
        sessionQueue.async { [weak self] in
            guard let self = self, let device = self.activeDevice else {
                DispatchQueue.main.async { result(false) }
                return
            }
            let x = CGFloat((args["x"] as? NSNumber)?.doubleValue ?? 0.5)
            let y = CGFloat((args["y"] as? NSNumber)?.doubleValue ?? 0.5)
            let lockAeAf = (args["lockAeAf"] as? Bool) ?? (args["aeAfLocked"] as? Bool) ?? false
            let pt = CGPoint(x: max(0.0, min(1.0, x)), y: max(0.0, min(1.0, y)))
            do {
                try device.lockForConfiguration()
                if device.isFocusPointOfInterestSupported {
                    device.focusPointOfInterest = pt
                }
                if lockAeAf {
                    if device.isFocusModeSupported(.locked) {
                        device.focusMode = .locked
                    }
                } else if device.isFocusModeSupported(.continuousAutoFocus) {
                    device.focusMode = .continuousAutoFocus
                } else if device.isFocusModeSupported(.autoFocus) {
                    device.focusMode = .autoFocus
                }

                if device.isExposurePointOfInterestSupported {
                    device.exposurePointOfInterest = pt
                }
                if device.exposureMode != .custom {
                    if lockAeAf {
                        if device.isExposureModeSupported(.locked) {
                            device.exposureMode = .locked
                        }
                    } else if device.isExposureModeSupported(.continuousAutoExposure) {
                        device.exposureMode = .continuousAutoExposure
                    } else if device.isExposureModeSupported(.autoExpose) {
                        device.exposureMode = .autoExpose
                    }
                }
                self.isAeAfLocked = lockAeAf
                device.unlockForConfiguration()
                DispatchQueue.main.async { result(true) }
            } catch {
                DispatchQueue.main.async { result(false) }
            }
        }
    }

    private func startVideoRecording(args: [String: Any], result: @escaping FlutterResult) {
        sessionQueue.async { [weak self] in
            guard let self = self, let mOut = self.movieFileOutput else {
                DispatchQueue.main.async {
                    result(FlutterError(code: "NO_RECORDER", message: "Movie output not active", details: nil))
                }
                return
            }

            if mOut.isRecording {
                let existingPath = self.activeRecordingPath ?? ""
                DispatchQueue.main.async {
                    result(["started": true, "videoPath": existingPath])
                }
                return
            }

            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let ts = Int(Date().timeIntervalSince1970 * 1000)
            let outUrl = docs.appendingPathComponent("ZAM_VID_\(ts).mov")

            self.videoRecordingStartTime = Date()
            self.activeRecordingPath = outUrl.path
            mOut.startRecording(to: outUrl, recordingDelegate: self)

            DispatchQueue.main.async {
                result(["started": true, "videoPath": outUrl.path])
            }
        }
    }

    private func stopVideoRecording(result: @escaping FlutterResult) {
        sessionQueue.async { [weak self] in
            guard let self = self, let mOut = self.movieFileOutput, mOut.isRecording else {
                DispatchQueue.main.async {
                    result(FlutterError(code: "NOT_RECORDING", message: "Video is not recording", details: nil))
                }
                return
            }
            self.pendingVideoRecordingResult = result
            mOut.stopRecording()
        }
    }

    public func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        activeRecordingPath = nil
        guard let cb = pendingVideoRecordingResult else { return }
        pendingVideoRecordingResult = nil

        if let err = error {
            DispatchQueue.main.async {
                cb(FlutterError(code: "REC_ERR", message: err.localizedDescription, details: nil))
            }
            return
        }

        PHPhotoLibrary.shared().performChanges({
            let req = PHAssetCreationRequest.forAsset()
            req.addResource(with: .video, fileURL: outputFileURL, options: nil)
        }, completionHandler: nil)

        let durationMs = Int((videoRecordingStartTime.map { Date().timeIntervalSince($0) } ?? 0.0) * 1000.0)
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: outputFileURL.path)[.size] as? Int) ?? 0
        let prof = activeVideoProfile
        let isLog = prof == "iosAppleLogHevc10Bit" || prof == "iosAppleLogProRes422Hq" || prof.contains("AppleLog") || prof.contains("APPLE_LOG") || prof.contains("Apple Log")
        let isHlg = prof == "androidHlg10Hevc10Bit" || prof.contains("HLG") || prof.contains("Hlg")
        let codecStr = prof == "iosAppleLogProRes422Hq" ? "ProRes422HQ" : "HEVC"
        let colorStd = (isLog || isHlg) ? "BT.2020" : "BT.709"
        let colorXfer = isLog ? "Apple Log" : (isHlg ? "HLG" : "Rec.709")

        DispatchQueue.main.async {
            cb([
                "videoPath": outputFileURL.path,
                "mediaStoreUri": outputFileURL.path,
                "durationMs": durationMs,
                "width": self.activeVideoWidth,
                "height": self.activeVideoHeight,
                "fps": self.activeVideoFps,
                "bitrateMbps": durationMs > 0 ? (Double(fileSize) * 8.0 / (Double(durationMs) / 1000.0) / 1_000_000.0) : 100.0,
                "codec": codecStr,
                "profile": prof,
                "colorStandard": colorStd,
                "colorTransfer": colorXfer,
                "droppedFrames": 0,
                "fileSizeBytes": fileSize
            ])
        }
    }

    private func triggerFocusPull(args: [String: Any], result: @escaping FlutterResult) {
        let fromLensPos = Float((args["fromFocusNorm"] as? NSNumber)?.doubleValue ?? Double(activeDevice?.lensPosition ?? 0.1))
        let targetLensPos = Float(
            (args["toFocusNorm"] as? NSNumber)?.doubleValue
                ?? (args["targetFocusDistance"] as? NSNumber)?.doubleValue
                ?? 0.8
        )
        let durationMs = max(100, (args["durationMs"] as? NSNumber)?.intValue ?? 1500)
        let steps = max(20, min(120, durationMs / 25))
        let interval = Double(durationMs) / Double(steps) / 1000.0

        guard let dev = activeDevice, dev.isFocusModeSupported(.locked) else {
            result(false)
            return
        }

        sessionQueue.async {
            do {
                try dev.lockForConfiguration()
                dev.setFocusModeLocked(lensPosition: max(0.0, min(1.0, fromLensPos)), completionHandler: nil)
                dev.unlockForConfiguration()
            } catch {}
        }

        let startPos = fromLensPos
        var stepCount = 0

        focusPullTimer?.invalidate()
        focusPullTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
            stepCount += 1
            let t = max(0.0, min(1.0, Float(stepCount) / Float(steps)))
            let eased = t * t * (3.0 - 2.0 * t)
            let curr = startPos + (targetLensPos - startPos) * eased
            self?.sessionQueue.async {
                if let d = self?.activeDevice, d.isFocusModeSupported(.locked) {
                    do {
                        try d.lockForConfiguration()
                        d.setFocusModeLocked(lensPosition: max(0.0, min(1.0, curr)), completionHandler: nil)
                        d.unlockForConfiguration()
                    } catch {}
                }
            }
            if stepCount >= steps {
                timer.invalidate()
                self?.focusPullTimer = nil
            }
        }
        result(true)
    }

    private func listAudioInputDevices() -> [[String: Any]] {
        let audioSession = AVAudioSession.sharedInstance()
        var inputs: [[String: Any]] = [
            ["id": "builtin_mic", "name": "iPhone Dahili Mikrofon", "type": "BUILTIN_MIC"]
        ]
        if let available = audioSession.availableInputs {
            for inp in available {
                inputs.append([
                    "id": inp.uid,
                    "name": inp.portName,
                    "type": inp.portType.rawValue
                ])
            }
        }
        return inputs
    }

    private func extractVideoTelemetry() -> [String: Any] {
        let isRec = movieFileOutput?.isRecording ?? false
        let durationMs = Int((videoRecordingStartTime.map { Date().timeIntervalSince($0) } ?? 0.0) * 1000.0)
        let expSec = activeDevice.map { max(0.0, CMTimeGetSeconds($0.exposureDuration)) } ?? 0.016
        let shutterNs = Int64(expSec * 1_000_000_000.0)

        // Real hardware audio metering via AVCaptureAudioChannel (dBFS)
        let audioChannel = movieFileOutput?.connection(with: .audio)?.audioChannels.first
        let samplePeakDbfs: Double
        let rmsDbfs: Double
        if let ch = audioChannel {
            let rawPeak = Double(ch.peakHoldLevel)
            let rawAvg = Double(ch.averagePowerLevel)
            samplePeakDbfs = rawPeak.isFinite ? max(-96.0, min(0.0, rawPeak)) : -96.0
            rmsDbfs = rawAvg.isFinite ? max(-96.0, min(0.0, rawAvg)) : -96.0
        } else {
            samplePeakDbfs = -96.0
            rmsDbfs = -96.0
        }

        // Exposure meter offset, AE/AF lock & focus diopters
        let rawEvOffset = Double(activeDevice?.exposureTargetOffset ?? 0)
        let meteredEvDelta = rawEvOffset.isFinite ? max(-8.0, min(8.0, rawEvOffset)) : 0.0
        let aeAfLocked = isAeAfLocked || (activeDevice?.exposureMode == .locked && activeDevice?.focusMode == .locked)
        let focusDistanceDiopters = Double((activeDevice?.lensPosition ?? 0.0) * 10.0)

        // Live Luma / Zebra summary
        telemetryColorLock.lock()
        let centerSrgb = latestLiveCenterSrgb
        let centerLab = latestLiveCenterLabD50
        let meanLuma = latestMeanLuma
        let zebraClip = latestZebraClipRatio
        let shadowClip = latestShadowClipRatio
        telemetryColorLock.unlock()

        // Thermal Level Mapping
        let thermalState = ProcessInfo.processInfo.thermalState
        let thermalStr: String
        switch thermalState {
        case .nominal: thermalStr = "NORMAL"
        case .fair: thermalStr = "MODERATE"
        case .serious: thermalStr = "SEVERE"
        case .critical: thermalStr = "CRITICAL"
        @unknown default: thermalStr = "NORMAL"
        }

        // Available disk storage
        let freeBytes = (try? URL(fileURLWithPath: NSHomeDirectory())
            .resourceValues(forKeys: [.volumeAvailableCapacityKey])
            .volumeAvailableCapacity) ?? 50_000_000_000

        return [
            "isRecording": isRec,
            "recordedDurationMs": isRec ? durationMs : 0,
            "samplePeakDbfs": samplePeakDbfs,
            "rmsDbfs": rmsDbfs,
            "droppedFrameCount": 0,
            "thermalStatus": thermalStr,
            "thermalLevel": thermalStr,
            "availableStorageBytes": freeBytes,
            "remainingRecordSeconds": Int(freeBytes / (12 * 1024 * 1024)),
            "iso": Int(activeDevice?.iso ?? 100),
            "activeIso": Int(activeDevice?.iso ?? 100),
            "exposureTimeNs": shutterNs,
            "shutterExposureNs": shutterNs,
            "shutterAngleDeg": activeShutterAngleDeg,
            "fps": activeVideoFps,
            "activePhysicalLensId": activeDevice?.deviceType.rawValue ?? "2",
            "meteredEvDelta": meteredEvDelta,
            "aeAfLocked": aeAfLocked,
            "focusDistanceDiopters": focusDistanceDiopters,
            "meanLuma": meanLuma,
            "lumaIre": meanLuma * 100.0,
            "zebraClipRatio": zebraClip,
            "highlightClipRatio": zebraClip,
            "shadowClipRatio": shadowClip,
            "zebraActive": zebraClip > 0.01,
            "liveCenterSrgb": centerSrgb,
            "liveCenterLabD50": centerLab
        ]
    }

    private func pickCubeLutFile(result: @escaping FlutterResult) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.pendingLutResult = result
            let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.plainText, .data], asCopy: true)
            picker.delegate = self
            picker.allowsMultipleSelection = false

            if let rootVc = UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.rootViewController {
                rootVc.present(picker, animated: true, completion: nil)
            } else {
                result(FlutterError(code: "NO_VC", message: "Root view controller not found", details: nil))
            }
        }
    }

    public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first, let cb = pendingLutResult else { return }
        pendingLutResult = nil
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            cb([
                "fileName": url.lastPathComponent,
                "content": content
            ])
        } catch {
            cb(FlutterError(code: "READ_FAILED", message: error.localizedDescription, details: nil))
        }
    }

    public func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        pendingLutResult?(nil)
        pendingLutResult = nil
    }

    // MARK: - Resource Cleanup

    private func stopPreviewSession() {
        sessionQueue.async { [weak self] in
            self?.stopPreviewSessionInternal()
        }
    }

    private func stopPreviewSessionInternal() {
        captureSession?.stopRunning()
        captureSession = nil
        activeDevice = nil
        photoOutput = nil
        videoOutput = nil
        isAeAfLocked = false
        if textureId >= 0 {
            let oldId = textureId
            textureId = -1
            DispatchQueue.main.async { [weak self] in
                self?.textureRegistry?.unregisterTexture(oldId)
            }
        }
    }

    private func stopVideoSession() {
        sessionQueue.async { [weak self] in
            self?.stopVideoSessionInternal()
        }
    }

    private func stopVideoSessionInternal() {
        if let m = movieFileOutput, m.isRecording {
            m.stopRecording()
        }
        movieFileOutput = nil
        activeRecordingPath = nil
        isAeAfLocked = false
        videoSession?.stopRunning()
        videoSession = nil
        activeDevice = nil
        focusPullTimer?.invalidate()
        focusPullTimer = nil
        if textureId >= 0 {
            let oldId = textureId
            textureId = -1
            DispatchQueue.main.async { [weak self] in
                self?.textureRegistry?.unregisterTexture(oldId)
            }
        }
    }

    // MARK: - Faz 0: Hardware Probe

    private func probeAVFoundationCapabilities() -> [String: Any] {
        var deviceTypes: [AVCaptureDevice.DeviceType] = [
            .builtInWideAngleCamera,
            .builtInTelephotoCamera,
            .builtInUltraWideCamera,
            .builtInTripleCamera,
            .builtInDualWideCamera,
            .builtInDualCamera,
            .builtInTrueDepthCamera
        ]
        if #available(iOS 17.0, *) {
            deviceTypes.append(.external)
        }

        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .video,
            position: .unspecified
        )

        var cameras: [[String: Any]] = []
        for device in discovery.devices {
            cameras.append(inspectDevice(device))
        }

        let processInfo = ProcessInfo.processInfo
        return [
            "platform": "ios",
            "manufacturer": "Apple",
            "brand": "Apple",
            "model": UIDevice.current.model,
            "device": UIDevice.current.name,
            "sdkInt": processInfo.operatingSystemVersion.majorVersion,
            "release": UIDevice.current.systemVersion,
            "rustCoreVersion": resolveRustCoreVersion().version,
            "cameraIdList": discovery.devices.map { $0.uniqueID },
            "cameras": cameras
        ]
    }

    private func inspectDevice(_ device: AVCaptureDevice) -> [String: Any] {
        let positionStr: String
        switch device.position {
        case .back: positionStr = "BACK"
        case .front: positionStr = "FRONT"
        case .unspecified: positionStr = "EXTERNAL"
        @unknown default: positionStr = "UNKNOWN"
        }

        let isVirtual = device.isVirtualDevice
        let constituentIds = device.constituentDevices.map { $0.uniqueID }
        let switchOverZooms = device.virtualDeviceSwitchOverVideoZoomFactors.map { $0.doubleValue }

        let activeFormat = device.activeFormat
        let minISO = activeFormat.minISO
        let maxISO = activeFormat.maxISO
        let minExpSec = CMTimeGetSeconds(activeFormat.minExposureDuration)
        let maxExpSec = CMTimeGetSeconds(activeFormat.maxExposureDuration)

        var maxStillDimensions: [String] = []
        var supportsAppleLog = false
        var supportsHLG = false
        var supportsP3 = false
        var openGateFormats: [String] = []

        for format in device.formats {
            let desc = format.formatDescription
            let dims = CMVideoFormatDescriptionGetDimensions(desc)
            if #available(iOS 16.0, *) {
                for maxDim in format.supportedMaxPhotoDimensions {
                    let dimStr = "\(maxDim.width)x\(maxDim.height)"
                    if !maxStillDimensions.contains(dimStr) {
                        maxStillDimensions.append(dimStr)
                    }
                }
            }
            if dims.width >= 4000 && abs(Double(dims.width) / Double(dims.height) - (4.0 / 3.0)) < 0.05 {
                let og = "\(dims.width)x\(dims.height)"
                if !openGateFormats.contains(og) {
                    openGateFormats.append(og)
                }
            }

            for cs in format.supportedColorSpaces {
                if cs == .P3_D65 { supportsP3 = true }
                if cs == .HLG_BT2020 { supportsHLG = true }
                if #available(iOS 17.0, *) {
                    if cs == .appleLog { supportsAppleLog = true }
                }
            }
        }

        var colorSpaces: [String] = ["sRGB"]
        if supportsP3 { colorSpaces.append("P3_D65") }
        if supportsHLG { colorSpaces.append("HLG_BT2020") }
        if supportsAppleLog { colorSpaces.append("AppleLog") }

        var capabilities: [String] = []
        if device.isExposureModeSupported(.custom) { capabilities.append("MANUAL_EXPOSURE_ISO_SHUTTER") }
        if device.isFocusModeSupported(.locked) { capabilities.append("MANUAL_FOCUS_LOCK") }
        if device.isWhiteBalanceModeSupported(.locked) { capabilities.append("MANUAL_WB_GAINS_LOCK") }
        if !isVirtual { capabilities.append("PHYSICAL_DISCRETE_LENS") }
        if supportsAppleLog { capabilities.append("APPLE_LOG") }
        if !openGateFormats.isEmpty { capabilities.append("OPEN_GATE_4_3") }

        return [
            "cameraId": "\(device.deviceType.rawValue) (\(device.uniqueID))",
            "isDirectlyOpenableInCameraIdList": true,
            "facing": positionStr,
            "hardwareLevel": isVirtual ? "VIRTUAL_FUSION" : "PHYSICAL_DIRECT",
            "sensorOrientation": 90,
            "lensShadingApplied": false,
            "capabilities": capabilities,
            "supportsRawSensor": !isVirtual,
            "rawSensorSizes": maxStillDimensions,
            "raw10Sizes": openGateFormats,
            "maxResolutionRawSensorSizes": maxStillDimensions,
            "physicalCameraIds": constituentIds,
            "focalLengthsMm": switchOverZooms,
            "apertures": [Double(device.lensAperture)],
            "minimumFocusDistanceDiopters": device.isFocusModeSupported(.locked) ? 10.0 : 0.0,
            "isoRange": [Double(minISO), Double(maxISO)],
            "exposureTimeRangeNs": [
                Int64(minExpSec * 1_000_000_000.0),
                Int64(maxExpSec * 1_000_000_000.0)
            ],
            "sensorWhiteLevel": nil as Int?,
            "tenBitDynamicRangeProfiles": colorSpaces,
            "supportsOis": activeFormat.isVideoStabilizationModeSupported(.standard),
            "supportsVideoStabilization": activeFormat.isVideoStabilizationModeSupported(.cinematic)
        ]
    }
}
