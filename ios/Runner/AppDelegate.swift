import Flutter
import UIKit
import Foundation
import Darwin
import Speech
import AVFoundation
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var netServiceBrowsers: [NetServiceBrowser] = []
  private var audioEngine: AVAudioEngine?
  private var speechRecognizer: SFSpeechRecognizer?
  private var speechRecognitionRequest: SFSpeechAudioBufferRecognitionRequest?
  private var speechRecognitionTask: SFSpeechRecognitionTask?
  private var pendingVoiceResult: FlutterResult?
  private var latestVoiceTranscript: String = ""
  private var voiceSilenceTimer: Timer?
  private var voiceMaxTimeoutTimer: Timer?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .list, .sound, .badge])
    } else {
      completionHandler([.alert, .sound, .badge])
    }
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "CueDeckIosNetworkBridge") {
      let channel = FlutterMethodChannel(
        name: "com.akarworks.cuedeck/network",
        binaryMessenger: registrar.messenger()
      )
      channel.setMethodCallHandler { [weak self] call, result in
        guard let self = self else {
          result(FlutterError(code: "DISPOSED", message: "AppDelegate disposed", details: nil))
          return
        }
        self.handleNetworkMethodCall(call: call, result: result)
      }
    }

    if let voiceRegistrar = engineBridge.pluginRegistry.registrar(forPlugin: "CueDeckIosVoiceBridge") {
      let voiceChannel = FlutterMethodChannel(
        name: "com.akarworks.cuedeck/voice",
        binaryMessenger: voiceRegistrar.messenger()
      )
      voiceChannel.setMethodCallHandler { [weak self] call, result in
        guard let self = self else {
          result(FlutterError(code: "DISPOSED", message: "AppDelegate disposed", details: nil))
          return
        }
        self.handleVoiceMethodCall(call: call, result: result)
      }
    }

    if let notifRegistrar = engineBridge.pluginRegistry.registrar(forPlugin: "CueDeckIosNotificationBridge") {
      let notifChannel = FlutterMethodChannel(
        name: "com.akarworks.cuedeck/notifications",
        binaryMessenger: notifRegistrar.messenger()
      )
      notifChannel.setMethodCallHandler { [weak self] call, result in
        guard let self = self else {
          result(FlutterError(code: "DISPOSED", message: "AppDelegate disposed", details: nil))
          return
        }
        self.handleNotificationMethodCall(call: call, result: result)
      }
    }
  }

  private func handleNotificationMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
    let center = UNUserNotificationCenter.current()
    switch call.method {
    case "requestNotificationPermission":
      center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
        DispatchQueue.main.async {
          result(granted)
        }
      }

    case "showNotificationNow":
      let args = call.arguments as? [String: Any]
      let notificationId = (args?["notificationId"] as? Int) ?? 2001
      let title = (args?["title"] as? String) ?? "CueDeck İzleme Vakti"
      let body = (args?["body"] as? String) ?? ""
      let subText = (args?["subText"] as? String) ?? ""
      let cueId = (args?["cueId"] as? String) ?? ""

      let content = UNMutableNotificationContent()
      content.title = title
      content.body = body
      if !subText.isEmpty {
        content.subtitle = subText
      }
      content.sound = .default
      if !cueId.isEmpty {
        content.userInfo = ["cueId": cueId]
      }

      let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.25, repeats: false)
      let req = UNNotificationRequest(
        identifier: "cuedeck_immediate_\(notificationId)",
        content: content,
        trigger: trigger
      )
      center.add(req) { err in
        DispatchQueue.main.async {
          result(err == nil)
        }
      }

    case "syncScheduledNotifications":
      let args = call.arguments as? [String: Any]
      let rawAlarms = (args?["alarms"] as? [[String: Any]]) ?? []
      center.getPendingNotificationRequests { pending in
        let oldIds = pending
          .map { $0.identifier }
          .filter { $0.hasPrefix("cuedeck_alarm_") }
        if !oldIds.isEmpty {
          center.removePendingNotificationRequests(withIdentifiers: oldIds)
        }

        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        var scheduledCount = 0
        let calendar = Calendar.current

        for entry in rawAlarms {
          guard let alarmId = (entry["alarmId"] as? NSNumber)?.intValue,
                let triggerAtMillis = (entry["triggerAtMillis"] as? NSNumber)?.int64Value,
                triggerAtMillis > nowMs else {
            continue
          }
          let title = (entry["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
          if title.isEmpty { continue }
          let body = (entry["body"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
          let subText = (entry["subText"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
          let cueId = (entry["cueId"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

          let content = UNMutableNotificationContent()
          content.title = title
          content.body = body
          if !subText.isEmpty {
            content.subtitle = subText
          }
          content.sound = .default
          if !cueId.isEmpty {
            content.userInfo = ["cueId": cueId]
          }

          let fireDate = Date(timeIntervalSince1970: TimeInterval(triggerAtMillis) / 1000.0)
          let comps = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: fireDate
          )
          let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
          let req = UNNotificationRequest(
            identifier: "cuedeck_alarm_\(alarmId)",
            content: content,
            trigger: trigger
          )
          center.add(req, withCompletionHandler: nil)
          scheduledCount += 1
        }

        DispatchQueue.main.async {
          result(scheduledCount)
        }
      }

    case "cancelAllNotifications":
      center.removeAllPendingNotificationRequests()
      result(true)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func handleVoiceMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "startVoiceRecognition":
      let args = call.arguments as? [String: Any]
      let localeId = (args?["locale"] as? String) ?? "tr-TR"
      DispatchQueue.main.async {
        if self.pendingVoiceResult != nil {
          self.finishVoiceSession(with: nil)
        }
        self.pendingVoiceResult = result
        self.latestVoiceTranscript = ""

        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
          DispatchQueue.main.async {
            guard let self = self else { return }
            guard authStatus == .authorized else {
              self.finishVoiceSession(with: "__PERMISSION_DENIED__")
              return
            }
            self.requestMicrophonePermission { micGranted in
              DispatchQueue.main.async {
                guard micGranted else {
                  self.finishVoiceSession(with: "__PERMISSION_DENIED__")
                  return
                }
                self.beginIosSpeechCapture(localeId: localeId)
              }
            }
          }
        }
      }

    case "stopVoiceRecognition":
      DispatchQueue.main.async {
        let captured = self.latestVoiceTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        self.finishVoiceSession(with: captured.isEmpty ? nil : captured)
        result(nil)
      }

    case "cancelVoiceRecognition":
      DispatchQueue.main.async {
        self.finishVoiceSession(with: nil)
        result(nil)
      }

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
    if #available(iOS 17.0, *) {
      AVAudioApplication.requestRecordPermission { granted in
        completion(granted)
      }
    } else {
      AVAudioSession.sharedInstance().requestRecordPermission { granted in
        completion(granted)
      }
    }
  }

  private func beginIosSpeechCapture(localeId: String) {
    stopAudioEngineAndTimers()

    let recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeId))
      ?? SFSpeechRecognizer(locale: Locale(identifier: "tr-TR"))
      ?? SFSpeechRecognizer(locale: Locale.current)
      ?? SFSpeechRecognizer()

    guard let activeRecognizer = recognizer, activeRecognizer.isAvailable else {
      finishVoiceSession(with: nil)
      return
    }
    self.speechRecognizer = activeRecognizer

    let audioSession = AVAudioSession.sharedInstance()
    do {
      do {
        try audioSession.setCategory(
          .playAndRecord,
          mode: .measurement,
          options: [.duckOthers, .defaultToSpeaker, .allowBluetooth]
        )
      } catch {
        try audioSession.setCategory(.record, mode: .default, options: [])
      }
      try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
    } catch {
      finishVoiceSession(with: nil)
      return
    }

    let request = SFSpeechAudioBufferRecognitionRequest()
    request.shouldReportPartialResults = true
    self.speechRecognitionRequest = request

    let engine = AVAudioEngine()
    self.audioEngine = engine
    let inputNode = engine.inputNode
    let recordingFormat = inputNode.outputFormat(forBus: 0)
    guard recordingFormat.sampleRate > 0 && recordingFormat.channelCount > 0 else {
      finishVoiceSession(with: nil)
      return
    }

    inputNode.removeTap(onBus: 0)
    inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
      self?.speechRecognitionRequest?.append(buffer)
    }

    do {
      engine.prepare()
      try engine.start()
    } catch {
      finishVoiceSession(with: nil)
      return
    }

    // Max initial silence / session timeout (7.5 seconds)
    self.voiceMaxTimeoutTimer = Timer.scheduledTimer(withTimeInterval: 7.5, repeats: false) { [weak self] _ in
      guard let self = self else { return }
      let captured = self.latestVoiceTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
      self.finishVoiceSession(with: captured.isEmpty ? nil : captured)
    }

    self.speechRecognitionTask = activeRecognizer.recognitionTask(with: request) { [weak self] res, err in
      DispatchQueue.main.async {
        guard let self = self, self.pendingVoiceResult != nil else { return }
        if let res = res {
          let text = res.bestTranscription.formattedString.trimmingCharacters(in: .whitespacesAndNewlines)
          if !text.isEmpty {
            self.latestVoiceTranscript = text
            if res.isFinal {
              self.finishVoiceSession(with: text)
              return
            }
            // Reset 1.35s post-speech silence endpoint timer
            self.voiceSilenceTimer?.invalidate()
            self.voiceSilenceTimer = Timer.scheduledTimer(withTimeInterval: 1.35, repeats: false) { [weak self] _ in
              guard let self = self else { return }
              let finalText = self.latestVoiceTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
              self.finishVoiceSession(with: finalText.isEmpty ? nil : finalText)
            }
          }
        }
        if err != nil {
          let captured = self.latestVoiceTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
          self.finishVoiceSession(with: captured.isEmpty ? nil : captured)
        }
      }
    }
  }

  private func stopAudioEngineAndTimers() {
    voiceSilenceTimer?.invalidate()
    voiceSilenceTimer = nil
    voiceMaxTimeoutTimer?.invalidate()
    voiceMaxTimeoutTimer = nil

    if let engine = audioEngine {
      if engine.isRunning {
        engine.stop()
      }
      engine.inputNode.removeTap(onBus: 0)
    }
    audioEngine = nil

    speechRecognitionRequest?.endAudio()
    speechRecognitionRequest = nil

    speechRecognitionTask?.cancel()
    speechRecognitionTask = nil

    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
  }

  private func finishVoiceSession(with transcript: String?) {
    stopAudioEngineAndTimers()
    guard let callback = pendingVoiceResult else { return }
    pendingVoiceResult = nil
    callback(transcript)
  }

  private func handleNetworkMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getWifiInfo":
      let info = Self.queryWifiInterfaceInfo()
      result(info)

    case "openAppSettings":
      DispatchQueue.main.async {
        if let url = URL(string: UIApplication.openSettingsURLString),
           UIApplication.shared.canOpenURL(url) {
          UIApplication.shared.open(url, options: [:]) { ok in
            result(ok)
          }
        } else {
          result(false)
        }
      }

    case "triggerLocalNetworkPrompt":
      triggerBonjourLocalNetworkPrompt()
      result(true)

    case "scanSubnetForTvs":
      triggerBonjourLocalNetworkPrompt()
      let args = call.arguments as? [String: Any]
      let preferredIp = (args?["preferredIp"] as? String) ?? ""
      DispatchQueue.global(qos: .userInitiated).async {
        let scanResult = Self.performNativeSubnetScan(preferredIp: preferredIp)
        DispatchQueue.main.async {
          result(scanResult)
        }
      }

    case "nativeAdbShell":
      let args = call.arguments as? [String: Any]
      let ip = (args?["ip"] as? String) ?? ""
      let port = UInt16((args?["port"] as? Int) ?? 5555)
      let command = (args?["command"] as? String) ?? ""
      let timeoutMs = Int32((args?["timeoutMs"] as? Int) ?? 1500)
      DispatchQueue.global(qos: .userInitiated).async {
        let adbResult = Self.executeNativeAdbCommand(
          ip: ip,
          port: port,
          shellCommand: command,
          timeoutMs: timeoutMs
        )
        DispatchQueue.main.async {
          result(adbResult)
        }
      }

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func triggerBonjourLocalNetworkPrompt() {
    DispatchQueue.main.async {
      self.netServiceBrowsers.removeAll()
      let services = ["_androidtvremote2._tcp.", "_adb._tcp.", "_googlecast._tcp."]
      for svc in services {
        let browser = NetServiceBrowser()
        browser.includesPeerToPeer = true
        browser.searchForServices(ofType: svc, inDomain: "local.")
        self.netServiceBrowsers.append(browser)
      }
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
        self?.netServiceBrowsers.forEach { $0.stop() }
        self?.netServiceBrowsers.removeAll()
      }
    }
  }

  private static func queryWifiInterfaceInfo() -> [String: Any] {
    var wifiIp = ""
    var subnetPrefix = ""
    var interfacesList: [String] = []
    var ifaddrPtr: UnsafeMutablePointer<ifaddrs>?

    if getifaddrs(&ifaddrPtr) == 0, let firstAddr = ifaddrPtr {
      var ptr: UnsafeMutablePointer<ifaddrs>? = firstAddr
      while let current = ptr {
        let flags = Int32(current.pointee.ifa_flags)
        let isUp = (flags & IFF_UP) != 0 && (flags & IFF_LOOPBACK) == 0
        if isUp, let addr = current.pointee.ifa_addr, addr.pointee.sa_family == UInt8(AF_INET) {
          let name = String(cString: current.pointee.ifa_name)
          var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
          if getnameinfo(
            addr,
            socklen_t(addr.pointee.sa_len),
            &hostname,
            socklen_t(hostname.count),
            nil,
            0,
            NI_NUMERICHOST
          ) == 0 {
            let ip = String(cString: hostname)
            interfacesList.append("\(name):\(ip)")
            if name == "en0" || (wifiIp.isEmpty && name.hasPrefix("en") && ip.hasPrefix("192.168.")) {
              wifiIp = ip
              let parts = ip.split(separator: ".")
              if parts.count == 4 {
                subnetPrefix = "\(parts[0]).\(parts[1]).\(parts[2])"
              }
            }
          }
        }
        ptr = current.pointee.ifa_next
      }
      freeifaddrs(ifaddrPtr)
    }

    let en0Idx = if_nametoindex("en0")
    return [
      "wifiIp": wifiIp,
      "subnetPrefix": subnetPrefix,
      "en0Index": Int(en0Idx),
      "interfaces": interfacesList
    ]
  }

  private static func tcpConnectBound(
    ip: String,
    port: UInt16,
    en0Index: UInt32,
    timeoutMs: Int32
  ) -> (fd: Int32, errCode: Int32) {
    let fd = socket(AF_INET, SOCK_STREAM, 0)
    if fd < 0 {
      return (-1, errno)
    }

    var one: Int32 = 1
    _ = setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &one, socklen_t(MemoryLayout<Int32>.size))
    _ = setsockopt(fd, IPPROTO_TCP, TCP_NODELAY, &one, socklen_t(MemoryLayout<Int32>.size))

    if en0Index > 0 {
      var boundIdx = en0Index
      _ = setsockopt(
        fd,
        IPPROTO_IP,
        IP_BOUND_IF,
        &boundIdx,
        socklen_t(MemoryLayout<UInt32>.size)
      )
    }

    let flags = fcntl(fd, F_GETFL, 0)
    _ = fcntl(fd, F_SETFL, flags | O_NONBLOCK)

    var addr = sockaddr_in()
    addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    addr.sin_family = sa_family_t(AF_INET)
    addr.sin_port = port.bigEndian
    guard inet_pton(AF_INET, ip, &addr.sin_addr) == 1 else {
      close(fd)
      return (-1, EINVAL)
    }

    let connectRc = withUnsafePointer(to: &addr) {
      $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
      }
    }

    if connectRc < 0 {
      let err = errno
      if err != EINPROGRESS {
        close(fd)
        return (-1, err)
      }
    }

    var pfd = pollfd(fd: fd, events: Int16(POLLOUT), revents: 0)
    let pollRc = poll(&pfd, 1, timeoutMs)
    if pollRc <= 0 {
      close(fd)
      return (-1, ETIMEDOUT)
    }

    var soErr: Int32 = 0
    var soLen = socklen_t(MemoryLayout<Int32>.size)
    if getsockopt(fd, SOL_SOCKET, SO_ERROR, &soErr, &soLen) < 0 || soErr != 0 {
      close(fd)
      return (-1, soErr != 0 ? soErr : errno)
    }

    _ = fcntl(fd, F_SETFL, flags)
    var tv = timeval(tv_sec: 2, tv_usec: 500_000)
    _ = setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
    _ = setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
    return (fd, 0)
  }

  private static func probePortWithFallback(
    ip: String,
    port: UInt16,
    en0Index: UInt32,
    timeoutMs: Int32
  ) -> (open: Bool, errCode: Int32) {
    let first = tcpConnectBound(ip: ip, port: port, en0Index: en0Index, timeoutMs: timeoutMs)
    if first.fd >= 0 {
      close(first.fd)
      return (true, 0)
    }
    if en0Index > 0 && (first.errCode == ENETUNREACH || first.errCode == ENETDOWN) {
      let second = tcpConnectBound(ip: ip, port: port, en0Index: 0, timeoutMs: timeoutMs)
      if second.fd >= 0 {
        close(second.fd)
        return (true, 0)
      }
      return (false, second.errCode)
    }
    return (false, first.errCode)
  }

  private static func performNativeSubnetScan(preferredIp: String) -> [String: Any] {
    let wifiInfo = queryWifiInterfaceInfo()
    let wifiIp = (wifiInfo["wifiIp"] as? String) ?? ""
    var prefix = (wifiInfo["subnetPrefix"] as? String) ?? ""
    let en0Index = UInt32((wifiInfo["en0Index"] as? Int) ?? 0)

    if prefix.isEmpty {
      let parts = preferredIp.split(separator: ".")
      if parts.count == 4 {
        prefix = "\(parts[0]).\(parts[1]).\(parts[2])"
      } else {
        prefix = "192.168.1"
      }
    }

    let lock = NSLock()
    var open5555 = Set<String>()
    var open6466 = Set<String>()
    var open8008 = Set<String>()
    var openSmartTv = Set<String>()
    let smartTvPorts: [UInt16] = [8085, 56789, 8001, 3000, 1925, 8060]
    var permissionDeniedCount = 0
    var lastPermissionErrno: Int32 = 0
    var anyLanTrafficAllowed = false

    // 0. Probe gateway (prefix.1) on port 80/53 to verify Local Network permission accurately.
    // On iOS, EHOSTUNREACH (65) on unused subnet IPs is normal ARP miss, NOT permission denial!
    // If any host or gateway returns open, ECONNREFUSED (61), or ETIMEDOUT (60), Local Network is ON.
    let gatewayIp = "\(prefix).1"
    for gwPort: UInt16 in [80, 443, 53] {
      let gw = probePortWithFallback(ip: gatewayIp, port: gwPort, en0Index: en0Index, timeoutMs: 180)
      if gw.open || gw.errCode == ECONNREFUSED || gw.errCode == ETIMEDOUT {
        anyLanTrafficAllowed = true
        break
      } else if gw.errCode == EPERM || gw.errCode == EACCES {
        permissionDeniedCount += 1
        lastPermissionErrno = gw.errCode
      }
    }

    // 1. Two-stage warmup + probe on preferredIp first (if valid)
    if !preferredIp.isEmpty {
      let warm = probePortWithFallback(ip: preferredIp, port: 5555, en0Index: en0Index, timeoutMs: 360)
      if warm.open {
        open5555.insert(preferredIp)
        anyLanTrafficAllowed = true
      } else {
        if warm.errCode == ECONNREFUSED || warm.errCode == ETIMEDOUT {
          anyLanTrafficAllowed = true
        } else if warm.errCode == EPERM || warm.errCode == EACCES {
          permissionDeniedCount += 1
          lastPermissionErrno = warm.errCode
        }
        usleep(80_000)
        let retry = probePortWithFallback(ip: preferredIp, port: 5555, en0Index: en0Index, timeoutMs: 650)
        if retry.open {
          open5555.insert(preferredIp)
          anyLanTrafficAllowed = true
        }
      }
      let p6466 = probePortWithFallback(ip: preferredIp, port: 6466, en0Index: en0Index, timeoutMs: 420)
      if p6466.open {
        open6466.insert(preferredIp)
        anyLanTrafficAllowed = true
      }
      for sPort in smartTvPorts {
        let pSmart = probePortWithFallback(ip: preferredIp, port: sPort, en0Index: en0Index, timeoutMs: 280)
        if pSmart.open {
          openSmartTv.insert("\(preferredIp):\(sPort)")
          anyLanTrafficAllowed = true
          break
        }
      }
      let p8008 = probePortWithFallback(ip: preferredIp, port: 8008, en0Index: en0Index, timeoutMs: 360)
      if p8008.open {
        open8008.insert(preferredIp)
        anyLanTrafficAllowed = true
      }
    }

    // 2. Build ordered octet list: priority DHCP ranges (2..60, 95..160) first, then remaining (61..94, 161..254)
    var orderedOctets: [Int] = Array(2...60)
    orderedOctets.append(contentsOf: Array(95...160))
    orderedOctets.append(contentsOf: Array(61...94))
    orderedOctets.append(contentsOf: Array(161...254))

    // Full scan across all 253 octets in 4 high-concurrency chunks of 64 (~2.4s total)
    let fullChunkSize = 64
    for start in stride(from: 0, to: orderedOctets.count, by: fullChunkSize) {
      let end = min(start + fullChunkSize, orderedOctets.count)
      let slice = Array(orderedOctets[start..<end])

      DispatchQueue.concurrentPerform(iterations: slice.count) { idx in
        let ip = "\(prefix).\(slice[idx])"
        if ip == wifiIp { return }

        var hostIsAlive = false
        let r5555 = probePortWithFallback(ip: ip, port: 5555, en0Index: en0Index, timeoutMs: 220)
        if r5555.open {
          lock.lock()
          open5555.insert(ip)
          anyLanTrafficAllowed = true
          lock.unlock()
          hostIsAlive = true
        } else if r5555.errCode == ECONNREFUSED {
          hostIsAlive = true
          lock.lock()
          anyLanTrafficAllowed = true
          lock.unlock()
        } else if r5555.errCode == EPERM || r5555.errCode == EACCES {
          lock.lock()
          permissionDeniedCount += 1
          lastPermissionErrno = r5555.errCode
          lock.unlock()
        }

        let probeTimeout: Int32 = hostIsAlive ? 240 : 140
        let r6466 = probePortWithFallback(ip: ip, port: 6466, en0Index: en0Index, timeoutMs: probeTimeout)
        if r6466.open {
          lock.lock()
          open6466.insert(ip)
          anyLanTrafficAllowed = true
          lock.unlock()
          hostIsAlive = true
        } else if r6466.errCode == ECONNREFUSED {
          hostIsAlive = true
        }

        var matchedSmart = false
        let primarySmartPorts: [UInt16] = hostIsAlive ? smartTvPorts : [8085, 56789]
        for sPort in primarySmartPorts {
          let rSmart = probePortWithFallback(ip: ip, port: sPort, en0Index: en0Index, timeoutMs: hostIsAlive ? 200 : 130)
          if rSmart.open {
            lock.lock()
            openSmartTv.insert("\(ip):\(sPort)")
            anyLanTrafficAllowed = true
            lock.unlock()
            matchedSmart = true
            hostIsAlive = true
            break
          } else if rSmart.errCode == ECONNREFUSED && !hostIsAlive {
            hostIsAlive = true
            for extraPort: UInt16 in [8001, 3000, 1925, 8060] {
              let rExtra = probePortWithFallback(ip: ip, port: extraPort, en0Index: en0Index, timeoutMs: 180)
              if rExtra.open {
                lock.lock()
                openSmartTv.insert("\(ip):\(extraPort)")
                anyLanTrafficAllowed = true
                lock.unlock()
                matchedSmart = true
                break
              }
            }
            if matchedSmart { break }
          }
        }

        if !matchedSmart {
          let r8008 = probePortWithFallback(ip: ip, port: 8008, en0Index: en0Index, timeoutMs: hostIsAlive ? 220 : 130)
          if r8008.open {
            lock.lock()
            open8008.insert(ip)
            anyLanTrafficAllowed = true
            lock.unlock()
          }
        }
      }
    }

    let isPermissionDenied = open5555.isEmpty && open6466.isEmpty && openSmartTv.isEmpty && open8008.isEmpty && !anyLanTrafficAllowed && permissionDeniedCount >= 3
    return [
      "open5555": Array(open5555),
      "open6466": Array(open6466),
      "open8008": Array(open8008),
      "openSmartTv": Array(openSmartTv),
      "wifiIp": wifiIp,
      "subnetPrefix": prefix,
      "permissionDenied": isPermissionDenied,
      "errno": Int(lastPermissionErrno)
    ]
  }

  private static func buildAdbPacket(command: UInt32, arg0: UInt32, arg1: UInt32, payload: [UInt8]) -> [UInt8] {
    var sum: UInt32 = 0
    for b in payload {
      sum = sum &+ UInt32(b)
    }
    let magic = command ^ 0xFFFFFFFF
    var header = [UInt8](repeating: 0, count: 24)
    func putU32(_ offset: Int, _ val: UInt32) {
      header[offset] = UInt8(val & 0xFF)
      header[offset + 1] = UInt8((val >> 8) & 0xFF)
      header[offset + 2] = UInt8((val >> 16) & 0xFF)
      header[offset + 3] = UInt8((val >> 24) & 0xFF)
    }
    putU32(0, command)
    putU32(4, arg0)
    putU32(8, arg1)
    putU32(12, UInt32(payload.count))
    putU32(16, sum)
    putU32(20, magic)
    return header + payload
  }

  private static func readExact(fd: Int32, count: Int) -> [UInt8]? {
    if count == 0 { return [] }
    var buffer = [UInt8](repeating: 0, count: count)
    var offset = 0
    while offset < count {
      let n = buffer.withUnsafeMutableBytes { rawPtr -> Int in
        guard let base = rawPtr.baseAddress else { return -1 }
        return recv(fd, base.advanced(by: offset), count - offset, 0)
      }
      if n <= 0 {
        return nil
      }
      offset += n
    }
    return buffer
  }

  private static func writeAll(fd: Int32, bytes: [UInt8]) -> Bool {
    var offset = 0
    while offset < bytes.count {
      let n = bytes.withUnsafeBytes { rawPtr -> Int in
        guard let base = rawPtr.baseAddress else { return -1 }
        return send(fd, base.advanced(by: offset), bytes.count - offset, 0)
      }
      if n <= 0 {
        return false
      }
      offset += n
    }
    return true
  }

  private static func parseU32LE(_ bytes: [UInt8], _ offset: Int) -> UInt32 {
    return UInt32(bytes[offset])
      | (UInt32(bytes[offset + 1]) << 8)
      | (UInt32(bytes[offset + 2]) << 16)
      | (UInt32(bytes[offset + 3]) << 24)
  }

  private static func executeNativeAdbCommand(
    ip: String,
    port: UInt16,
    shellCommand: String,
    timeoutMs: Int32
  ) -> [String: Any] {
    let en0Index = if_nametoindex("en0")
    var conn = tcpConnectBound(ip: ip, port: port, en0Index: en0Index, timeoutMs: timeoutMs)
    if conn.fd < 0 {
      usleep(120_000)
      conn = tcpConnectBound(ip: ip, port: port, en0Index: en0Index, timeoutMs: max(timeoutMs, 1400))
    }
    if conn.fd < 0 && en0Index > 0 {
      conn = tcpConnectBound(ip: ip, port: port, en0Index: 0, timeoutMs: 1200)
    }
    guard conn.fd >= 0 else {
      let isPerm = (conn.errCode == EPERM || conn.errCode == EACCES)
      return [
        "ok": false,
        "permissionDenied": isPerm,
        "errno": Int(conn.errCode)
      ]
    }

    let fd = conn.fd
    defer { close(fd) }

    let cnxnPayload = Array("host::cuedeck\0".utf8)
    let cnxnPkt = buildAdbPacket(command: 0x4e584e43, arg0: 0x01000000, arg1: 4096, payload: cnxnPayload)
    guard writeAll(fd: fd, bytes: cnxnPkt),
          let hdr = readExact(fd: fd, count: 24) else {
      return ["ok": false, "errno": Int(ETIMEDOUT)]
    }

    let cmd = parseU32LE(hdr, 0)
    let len = Int(parseU32LE(hdr, 12))
    let body = (len > 0 && len <= 65536) ? (readExact(fd: fd, count: len) ?? []) : []

    if cmd == 0x48545541 { // AUTH required
      return [
        "ok": false,
        "requiresRsaAuth": true
      ]
    }

    guard cmd == 0x4e584e43 else {
      return ["ok": false]
    }

    let banner = String(decoding: body, as: UTF8.self)
    if shellCommand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      return [
        "ok": true,
        "output": "",
        "banner": banner
      ]
    }

    let openPayload = Array("shell:\(shellCommand)\0".utf8)
    let openPkt = buildAdbPacket(command: 0x4e45504f, arg0: 1, arg1: 0, payload: openPayload)
    guard writeAll(fd: fd, bytes: openPkt) else {
      return ["ok": false]
    }

    var collected = [UInt8]()
    for _ in 0..<64 {
      guard let shdr = readExact(fd: fd, count: 24) else { break }
      let scmd = parseU32LE(shdr, 0)
      let sarg0 = parseU32LE(shdr, 4)
      let slen = Int(parseU32LE(shdr, 12))
      let sbody = (slen > 0 && slen <= 65536) ? (readExact(fd: fd, count: slen) ?? []) : []

      if scmd == 0x45545257 { // WRTE
        if collected.count < 8192 {
          collected.append(contentsOf: sbody)
        }
        let okayPkt = buildAdbPacket(command: 0x59414b4f, arg0: 1, arg1: sarg0, payload: [])
        _ = writeAll(fd: fd, bytes: okayPkt)
      } else if scmd == 0x45534c43 { // CLSE
        let clsePkt = buildAdbPacket(command: 0x45534c43, arg0: 1, arg1: sarg0, payload: [])
        _ = writeAll(fd: fd, bytes: clsePkt)
        break
      }
    }

    let outStr = String(decoding: collected, as: UTF8.self)
    return [
      "ok": true,
      "output": outStr,
      "banner": banner
    ]
  }
}
