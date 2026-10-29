import Flutter
import UIKit
import Foundation
import Darwin

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var netServiceBrowsers: [NetServiceBrowser] = []

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
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
      let preferredIp = (args?["preferredIp"] as? String) ?? "192.168.1.125"
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
    var permissionDeniedCount = 0
    var lastPermissionErrno: Int32 = 0

    // 1. Two-stage warmup + probe on preferredIp first
    if !preferredIp.isEmpty {
      let warm = probePortWithFallback(ip: preferredIp, port: 5555, en0Index: en0Index, timeoutMs: 420)
      if warm.open {
        open5555.insert(preferredIp)
      } else {
        if warm.errCode == EHOSTUNREACH || warm.errCode == EPERM || warm.errCode == EACCES {
          permissionDeniedCount += 1
          lastPermissionErrno = warm.errCode
        }
        usleep(120_000)
        let retry = probePortWithFallback(ip: preferredIp, port: 5555, en0Index: en0Index, timeoutMs: 1100)
        if retry.open {
          open5555.insert(preferredIp)
        }
      }
      let p6466 = probePortWithFallback(ip: preferredIp, port: 6466, en0Index: en0Index, timeoutMs: 500)
      if p6466.open {
        open6466.insert(preferredIp)
      }
    }

    // 2. Build ordered octet list: priority DHCP range (95..160) first, then remaining (2..94, 161..254)
    var orderedOctets: [Int] = Array(95...160)
    orderedOctets.append(contentsOf: Array(2...94))
    orderedOctets.append(contentsOf: Array(161...254))

    let priorityOctets = Array(95...160)
    // Fast ARP warmup on priority range (95..160) in chunks of 22
    let chunkSize = 22
    for start in stride(from: 0, to: priorityOctets.count, by: chunkSize) {
      let end = min(start + chunkSize, priorityOctets.count)
      let slice = Array(priorityOctets[start..<end])
      DispatchQueue.concurrentPerform(iterations: slice.count) { idx in
        let ip = "\(prefix).\(slice[idx])"
        if ip == wifiIp { return }
        let res = probePortWithFallback(ip: ip, port: 5555, en0Index: en0Index, timeoutMs: 260)
        if res.open {
          lock.lock()
          open5555.insert(ip)
          lock.unlock()
        } else if res.errCode == EHOSTUNREACH || res.errCode == EPERM || res.errCode == EACCES {
          lock.lock()
          permissionDeniedCount += 1
          lastPermissionErrno = res.errCode
          lock.unlock()
        }
      }
    }

    usleep(140_000) // Allow Wi-Fi ARP replies from sleeping TVs to settle

    // Full scan across all 253 octets in chunks of 24
    let fullChunkSize = 24
    for start in stride(from: 0, to: orderedOctets.count, by: fullChunkSize) {
      let end = min(start + fullChunkSize, orderedOctets.count)
      let slice = Array(orderedOctets[start..<end])
      let isPrioritySlice = start < 66
      let timeout: Int32 = isPrioritySlice ? 780 : 420

      DispatchQueue.concurrentPerform(iterations: slice.count) { idx in
        let ip = "\(prefix).\(slice[idx])"
        if ip == wifiIp { return }

        lock.lock()
        let alreadyFound = open5555.contains(ip)
        lock.unlock()
        if !alreadyFound {
          let r5555 = probePortWithFallback(ip: ip, port: 5555, en0Index: en0Index, timeoutMs: timeout)
          if r5555.open {
            lock.lock()
            open5555.insert(ip)
            lock.unlock()
          }
        }

        if isPrioritySlice {
          let r6466 = probePortWithFallback(ip: ip, port: 6466, en0Index: en0Index, timeoutMs: 360)
          if r6466.open {
            lock.lock()
            open6466.insert(ip)
            lock.unlock()
          }
        }
      }
    }

    let isPermissionDenied = open5555.isEmpty && open6466.isEmpty && permissionDeniedCount >= 3
    return [
      "open5555": Array(open5555),
      "open6466": Array(open6466),
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
      let isPerm = (conn.errCode == EHOSTUNREACH || conn.errCode == EPERM || conn.errCode == EACCES)
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
