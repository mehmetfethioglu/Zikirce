import Flutter
import UIKit
import AVFoundation

/**
 * ZameraCapturePlugin (iOS AVFoundation Hardware Probe + Live FlutterTexture Preview + Physical Lens Lock + Bayer RAW / ProRAW Capture)
 */
public class ZameraCapturePlugin: NSObject, FlutterPlugin, FlutterTexture, AVCaptureVideoDataOutputSampleBufferDelegate, AVCapturePhotoCaptureDelegate {
    private var textureRegistry: FlutterTextureRegistry?
    private var textureId: Int64 = -1
    private var latestPixelBuffer: CVPixelBuffer?
    private let bufferLock = NSLock()

    private let sessionQueue = DispatchQueue(label: "com.akarworks.zamera.sessionQueue")
    private var captureSession: AVCaptureSession?
    private var activeDevice: AVCaptureDevice?
    private var photoOutput: AVCapturePhotoOutput?
    private var videoOutput: AVCaptureVideoDataOutput?
    private var pendingCaptureResult: FlutterResult?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.akarworks.zamera/capture_probe",
            binaryMessenger: registrar.messenger()
        )
        let instance = ZameraCapturePlugin()
        instance.textureRegistry = registrar.textures()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        bufferLock.lock()
        defer { bufferLock.unlock() }
        guard let buffer = latestPixelBuffer else { return nil }
        return Unmanaged.passRetained(buffer)
    }

    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        bufferLock.lock()
        latestPixelBuffer = pixelBuffer
        bufferLock.unlock()
        if textureId >= 0 {
            textureRegistry?.textureFrameAvailable(textureId)
        }
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "probeDeviceCapabilities":
            result(probeAVFoundationCapabilities())
        case "startPreviewSession":
            let args = call.arguments as? [String: Any] ?? [:]
            let cameraId = args["cameraId"] as? String ?? "builtInWideAngleCamera"
            startPreviewSession(cameraId: cameraId, result: result)
        case "updateManualControls":
            let args = call.arguments as? [String: Any] ?? [:]
            updateManualControls(args: args, result: result)
        case "capturePhoto":
            let args = call.arguments as? [String: Any] ?? [:]
            captureRawAndHeicPhoto(args: args, result: result)
        case "stopPreviewSession":
            stopPreviewSession()
            result(true)
        case "getRustCoreVersion":
            result("zamera_core 0.2.0 (TrueColor 24-Patch ColorChecker + FlatField)")
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func startPreviewSession(cameraId: String, result: @escaping FlutterResult) {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.stopPreviewSessionInternal()

            let session = AVCaptureSession()
            session.beginConfiguration()
            session.sessionPreset = .photo

            // Select physical lens directly to prevent iOS automatic macro/tele crop switching
            let targetDevice: AVCaptureDevice?
            if cameraId.contains("Telephoto") {
                targetDevice = AVCaptureDevice.default(.builtInTelephotoCamera, for: .video, position: .back)
            } else if cameraId.contains("UltraWide") {
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
                result([
                    "textureId": self.textureId,
                    "previewWidth": Int(dims.width),
                    "previewHeight": Int(dims.height),
                    "activeCameraId": device.deviceType.rawValue,
                    "supportsRawSensor": !(pOut.availableRawPhotoPixelFormatTypes.isEmpty)
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

                let manualExposure = args["manualExposure"] as? Bool ?? false
                if manualExposure && device.isExposureModeSupported(.custom) {
                    let reqIso = Float(args["iso"] as? Double ?? 100.0)
                    let clampedIso = max(device.activeFormat.minISO, min(device.activeFormat.maxISO, reqIso))
                    let shutterNs = args["exposureTimeNs"] as? Int64 ?? 8_000_000
                    let reqDuration = CMTimeMake(value: shutterNs, timescale: 1_000_000_000)
                    device.setExposureModeCustom(duration: reqDuration, iso: clampedIso, completionHandler: nil)
                } else if device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposureMode = .continuousAutoExposure
                }

                let manualFocus = args["manualFocus"] as? Bool ?? false
                if manualFocus && device.isFocusModeSupported(.locked) {
                    let lensPos = Float(args["focusDistance"] as? Double ?? 0.5)
                    device.setFocusModeLocked(lensPosition: max(0.0, min(1.0, lensPos)), completionHandler: nil)
                } else if device.isFocusModeSupported(.continuousAutoFocus) {
                    device.focusMode = .continuousAutoFocus
                }

                let manualWb = args["manualWb"] as? Bool ?? false
                if manualWb && device.isWhiteBalanceModeSupported(.locked),
                   let rggb = args["rggbGains"] as? [Double], rggb.count >= 4 {
                    let maxGain = device.maxWhiteBalanceGain
                    let gains = AVCaptureDevice.WhiteBalanceGains(
                        redGain: max(1.0, min(maxGain, Float(rggb[0]))),
                        greenGain: max(1.0, min(maxGain, Float(rggb[1]))),
                        blueGain: max(1.0, min(maxGain, Float(rggb[3])))
                    )
                    device.setWhiteBalanceModeLocked(with: gains, completionHandler: nil)
                } else if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                    device.whiteBalanceMode = .continuousAutoWhiteBalance
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

    private func captureRawAndHeicPhoto(args: [String: Any], result: @escaping FlutterResult) {
        sessionQueue.async { [weak self] in
            guard let self = self, let pOut = self.photoOutput else {
                DispatchQueue.main.async {
                    result(FlutterError(code: "NO_PHOTO_OUTPUT", message: "Photo output not active", details: nil))
                }
                return
            }

            let preferProRaw = args["preferProRaw"] as? Bool ?? false
            var selectedRawFormat: OSType?

            if #available(iOS 14.3, *) {
                selectedRawFormat = pOut.availableRawPhotoPixelFormatTypes.first { fmt in
                    preferProRaw ? AVCapturePhotoOutput.isAppleProRAWPixelFormat(fmt) : AVCapturePhotoOutput.isBayerRAWPixelFormat(fmt)
                } ?? pOut.availableRawPhotoPixelFormatTypes.first
            } else {
                selectedRawFormat = pOut.availableRawPhotoPixelFormatTypes.first
            }

            let settings: AVCapturePhotoSettings
            if let rawFmt = selectedRawFormat {
                settings = AVCapturePhotoSettings(
                    rawPixelFormatType: rawFmt,
                    processedFormat: [AVVideoCodecKey: AVVideoCodecType.jpeg]
                )
            } else {
                settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
            }

            self.pendingCaptureResult = result
            pOut.capturePhoto(with: settings, delegate: self)
        }
    }

    public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let cb = pendingCaptureResult else { return }
        if let err = error {
            pendingCaptureResult = nil
            DispatchQueue.main.async {
                cb(FlutterError(code: "PHOTO_CAPTURE_ERR", message: err.localizedDescription, details: nil))
            }
            return
        }

        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let ts = Int(Date().timeIntervalSince1970 * 1000)
        if photo.isRawPhoto {
            let dngUrl = docs.appendingPathComponent("ZAMERA_\(ts).dng")
            if let data = photo.fileDataRepresentation() {
                try? data.write(to: dngUrl)
                pendingCaptureResult = nil
                DispatchQueue.main.async {
                    cb([
                        "dngPath": dngUrl.path,
                        "jpegPath": dngUrl.path,
                        "cameraId": self.activeDevice?.deviceType.rawValue ?? "ios"
                    ])
                }
            }
        } else {
            let jpgUrl = docs.appendingPathComponent("ZAMERA_\(ts).jpg")
            if let data = photo.fileDataRepresentation() {
                try? data.write(to: jpgUrl)
                pendingCaptureResult = nil
                DispatchQueue.main.async {
                    cb([
                        "jpegPath": jpgUrl.path,
                        "dngPath": nil as String?,
                        "cameraId": self.activeDevice?.deviceType.rawValue ?? "ios"
                    ])
                }
            }
        }
    }

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
        if textureId >= 0 {
            let oldId = textureId
            textureId = -1
            DispatchQueue.main.async { [weak self] in
                self?.textureRegistry?.unregisterTexture(oldId)
            }
        }
    }

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
            "rustCoreVersion": "zamera_core 0.2.0 (TrueColor 24-Patch ColorChecker + FlatField)",
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
            "capabilities": capabilities,
            "supportsRawSensor": !isVirtual,
            "rawSensorSizes": maxStillDimensions,
            "raw10Sizes": openGateFormats,
            "maxResolutionRawSensorSizes": maxStillDimensions,
            "physicalCameraIds": constituentIds,
            "focalLengthsMm": switchOverZooms,
            "apertures": [Double(device.lensAperture)],
            "minimumFocusDistanceDiopters": nil as Double?,
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
