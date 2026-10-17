import Flutter
import UIKit
import AVFoundation
import MediaPlayer

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var audioChannel: FlutterMethodChannel?
  private var remoteCommandsConfigured = false
  private var bgTaskIdentifier: UIBackgroundTaskIdentifier = .invalid
  private var isAudioActive = false

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

    if audioChannel == nil,
       let controller = window?.rootViewController as? FlutterViewController {
      setupAudioChannel(messenger: controller.binaryMessenger)
    }

    return result
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ZikirceAudioBackgroundPlugin") {
      setupAudioChannel(messenger: registrar.messenger())
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
}
