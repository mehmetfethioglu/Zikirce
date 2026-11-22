import Flutter
import UIKit
import AVFoundation
import AVKit
import MediaPlayer

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var audioChannel: FlutterMethodChannel?
  private var tvCastChannel: FlutterMethodChannel?
  private var deviceControlChannel: FlutterMethodChannel?
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
}
