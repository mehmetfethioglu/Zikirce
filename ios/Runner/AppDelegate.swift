import Flutter
import UIKit
import AVFoundation
import AVKit
import CoreLocation
import CoreMotion
import MediaPlayer

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var audioChannel: FlutterMethodChannel?
  private var tvCastChannel: FlutterMethodChannel?
  private var deviceControlChannel: FlutterMethodChannel?
  private var qiblaBridge: ZikirceQiblaNativeBridge?
  private var qiblaMethodChannel: FlutterMethodChannel?
  private var qiblaCompassChannel: FlutterEventChannel?
  private var tvCastObserversRegistered = false
  private var hiddenRoutePickerView: AVRoutePickerView?
  private var remoteCommandsConfigured = false
  private var bgTaskIdentifier: UIBackgroundTaskIdentifier = .invalid
  private var isAudioActive = false

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    activatePlaybackSession()
    application.beginReceivingRemoteControlEvents()

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleDidEnterBackground),
      name: UIApplication.didEnterBackgroundNotification,
      object: nil
    )

    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)

    if let controller = window?.rootViewController as? FlutterViewController {
      setupAudioChannel(messenger: controller.binaryMessenger)
      setupTvCastChannel(messenger: controller.binaryMessenger)
      setupDeviceControlChannel(messenger: controller.binaryMessenger)
      setupQiblaChannels(messenger: controller.binaryMessenger)
    }

    return result
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ZikirceAudioBackgroundPlugin") {
      let messenger = registrar.messenger()
      setupAudioChannel(messenger: messenger)
      setupTvCastChannel(messenger: messenger)
      setupDeviceControlChannel(messenger: messenger)
      setupQiblaChannels(messenger: messenger)
    }
  }

  @objc private func handleDidEnterBackground() {
    guard isAudioActive else { return }
    activatePlaybackSession()
    startBackgroundTransitionLease()
  }

  private func setupAudioChannel(messenger: FlutterBinaryMessenger) {
    guard audioChannel == nil else { return }
    let channel = FlutterMethodChannel(
      name: "com.akarworks.zikirce/audio_background",
      binaryMessenger: messenger
    )
    audioChannel = channel

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(nil)
        return
      }
      switch call.method {
      case "activateSession":
        self.isAudioActive = true
        self.activatePlaybackSession()
        self.configureRemoteCommandsIfNeeded()
        result(true)

      case "updateNowPlaying":
        self.isAudioActive = true
        self.activatePlaybackSession()
        self.configureRemoteCommandsIfNeeded()
        if let args = call.arguments as? [String: Any] {
          let title = args["title"] as? String ?? "Kur'an-ı Kerim Tilaveti"
          let subtitle = args["subtitle"] as? String ?? "Zikirce • Kelime Takipli Dinleme"
          let album = args["album"] as? String ?? "Diyanet İşleri Başkanlığı Tilaveti"
          let isPlaying = args["isPlaying"] as? Bool ?? true
          let durationMs = args["durationMs"] as? Double ?? 0.0
          let positionMs = args["positionMs"] as? Double ?? 0.0
          let speed = args["speed"] as? Double ?? 1.0

          var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [String: Any]()
          info[MPMediaItemPropertyTitle] = title
          info[MPMediaItemPropertyArtist] = subtitle
          info[MPMediaItemPropertyAlbumTitle] = album
          info[MPNowPlayingInfoPropertyIsLiveStream] = false
          info[MPNowPlayingInfoPropertyDefaultPlaybackRate] = 1.0
          info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? speed : 0.0
          if durationMs > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = durationMs / 1000.0
          }
          info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = max(0.0, positionMs / 1000.0)

          if info[MPMediaItemPropertyArtwork] == nil,
             let image = UIImage(named: "AppIcon") {
            let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            info[MPMediaItemPropertyArtwork] = artwork
          }

          MPNowPlayingInfoCenter.default().nowPlayingInfo = info
          if #available(iOS 13.0, *) {
            MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
          }
        }
        result(true)

      case "clearNowPlaying":
        self.isAudioActive = false
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        if #available(iOS 13.0, *) {
          MPNowPlayingInfoCenter.default().playbackState = .stopped
        }
        self.endBackgroundTransitionLease()
        result(true)

      case "beginTransitionTask":
        self.startBackgroundTransitionLease()
        result(true)

      case "getAppVersion":
        let vName = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let vCodeStr = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        let vCode = Int(vCodeStr) ?? 0
        result(["versionName": vName, "versionCode": vCode])

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func activatePlaybackSession() {
    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.playback, mode: .default, options: [])
      try session.setActive(true, options: [])
    } catch {
      print("[ZikirceAudio] AVAudioSession configuration warning: \(error)")
    }
  }

  private func configureRemoteCommandsIfNeeded() {
    guard !remoteCommandsConfigured else { return }
    remoteCommandsConfigured = true

    UIApplication.shared.beginReceivingRemoteControlEvents()
    let commandCenter = MPRemoteCommandCenter.shared()

    commandCenter.playCommand.isEnabled = true
    commandCenter.playCommand.addTarget { [weak self] _ in
      self?.audioChannel?.invokeMethod("onRemoteCommand", arguments: "play")
      return .success
    }

    commandCenter.pauseCommand.isEnabled = true
    commandCenter.pauseCommand.addTarget { [weak self] _ in
      self?.audioChannel?.invokeMethod("onRemoteCommand", arguments: "pause")
      return .success
    }

    commandCenter.togglePlayPauseCommand.isEnabled = true
    commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
      self?.audioChannel?.invokeMethod("onRemoteCommand", arguments: "togglePlayPause")
      return .success
    }

    commandCenter.nextTrackCommand.isEnabled = true
    commandCenter.nextTrackCommand.addTarget { [weak self] _ in
      self?.audioChannel?.invokeMethod("onRemoteCommand", arguments: "next")
      return .success
    }

    commandCenter.previousTrackCommand.isEnabled = true
    commandCenter.previousTrackCommand.addTarget { [weak self] _ in
      self?.audioChannel?.invokeMethod("onRemoteCommand", arguments: "previous")
      return .success
    }
  }

  private func startBackgroundTransitionLease() {
    endBackgroundTransitionLease()
    bgTaskIdentifier = UIApplication.shared.beginBackgroundTask(withName: "ZikirceAudioTransition") { [weak self] in
      self?.endBackgroundTransitionLease()
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 25.0) { [weak self] in
      self?.endBackgroundTransitionLease()
    }
  }

  private func endBackgroundTransitionLease() {
    if bgTaskIdentifier != .invalid {
      UIApplication.shared.endBackgroundTask(bgTaskIdentifier)
      bgTaskIdentifier = .invalid
    }
  }

  private func setupDeviceControlChannel(messenger: FlutterBinaryMessenger) {
    guard deviceControlChannel == nil else { return }
    let channel = FlutterMethodChannel(
      name: "com.akarworks.zikirce/battery_optimization",
      binaryMessenger: messenger
    )
    deviceControlChannel = channel

    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "setKeepScreenAwake":
        let enabled = (call.arguments as? [String: Any])?["enabled"] as? Bool ?? false
        DispatchQueue.main.async {
          UIApplication.shared.isIdleTimerDisabled = enabled
        }
        result(true)
      case "isTelevision":
        result(false)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func setupTvCastChannel(messenger: FlutterBinaryMessenger) {
    guard tvCastChannel == nil else { return }
    let channel = FlutterMethodChannel(
      name: "com.akarworks.zikirce/tv_cast",
      binaryMessenger: messenger
    )
    tvCastChannel = channel

    if !tvCastObserversRegistered {
      tvCastObserversRegistered = true
      let nc = NotificationCenter.default
      nc.addObserver(
        self,
        selector: #selector(handleTvCastStateChanged),
        name: UIScreen.didConnectNotification,
        object: nil
      )
      nc.addObserver(
        self,
        selector: #selector(handleTvCastStateChanged),
        name: UIScreen.didDisconnectNotification,
        object: nil
      )
      nc.addObserver(
        self,
        selector: #selector(handleTvCastStateChanged),
        name: UIScreen.capturedDidChangeNotification,
        object: nil
      )
      nc.addObserver(
        self,
        selector: #selector(handleTvCastStateChanged),
        name: AVAudioSession.routeChangeNotification,
        object: nil
      )
    }

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(nil)
        return
      }
      switch call.method {
      case "getCastStatus":
        result(self.currentTvCastStatus())
      case "openCastPicker":
        self.presentNativeAirPlayPicker { opened in
          result([
            "opened": opened,
            "mode": "ios_airplay_picker",
          ])
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  @objc private func handleTvCastStateChanged() {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      self.tvCastChannel?.invokeMethod("onCastStateChanged", arguments: self.currentTvCastStatus())
    }
  }

  private func currentTvCastStatus() -> [String: Any] {
    let windowScenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let activeScene = windowScenes.first(where: { $0.activationState == .foregroundActive }) ?? windowScenes.first
    let mainScreen = activeScene?.screen ?? UIScreen.main
    let hasExternalScreen = UIScreen.screens.count > 1
    let isScreenCaptured = mainScreen.isCaptured

    let outputs = AVAudioSession.sharedInstance().currentRoute.outputs
    let airPlayOutput = outputs.first(where: { $0.portType == .airPlay })
    let hdmiOutput = outputs.first(where: { $0.portType == .HDMI })

    let isVisualMirroring = hasExternalScreen || isScreenCaptured
    let isAirPlayAudio = airPlayOutput != nil
    let isConnected = isVisualMirroring || isAirPlayAudio

    let connectionType: String
    if hasExternalScreen && hdmiOutput != nil {
      connectionType = "wired"
    } else if isVisualMirroring {
      connectionType = "wireless"
    } else if isAirPlayAudio {
      connectionType = "airplay_audio"
    } else {
      connectionType = "none"
    }

    let deviceName: Any = airPlayOutput?.portName ?? hdmiOutput?.portName ?? NSNull()
    return [
      "supported": true,
      "isConnected": isConnected,
      "isVisualMirroring": isVisualMirroring,
      "deviceName": deviceName,
      "connectionType": connectionType,
      "platform": "ios",
    ]
  }

  private func presentNativeAirPlayPicker(completion: @escaping (Bool) -> Void) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else {
        completion(false)
        return
      }
      let windowScenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
      let activeScene = windowScenes.first(where: { $0.activationState == .foregroundActive }) ?? windowScenes.first
      let rootView = activeScene?.windows.first(where: { $0.isKeyWindow })?.rootViewController?.view
        ?? activeScene?.windows.first?.rootViewController?.view
        ?? self.window?.rootViewController?.view

      guard let hostView = rootView else {
        completion(false)
        return
      }

      let picker: AVRoutePickerView
      if let existing = self.hiddenRoutePickerView {
        picker = existing
      } else {
        let created = AVRoutePickerView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
        created.isHidden = true
        created.prioritizesVideoDevices = true
        self.hiddenRoutePickerView = created
        picker = created
      }

      if picker.superview !== hostView {
        picker.removeFromSuperview()
        hostView.addSubview(picker)
      }

      guard let button = picker.subviews.first(where: { $0 is UIButton }) as? UIButton else {
        completion(false)
        return
      }
      button.sendActions(for: .touchUpInside)
      completion(true)
    }
  }

  private func setupQiblaChannels(messenger: FlutterBinaryMessenger) {
    guard qiblaMethodChannel == nil else { return }
    let bridge = self.qiblaBridge ?? ZikirceQiblaNativeBridge()
    self.qiblaBridge = bridge

    let methodChannel = FlutterMethodChannel(
      name: "com.akarworks.zikirce/qibla_native",
      binaryMessenger: messenger
    )
    qiblaMethodChannel = methodChannel
    methodChannel.setMethodCallHandler { [weak bridge] call, result in
      guard let bridge = bridge else {
        result(["status": "unavailable"])
        return
      }
      switch call.method {
      case "getCurrentLocation":
        let args = call.arguments as? [String: Any]
        let requestPermission = args?["requestPermission"] as? Bool ?? true
        bridge.getCurrentLocation(requestPermission: requestPermission, result: result)
      case "openLocationSettings":
        bridge.openLocationSettings(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let eventChannel = FlutterEventChannel(
      name: "com.akarworks.zikirce/qibla_compass",
      binaryMessenger: messenger
    )
    qiblaCompassChannel = eventChannel
    eventChannel.setStreamHandler(bridge)
  }
}

final class ZikirceQiblaNativeBridge: NSObject, FlutterStreamHandler, CLLocationManagerDelegate {
  private let locationManager = CLLocationManager()
  private let motionManager = CMMotionManager()

  private var eventSink: FlutterEventSink?
  private var isCompassActive = false
  private var hasLatestHeading = false

  private var latestHeadingDeg: Double = 0.0
  private var latestIsTrueNorth: Bool = false
  private var latestAccuracyDeg: Double = -1.0
  private var latestNeedsCalibration: Bool = false

  private var latestTiltDeg: Double = 0.0
  private var latestPitchDeg: Double = 0.0
  private var latestRollDeg: Double = 0.0
  private var latestCalibratedFieldUt: Double = 0.0

  private var pendingLocationResult: FlutterResult?
  private var locationTimeoutWorkItem: DispatchWorkItem?

  override init() {
    super.init()
    locationManager.delegate = self
    locationManager.headingFilter = 0.5
    locationManager.headingOrientation = .portrait
    locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
  }

  deinit {
    stopCompassSensors()
    locationTimeoutWorkItem?.cancel()
    locationTimeoutWorkItem = nil
    pendingLocationResult = nil
    locationManager.delegate = nil
  }

  // MARK: - FlutterStreamHandler (Compass)

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    guard CLLocationManager.headingAvailable() else {
      return FlutterError(
        code: "UNAVAILABLE",
        message: "Heading sensor is not available on this device.",
        details: nil
      )
    }

    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      self.eventSink = events
      self.isCompassActive = true
      self.hasLatestHeading = false

      self.locationManager.headingFilter = 0.5
      self.locationManager.headingOrientation = .portrait
      self.locationManager.startUpdatingHeading()

      if self.motionManager.isDeviceMotionAvailable {
        self.motionManager.deviceMotionUpdateInterval = 1.0 / 30.0
        let handler: CMDeviceMotionHandler = { [weak self] motion, _ in
          guard let self = self, self.isCompassActive, let motion = motion else { return }
          self.processDeviceMotion(motion)
        }
        let availableFrames = CMMotionManager.availableAttitudeReferenceFrames()
        if availableFrames.contains(.xMagneticNorthZVertical) {
          self.motionManager.startDeviceMotionUpdates(
            using: .xMagneticNorthZVertical,
            to: .main,
            withHandler: handler
          )
        } else {
          self.motionManager.startDeviceMotionUpdates(to: .main, withHandler: handler)
        }
      }
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    DispatchQueue.main.async { [weak self] in
      self?.stopCompassSensors()
    }
    return nil
  }

  private func stopCompassSensors() {
    isCompassActive = false
    hasLatestHeading = false
    eventSink = nil
    locationManager.stopUpdatingHeading()
    if motionManager.isDeviceMotionActive {
      motionManager.stopDeviceMotionUpdates()
    }
  }

  private func processDeviceMotion(_ motion: CMDeviceMotion) {
    let g = motion.gravity
    // Negate CoreMotion gravity to align with Android accelerometer convention.
    let ax = -g.x * 9.80665
    let ay = -g.y * 9.80665
    let az = -g.z * 9.80665
    let norm = sqrt(ax * ax + ay * ay + az * az)
    if norm >= 0.1 {
      let cosTilt = max(-1.0, min(1.0, az / norm))
      latestTiltDeg = acos(cosTilt) * 180.0 / .pi
      let safeAz = abs(az) < 1e-4 ? (az < 0 ? -1e-4 : 1e-4) : az
      latestPitchDeg = atan2(ay, safeAz) * 180.0 / .pi
      latestRollDeg = atan2(ax, safeAz) * 180.0 / .pi
    }

    // Only expose calibrated magnetic field (µT); raw CLHeading values include MagSafe bias.
    let calibrated = motion.magneticField
    if calibrated.accuracy != .uncalibrated {
      let f = calibrated.field
      let magUt = sqrt(f.x * f.x + f.y * f.y + f.z * f.z)
      if magUt.isFinite {
        latestCalibratedFieldUt = magUt
      }
    } else {
      latestCalibratedFieldUt = 0.0
    }

    if hasLatestHeading {
      emitCompassSample()
    }
  }

  private func emitCompassSample() {
    guard isCompassActive, let sink = eventSink else { return }
    sink([
      "headingDeg": latestHeadingDeg,
      "isTrueNorth": latestIsTrueNorth,
      "accuracyDeg": latestAccuracyDeg,
      "tiltDeg": latestTiltDeg,
      "pitchDeg": latestPitchDeg,
      "rollDeg": latestRollDeg,
      "magneticFieldUt": latestCalibratedFieldUt,
      "needsCalibration": latestNeedsCalibration,
    ])
  }

  // MARK: - Location MethodChannel

  func getCurrentLocation(requestPermission: Bool, result: @escaping FlutterResult) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else {
        result(["status": "unavailable"])
        return
      }

      if self.pendingLocationResult != nil {
        self.resolvePendingLocation(["status": "unavailable"])
      }

      let status = self.currentAuthorizationStatus()
      switch status {
      case .denied, .restricted:
        result(["status": "deniedForever"])
      case .notDetermined:
        if !requestPermission {
          result(["status": "denied"])
          return
        }
        self.pendingLocationResult = result
        self.scheduleLocationTimeout(seconds: 15.0, payload: ["status": "denied"])
        self.locationManager.requestWhenInUseAuthorization()
      case .authorizedWhenInUse, .authorizedAlways:
        self.pendingLocationResult = result
        self.resolveAuthorizedLocationOrRequest()
      @unknown default:
        result(["status": "unavailable"])
      }
    }
  }

  func openLocationSettings(result: @escaping FlutterResult) {
    DispatchQueue.main.async {
      guard let url = URL(string: UIApplication.openSettingsURLString),
            UIApplication.shared.canOpenURL(url) else {
        result(false)
        return
      }
      UIApplication.shared.open(url, options: [:]) { success in
        result(success)
      }
    }
  }

  private func currentAuthorizationStatus() -> CLAuthorizationStatus {
    if #available(iOS 14.0, *) {
      return locationManager.authorizationStatus
    }
    return CLLocationManager.authorizationStatus()
  }

  private func resolveAuthorizedLocationOrRequest() {
    if let cached = locationManager.location,
       abs(cached.timestamp.timeIntervalSinceNow) < 300.0,
       cached.horizontalAccuracy >= 0.0,
       cached.horizontalAccuracy <= 1500.0 {
      resolvePendingLocation([
        "status": "granted",
        "latitude": cached.coordinate.latitude,
        "longitude": cached.coordinate.longitude,
        "accuracyMeters": cached.horizontalAccuracy,
      ])
      return
    }

    locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    scheduleLocationTimeout(seconds: 10.0, payload: ["status": "timeout"])
    locationManager.requestLocation()
  }

  private func scheduleLocationTimeout(seconds: TimeInterval, payload: [String: Any]) {
    locationTimeoutWorkItem?.cancel()
    let item = DispatchWorkItem { [weak self] in
      guard let self = self else { return }
      if let fallback = self.locationManager.location, fallback.horizontalAccuracy >= 0.0 {
        self.resolvePendingLocation([
          "status": "granted",
          "latitude": fallback.coordinate.latitude,
          "longitude": fallback.coordinate.longitude,
          "accuracyMeters": fallback.horizontalAccuracy,
        ])
      } else {
        self.resolvePendingLocation(payload)
      }
    }
    locationTimeoutWorkItem = item
    DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: item)
  }

  private func resolvePendingLocation(_ payload: [String: Any]) {
    let complete = { [weak self] in
      guard let self = self else { return }
      self.locationTimeoutWorkItem?.cancel()
      self.locationTimeoutWorkItem = nil
      guard let callback = self.pendingLocationResult else { return }
      self.pendingLocationResult = nil
      callback(payload)
    }
    if Thread.isMainThread {
      complete()
    } else {
      DispatchQueue.main.async(execute: complete)
    }
  }

  // MARK: - CLLocationManagerDelegate

  func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool {
    return true
  }

  func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
    let headingDeg: Double
    let isTrueNorth: Bool
    if newHeading.trueHeading >= 0.0 {
      headingDeg = newHeading.trueHeading
      isTrueNorth = true
    } else if newHeading.magneticHeading >= 0.0 {
      headingDeg = newHeading.magneticHeading
      isTrueNorth = false
    } else {
      return
    }

    let accuracyDeg = newHeading.headingAccuracy
    let needsCal = accuracyDeg < 0.0 || accuracyDeg > 25.0

    latestHeadingDeg = headingDeg
    latestIsTrueNorth = isTrueNorth
    latestAccuracyDeg = accuracyDeg
    latestNeedsCalibration = needsCal
    hasLatestHeading = true
    emitCompassSample()
  }

  @available(iOS 14.0, *)
  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    handleAuthorizationChanged(manager.authorizationStatus)
  }

  func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
    handleAuthorizationChanged(status)
  }

  private func handleAuthorizationChanged(_ status: CLAuthorizationStatus) {
    switch status {
    case .authorizedWhenInUse, .authorizedAlways:
      if isCompassActive && CLLocationManager.headingAvailable() {
        locationManager.startUpdatingHeading()
      }
      if pendingLocationResult != nil {
        resolveAuthorizedLocationOrRequest()
      }
    case .denied, .restricted:
      if pendingLocationResult != nil {
        resolvePendingLocation(["status": "deniedForever"])
      }
    case .notDetermined:
      break
    @unknown default:
      if pendingLocationResult != nil {
        resolvePendingLocation(["status": "unavailable"])
      }
    }
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let loc = locations.last else { return }
    resolvePendingLocation([
      "status": "granted",
      "latitude": loc.coordinate.latitude,
      "longitude": loc.coordinate.longitude,
      "accuracyMeters": loc.horizontalAccuracy,
    ])
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    if let clErr = error as? CLError, clErr.code == .denied {
      resolvePendingLocation(["status": "deniedForever"])
      return
    }
    if let fallback = manager.location, fallback.horizontalAccuracy >= 0.0 {
      resolvePendingLocation([
        "status": "granted",
        "latitude": fallback.coordinate.latitude,
        "longitude": fallback.coordinate.longitude,
        "accuracyMeters": fallback.horizontalAccuracy,
      ])
      return
    }
    resolvePendingLocation(["status": "timeout"])
  }
}
