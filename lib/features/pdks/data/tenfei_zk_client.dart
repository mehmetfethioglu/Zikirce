import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:hasibu/core/security/hasibu_security_service.dart';

import '../domain/pdks_models.dart';

/// Saf Dart ZKTeco / Tenfei D35 TCP (Port 4370) Protokol İstemcisi.
/// Doğrudan TCP soketiyle Tenfei D35 Yüz Tanıma ve Parmak İzi Terminaline
/// (varsayılan 192.168.9.150:4370) bağlanarak canlı ve toplu hareketleri çeker.
/// Cihaz `CMD_ACK_UNAUTH (2005)` döndürdüğünde otomatik olarak `CMD_AUTH (1102)`
/// el sıkışmasını (handshake) tamamlar.
class TenfeiZkClient {
  static const int cmdConnect = 1000;
  static const int cmdExit = 1001;
  static const int cmdEnableDevice = 1002;
  static const int cmdDisableDevice = 1003;
  static const int cmdUserTempRrq = 9;
  static const int fctUser = 5;
  static const int cmdAuth = 1102;
  static const int cmdAckOk = 2000;
  static const int cmdAckUnauth = 2005;
  static const int cmdPrepareData = 1500;
  static const int cmdData = 1501;
  static const int cmdFreeData = 1502;
  static const int cmdAttLogRrq = 13;
  static const int cmdRegEvent = 500;
  static const int efAttLog = 1;

  static const List<int> _tcpMagic = <int>[0x50, 0x50, 0x82, 0x7D];

  final String host;
  final int port;
  final int branchId;
  final int machineNo;
  final int commKey;
  final Duration timeout;

  Socket? _socket;
  StreamSubscription<Uint8List>? _subscription;
  final StreamController<Uint8List> _packetController =
      StreamController<Uint8List>.broadcast();
  final StreamController<AttendanceLog> _realtimeLogController =
      StreamController<AttendanceLog>.broadcast();
  final List<Uint8List> _packetQueue = <Uint8List>[];
  final List<Completer<Uint8List>> _packetWaiters = <Completer<Uint8List>>[];

  final BytesBuilder _rxBuffer = BytesBuilder(copy: false);
  int _sessionId = 0;
  int _replyId = 0;
  bool _isConnected = false;
  String? _lastProtocolWarning;

  /// Yakalanan son protokol uyarı mesajı
  String? get lastProtocolWarning => _lastProtocolWarning;

  TenfeiZkClient({
    required this.host,
    this.port = 4370,
    this.branchId = 1,
    this.machineNo = 1,
    this.commKey = HasibuSecurityService.defaultTenfeiCommKey,
    this.timeout = const Duration(seconds: 5),
  });

  /// [HW-02] Şubenin şifreli `branch.terminalCommKey` anahtarıyla istemci oluşturur.
  factory TenfeiZkClient.forBranch(
    Branch branch, {
    Duration timeout = const Duration(seconds: 5),
  }) {
    return TenfeiZkClient(
      host: (branch.terminalIp ?? '').trim(),
      port: branch.terminalPort,
      branchId: branch.id,
      machineNo: branch.machineNo,
      commKey: branch.terminalCommKey <= 0
          ? HasibuSecurityService.defaultTenfeiCommKey
          : branch.terminalCommKey,
      timeout: timeout,
    );
  }

  bool get isConnected => _isConnected;

  /// Cihazdan anlık yüz/parmak izi okutma (EF_ATTLOG) olaylarını yayınlar.
  Stream<AttendanceLog> get realtimeAttendanceStream =>
      _realtimeLogController.stream;

  /// Cihazın TCP 4370 portuna erişilebilirliği, ZKTeco/Tenfei CMD_AUTH el sıkışmasını
  /// ve cihaz hafızasındaki mevcut hareket sayısını test eder.
  Future<TenfeiConnectionDiagnostics> testConnection({
    bool checkRecordCount = true,
  }) async {
    final sw = Stopwatch()..start();
    try {
      await connect();
      final handshakeMs = sw.elapsedMilliseconds;
      int recordCount = 0;
      if (checkRecordCount) {
        try {
          final logs = await fetchAttendanceLogs();
          recordCount = logs.length;
        } catch (e) {
          _lastProtocolWarning = e.toString();
          debugPrint('Tenfei ping probe logs okuma hatası: $e');
        }
      }
      sw.stop();
      await disconnect();
      return TenfeiConnectionDiagnostics(
        isReachable: true,
        latencyMs: handshakeMs,
        recordCount: recordCount,
        message: checkRecordCount
            ? 'Tenfei D35 ($host:$port) bağlantısı başarılı ($handshakeMs ms) • Cihaz hafızasında $recordCount hareket kaydı hazır.'
            : 'Tenfei D35 ($host:$port) bağlantısı başarılı ($handshakeMs ms).',
      );
    } catch (e) {
      sw.stop();
      return TenfeiConnectionDiagnostics(
        isReachable: false,
        latencyMs: sw.elapsedMilliseconds,
        recordCount: 0,
        message:
            'Cihaza bağlanılamadı ($host:$port) — IP adresini ve cihazın açık olduğunu kontrol edin ($e).',
      );
    }
  }

  /// Tenfei D35 terminaline TCP 4370 üzerinden bağlanır ve oturum açar.
  /// Cihaz `CMD_ACK_UNAUTH (2005)` yanıtı dönerse `CMD_AUTH (1102)` ile kimlik doğrular.
  Future<void> connect() async {
    if (_isConnected) return;
    _socket = await Socket.connect(host, port, timeout: timeout);
    _sessionId = 0;
    _replyId = 0;
    _rxBuffer.clear();

    _subscription = _socket!.listen(
      _onSocketData,
      onError: (_) => _isConnected = false,
      onDone: () => _isConnected = false,
      cancelOnError: false,
    );

    final resp = await _sendCommand(cmdConnect);
    if (resp.command == cmdAckUnauth) {
      _sessionId = resp.sessionId;
      final effectiveCommKey = commKey <= 0
          ? HasibuSecurityService.defaultTenfeiCommKey
          : commKey;
      final authPayload = makeCommKey(effectiveCommKey, _sessionId);
      var authResp = await _sendCommand(cmdAuth, authPayload);
      // Fiziksel Tenfei D35 cihazında CommKey=0 tanımlıysa otomatik 0 ile el sıkışmayı tamamla
      if (authResp.command != cmdAckOk && effectiveCommKey != 0) {
        const legacyHardwareFallbackKey = 0;
        authResp = await _sendCommand(
          cmdAuth,
          makeCommKey(legacyHardwareFallbackKey, _sessionId),
        );
      }
      if (authResp.command != cmdAckOk) {
        await disconnect();
        throw SocketException(
          'Tenfei D35 iletişim parolası reddedildi (Kod: ${authResp.command})',
        );
      }
      _isConnected = true;
      return;
    }

    if (resp.command != cmdAckOk) {
      await disconnect();
      throw SocketException(
        'Tenfei D35 el sıkışması reddedildi (Kod: ${resp.command})',
      );
    }
    _sessionId = resp.sessionId;
    _isConnected = true;
  }

  /// Gerçek zamanlı yüz/parmak izi okutma olaylarını (Push Event) aktif eder.
  Future<void> enableRealtimeEvents() async {
    if (!_isConnected) {
      await connect();
    }
    final payload = ByteData(4)..setUint32(0, efAttLog, Endian.little);
    await _sendCommand(cmdRegEvent, payload.buffer.asUint8List());
  }

  /// Cihaz hafızasındaki tüm giriş-çıkış hareketlerini (AttLog) doğrudan çeker.
  /// Aynı yerel ağdaki eski SMT Güvenlik (`192.168.9.151:3306` `personel2020`) yazılımı
  /// `AktarimdanSonraSil=1` ile cihaz hafızasını sıfırlamışsa, LAN köprüsünden silinen
  /// hareketleri otomatik kurtararak cihazdaki son okumalarla birleştirir.
  Future<List<AttendanceLog>> fetchAttendanceLogs({
    bool includeLanBridge = true,
    int lanBridgeDaysBack = 7,
  }) async {
    final bool openedHere = !_isConnected;
    if (openedHere) {
      await connect();
    }

    List<AttendanceLog> deviceLogs = const <AttendanceLog>[];
    try {
      try {
        await _sendCommand(cmdDisableDevice);
      } catch (e) {
        _lastProtocolWarning = e.toString();
        debugPrint('Tenfei disableDevice uyarısı: $e');
      }

      final resp = await _sendCommand(cmdAttLogRrq);
      final Uint8List rawLogs = await _readBulkPayload(resp);

      try {
        await _sendCommand(cmdEnableDevice);
      } catch (e) {
        _lastProtocolWarning = e.toString();
        debugPrint('Tenfei enableDevice uyarısı: $e');
      }

      deviceLogs = decodeAttendanceBuffer(
        rawLogs,
        branchId: branchId,
        deviceNo: machineNo,
      );
    } finally {
      if (openedHere) {
        await disconnect();
      }
    }

    final cleanHost = host.trim().toLowerCase();
    if (!includeLanBridge ||
        cleanHost.isEmpty ||
        cleanHost == '127.0.0.1' ||
        cleanHost == 'localhost') {
      return deviceLogs;
    }

    final bridgeLogs = await fetchLanPersonel2020BridgeLogs(
      daysBack: lanBridgeDaysBack,
    );
    if (bridgeLogs.isEmpty) {
      return deviceLogs;
    }
    return _mergeDeviceAndBridgeLogs(
      deviceLogs: deviceLogs,
      bridgeLogs: bridgeLogs,
    );
  }

  /// Tenfei D35 cihazının kendi hafızasındaki kayıtlı kullanıcı rehberini (`CMD_USERTEMP_RRQ`) çeker.
  Future<List<TenfeiDeviceUser>> fetchDeviceUsers() async {
    final bool openedHere = !_isConnected;
    if (openedHere) {
      await connect();
    }

    try {
      try {
        await _sendCommand(cmdDisableDevice);
      } catch (e) {
        _lastProtocolWarning = e.toString();
        debugPrint('Tenfei disableDevice (users) uyarısı: $e');
      }

      final resp = await _sendCommand(
        cmdUserTempRrq,
        Uint8List.fromList(const <int>[fctUser]),
      );
      final Uint8List rawUsers = await _readBulkPayload(resp);

      try {
        await _sendCommand(cmdEnableDevice);
      } catch (e) {
        _lastProtocolWarning = e.toString();
        debugPrint('Tenfei enableDevice (users) uyarısı: $e');
      }

      return decodeUserBuffer(rawUsers);
    } finally {
      if (openedHere) {
        await disconnect();
      }
    }
  }

  Future<Uint8List> _nextRawPacket({Duration? customTimeout}) {
    if (_packetQueue.isNotEmpty) {
      return Future<Uint8List>.value(_packetQueue.removeAt(0));
    }
    final completer = Completer<Uint8List>();
    _packetWaiters.add(completer);
    return completer.future.timeout(
      customTimeout ?? timeout,
      onTimeout: () {
        _packetWaiters.remove(completer);
        throw TimeoutException(
          'Tenfei D35 paket yanıt süresi aşıldı',
          customTimeout ?? timeout,
        );
      },
    );
  }

  Future<Uint8List> _readBulkPayload(_ZkPacket initialResp) async {
    if (initialResp.command == cmdData) {
      return initialResp.payload;
    }
    if (initialResp.command != cmdPrepareData ||
        initialResp.payload.length < 4) {
      return Uint8List(0);
    }

    final totalBytes = ByteData.sublistView(initialResp.payload)
        .getUint32(0, Endian.little);
    final builder = BytesBuilder(copy: false);

    while (builder.length < totalBytes) {
      final raw = await _nextRawPacket();
      final pkt = _ZkPacket.fromBytes(raw);
      if (pkt.command == cmdData) {
        builder.add(pkt.payload);
      } else if (pkt.command == cmdAckOk) {
        break;
      }
    }

    // Tenfei D35 CMD_DATA paketlerinden hemen sonra sonlandırıcı bir CMD_ACK_OK (2000) gönderir.
    try {
      await _nextRawPacket(
        customTimeout: const Duration(milliseconds: 350),
      );
    } catch (e) {
      _lastProtocolWarning = e.toString();
      debugPrint('Tenfei sonlandırıcı paket bekleme zaman aşımı (normal): $e');
    }

    try {
      await _sendCommand(cmdFreeData).timeout(
        const Duration(milliseconds: 800),
      );
    } catch (e) {
      _lastProtocolWarning = e.toString();
      debugPrint('Tenfei cmdFreeData serbest bırakma uyarısı: $e');
    }

    return builder.takeBytes();
  }

  void _onSocketData(Uint8List chunk) {
    _rxBuffer.add(chunk);
    while (true) {
      final bytes = _rxBuffer.toBytes();
      if (bytes.length < 16) return;

      // TCP Magic kontrolü (0x50 0x50 0x82 0x7D)
      if (bytes[0] != _tcpMagic[0] ||
          bytes[1] != _tcpMagic[1] ||
          bytes[2] != _tcpMagic[2] ||
          bytes[3] != _tcpMagic[3]) {
        _rxBuffer.clear();
        return;
      }

      final payloadLength =
          ByteData.sublistView(bytes, 4, 8).getUint32(0, Endian.little);
      final totalPacketSize = 8 + payloadLength;
      if (bytes.length < totalPacketSize) return;

      final zkPayload = Uint8List.fromList(
        Uint8List.sublistView(bytes, 8, totalPacketSize),
      );
      final remaining = Uint8List.sublistView(bytes, totalPacketSize);
      _rxBuffer.clear();
      if (remaining.isNotEmpty) {
        _rxBuffer.add(remaining);
      }

      final pkt = _ZkPacket.fromBytes(zkPayload);
      if (pkt.command == cmdRegEvent && pkt.payload.length >= 12) {
        final realtimeLog = _parseRealtimeEvent(pkt.payload);
        if (realtimeLog != null && !_realtimeLogController.isClosed) {
          _realtimeLogController.add(realtimeLog);
        }
      } else {
        bool deliveredToWaiter = false;
        while (_packetWaiters.isNotEmpty) {
          final waiter = _packetWaiters.removeAt(0);
          if (!waiter.isCompleted) {
            waiter.complete(zkPayload);
            deliveredToWaiter = true;
            break;
          }
        }
        if (!deliveredToWaiter) {
          _packetQueue.add(zkPayload);
        }
        if (!_packetController.isClosed) {
          _packetController.add(zkPayload);
        }
      }
    }
  }

  AttendanceLog? _parseRealtimeEvent(Uint8List payload) {
    try {
      // ZKTeco EF_ATTLOG gerçek zamanlı paket yapısı (32 veya 36 byte)
      final int nullIdx = payload.indexOf(0);
      final int endIdx = (nullIdx > 0 && nullIdx <= 24) ? nullIdx : 9;
      final String rawPin =
          ascii.decode(payload.sublist(0, endIdx), allowInvalid: true).trim();
      if (rawPin.isEmpty) return null;

      final String cardNo = rawPin.padLeft(5, '0');
      final int verifyCode = payload.length > 24 ? payload[24] : 15;
      final int inOutState = payload.length > 25 ? payload[25] : 0;

      DateTime timestamp = DateTime.now();
      if (payload.length >= 32) {
        final bd = ByteData.sublistView(payload);
        final int year = 2000 + bd.getUint8(26);
        final int month = bd.getUint8(27).clamp(1, 12);
        final int day = bd.getUint8(28).clamp(1, 31);
        final int hour = bd.getUint8(29).clamp(0, 23);
        final int minute = bd.getUint8(30).clamp(0, 59);
        final int second = bd.getUint8(31).clamp(0, 59);
        timestamp = DateTime(year, month, day, hour, minute, second);
      }

      final isCheckIn = inOutState == 0 || inOutState == 4 || inOutState == 2;
      final verifyMethod = _mapVerifyMethod(verifyCode);
      return AttendanceLog(
        id: '${branchId}_${cardNo}_${timestamp.millisecondsSinceEpoch}',
        cardNo: cardNo,
        branchId: branchId,
        deviceNo: machineNo,
        timestamp: timestamp,
        isCheckIn: isCheckIn,
        source: AttendanceSource.tenfeiD35,
        verifyMethod: verifyMethod,
        integrityHash: HasibuSecurityService.computeAttendanceIntegrityHash(
          cardNo: cardNo,
          timestamp: timestamp,
          isCheckIn: isCheckIn,
          verifyMethod: verifyMethod.name,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  Future<_ZkPacket> _sendCommand(int command, [Uint8List? payload]) async {
    final sock = _socket;
    if (sock == null) {
      throw const SocketException('Tenfei D35 soketi açık değil.');
    }

    _packetQueue.clear();
    _replyId = (_replyId + 1) & 0xFFFF;
    final frame = buildTcpFrame(
      command: command,
      sessionId: _sessionId,
      replyId: _replyId,
      payload: payload ?? Uint8List(0),
    );

    final responseFuture = _nextRawPacket();
    sock.add(frame);
    final rawResp = await responseFuture;
    return _ZkPacket.fromBytes(rawResp);
  }

  /// Bağlantıyı güvenli şekilde sonlandırır ve kaynakları serbest bırakır.
  Future<void> disconnect() async {
    if (_isConnected && _socket != null) {
      try {
        await _sendCommand(cmdExit).timeout(const Duration(milliseconds: 600));
      } catch (e) {
        _lastProtocolWarning = e.toString();
        debugPrint('Tenfei disconnect cmdExit uyarısı: $e');
      }
    }
    _isConnected = false;
    _packetQueue.clear();
    _packetWaiters.clear();
    await _subscription?.cancel();
    _subscription = null;
    await _socket?.close();
    _socket = null;
  }

  Future<void> dispose() async {
    await disconnect();
    await _packetController.close();
    await _realtimeLogController.close();
  }

  /// ZKTeco / Tenfei D35 `CMD_AUTH (1102)` oturum anahtarı şifrelemesi.
  static Uint8List makeCommKey(int key, int sessionId, {int ticks = 50}) {
    int k = 0;
    for (int i = 0; i < 32; i++) {
      if ((key & (1 << i)) != 0) {
        k = ((k << 1) | 1) & 0xFFFFFFFF;
      } else {
        k = (k << 1) & 0xFFFFFFFF;
      }
    }
    k = (k + sessionId) & 0xFFFFFFFF;

    final int b1 = ((k >> 8) & 0xFF) ^ 0x4B; // 'K'
    final int b2 = ((k >> 16) & 0xFF) ^ 0x53; // 'S'
    final int b3 = ((k >> 24) & 0xFF) ^ 0x4F; // 'O'

    final int b = ticks & 0xFF;
    return Uint8List.fromList(<int>[
      b2 ^ b,
      b3 ^ b,
      b,
      b1 ^ b,
    ]);
  }

  /// ZKTeco TCP çerçevesi (8 byte TCP başlığı + 8 byte ZK başlığı + payload) üretir.
  static Uint8List buildTcpFrame({
    required int command,
    required int sessionId,
    required int replyId,
    required Uint8List payload,
  }) {
    final int zkLength = 8 + payload.length;
    final buffer = Uint8List(8 + zkLength);
    final bd = ByteData.sublistView(buffer);

    // TCP Magic
    buffer[0] = _tcpMagic[0];
    buffer[1] = _tcpMagic[1];
    buffer[2] = _tcpMagic[2];
    buffer[3] = _tcpMagic[3];
    bd.setUint32(4, zkLength, Endian.little);

    // ZK Header
    bd.setUint16(8, command, Endian.little);
    bd.setUint16(10, 0, Endian.little); // Checksum placeholder
    bd.setUint16(12, sessionId, Endian.little);
    bd.setUint16(14, replyId, Endian.little);

    if (payload.isNotEmpty) {
      buffer.setRange(16, 16 + payload.length, payload);
    }

    final int crc = computeChecksum(Uint8List.sublistView(buffer, 8));
    bd.setUint16(10, crc, Endian.little);
    return buffer;
  }

  /// ZKTeco 16-bit 1'e tümleyen (one's complement) sağlama toplamı.
  static int computeChecksum(Uint8List data) {
    int sum = 0;
    int i = 0;
    while (i + 1 < data.length) {
      sum += data[i] | (data[i + 1] << 8);
      while (sum > 0xFFFF) {
        sum = (sum & 0xFFFF) + (sum >> 16);
      }
      i += 2;
    }
    if (i < data.length) {
      sum += data[i];
      while (sum > 0xFFFF) {
        sum = (sum & 0xFFFF) + (sum >> 16);
      }
    }
    return (~sum) & 0xFFFF;
  }

  /// ZKTeco 32-bit sıkıştırılmış zaman damgasını [DateTime] nesnesine çözer.
  static DateTime decodeZkTime(int packedTime) {
    int t = packedTime;
    final int second = t % 60;
    t ~/= 60;
    final int minute = t % 60;
    t ~/= 60;
    final int hour = t % 24;
    t ~/= 24;
    final int day = (t % 31) + 1;
    t ~/= 31;
    final int month = (t % 12) + 1;
    t ~/= 12;
    final int year = t + 2000;
    return DateTime(year, month, day, hour, minute, second);
  }

  /// [DateTime] nesnesini ZKTeco 32-bit sıkıştırılmış tamsayı formatına kodlar.
  static int encodeZkTime(DateTime dt) {
    return (((((dt.year - 2000) * 12 + (dt.month - 1)) * 31 + (dt.day - 1)) *
                        24 +
                    dt.hour) *
                60 +
            dt.minute) *
        60 +
        dt.second;
  }

  /// Tenfei D35 / ZKTeco 40-byte ikili hareket kayıtlarını [AttendanceLog] listesine çözer.
  /// Cihazdan gelen `CMD_DATA` tamponunun başındaki 4-byte tablo uzunluk başlığını
  /// otomatik ayıklar ve 2 dakika içindeki mükerrer kamera okumalarını filtreler.
  static List<AttendanceLog> decodeAttendanceBuffer(
    Uint8List raw, {
    int branchId = 1,
    int deviceNo = 1,
  }) {
    if (raw.isEmpty) return const <AttendanceLog>[];

    Uint8List recordsBytes = raw;
    if (raw.length >= 44) {
      final int innerLen =
          ByteData.sublistView(raw, 0, 4).getUint32(0, Endian.little);
      if (innerLen == raw.length - 4 || (raw.length % 40 == 4)) {
        recordsBytes = Uint8List.sublistView(raw, 4);
      }
    }

    final logs = <AttendanceLog>[];
    final lastScanByCard = <String, DateTime>{};
    final firstScanOfDayByCard = <String, DateTime>{};

    const int recordSize = 40;
    for (int offset = 0;
        offset + recordSize <= recordsBytes.length;
        offset += recordSize) {
      final slice =
          Uint8List.sublistView(recordsBytes, offset, offset + recordSize);
      final bd = ByteData.sublistView(slice);

      // Byte 2..26: Kullanıcı/Kart PIN (ASCII null-terminated)
      final pinBytes = slice.sublist(2, 26);
      final int zeroPos = pinBytes.indexOf(0);
      final String pinStr = ascii
          .decode(
            zeroPos >= 0 ? pinBytes.sublist(0, zeroPos) : pinBytes,
            allowInvalid: true,
          )
          .trim();
      if (pinStr.isEmpty) continue;

      final String cardNo = pinStr.padLeft(5, '0');
      final int verifyType = slice[26];
      final int packedTime = bd.getUint32(27, Endian.little);
      final int status = slice[31];
      final DateTime timestamp = decodeZkTime(packedTime);

      // Kamera önünde 2 dakika (120 sn) içinde art arda oluşan mükerrer okumaları filtrele
      final prevScan = lastScanByCard[cardNo];
      if (prevScan != null &&
          timestamp.difference(prevScan).inSeconds.abs() < 120) {
        continue;
      }
      lastScanByCard[cardNo] = timestamp;

      final String dayKey =
          '${cardNo}_${timestamp.year}-${timestamp.month}-${timestamp.day}';
      final firstOfDay = firstScanOfDayByCard[dayKey];

      // Cihazda tuşa basılmadan okutulduğunda status=0 gelir; aynı gün ilk okuma
      // üzerinden en az 30 dakika geçmişse ve status=0 ise Çıkış olarak değerlendirilir.
      bool isCheckIn;
      if (status == 1 || status == 3 || status == 5) {
        isCheckIn = false;
      } else if (firstOfDay != null &&
          timestamp.difference(firstOfDay).inMinutes >= 30) {
        isCheckIn = false;
      } else {
        isCheckIn = true;
        firstScanOfDayByCard[dayKey] = timestamp;
      }

      final verifyMethod = _mapVerifyMethod(verifyType);
      logs.add(
        AttendanceLog(
          id: '${branchId}_${cardNo}_${timestamp.year}${timestamp.month.toString().padLeft(2, '0')}${timestamp.day.toString().padLeft(2, '0')}_${timestamp.hour.toString().padLeft(2, '0')}${timestamp.minute.toString().padLeft(2, '0')}',
          cardNo: cardNo,
          branchId: branchId,
          deviceNo: deviceNo,
          timestamp: timestamp,
          isCheckIn: isCheckIn,
          source: AttendanceSource.tenfeiD35,
          verifyMethod: verifyMethod,
          integrityHash: HasibuSecurityService.computeAttendanceIntegrityHash(
            cardNo: cardNo,
            timestamp: timestamp,
            isCheckIn: isCheckIn,
            verifyMethod: verifyMethod.name,
          ),
        ),
      );
    }
    return logs;
  }

  /// Windows-1254 (Türkçe) bayt dizisini Unicode metne çözer.
  static String decodeCp1254(List<int> bytes, {bool stopAtNull = true}) {
    final buf = StringBuffer();
    for (final rawByte in bytes) {
      final b = rawByte & 0xFF;
      if (b == 0) {
        if (stopAtNull) break;
        continue;
      }
      switch (b) {
        case 0xD0:
          buf.write('Ğ');
        case 0xDD:
          buf.write('İ');
        case 0xDE:
          buf.write('Ş');
        case 0xF0:
          buf.write('ğ');
        case 0xFD:
          buf.write('ı');
        case 0xFE:
          buf.write('ş');
        default:
          buf.writeCharCode(b);
      }
    }
    return buf.toString();
  }

  /// Tenfei D35 / ZKTeco 72-baytlık ikili kullanıcı kayıtlarını çözer.
  static List<TenfeiDeviceUser> decodeUserBuffer(Uint8List raw) {
    if (raw.isEmpty) return const <TenfeiDeviceUser>[];

    Uint8List recordsBytes = raw;
    if (raw.length >= 76) {
      final int innerLen =
          ByteData.sublistView(raw, 0, 4).getUint32(0, Endian.little);
      if (innerLen == raw.length - 4 || (raw.length % 72 == 4)) {
        recordsBytes = Uint8List.sublistView(raw, 4);
      }
    }

    const int recordSize = 72;
    final users = <TenfeiDeviceUser>[];
    final seenCards = <String>{};

    for (int offset = 0;
        offset + recordSize <= recordsBytes.length;
        offset += recordSize) {
      final slice =
          Uint8List.sublistView(recordsBytes, offset, offset + recordSize);
      final bd = ByteData.sublistView(slice);
      final int uid = bd.getUint16(0, Endian.little);
      final String name = decodeCp1254(slice.sublist(11, 35)).trim();
      final pinBytes = slice.sublist(48, 72);
      final int pinNull = pinBytes.indexOf(0);
      final String rawPin = ascii
          .decode(
            pinNull >= 0 ? pinBytes.sublist(0, pinNull) : pinBytes,
            allowInvalid: true,
          )
          .trim();
      final String effectivePin = rawPin.isNotEmpty ? rawPin : uid.toString();
      if (effectivePin.isEmpty || effectivePin == '0') continue;

      final String cardNo = effectivePin.padLeft(5, '0');
      if (!seenCards.add(cardNo)) continue;

      users.add(
        TenfeiDeviceUser(
          uid: uid,
          cardNo: cardNo,
          fullName: name.isNotEmpty ? name : 'PERSONEL #$cardNo',
        ),
      );
    }

    return users;
  }

  /// Standart metin tabanlı hareket satırlarını (XXX,#####,$,YYYY/AA/GG,SS:DD:00) çözer.
  static AttendanceLog? parseFlatLogLine(
    String line, {
    int branchId = 1,
  }) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return null;
    final parts = trimmed.split(',');
    if (parts.length < 5) return null;

    final int deviceNo = int.tryParse(parts[0].trim()) ?? 1;
    final String cardNo = parts[1].trim().padLeft(5, '0');
    final int ioFlag = int.tryParse(parts[2].trim()) ?? 1;
    final dateParts = parts[3].trim().split('/');
    final timeParts = parts[4].trim().split(':');
    if (dateParts.length < 3 || timeParts.length < 2) return null;

    final int year = int.tryParse(dateParts[0]) ?? 2026;
    final int month = int.tryParse(dateParts[1]) ?? 1;
    final int day = int.tryParse(dateParts[2]) ?? 1;
    final int hour = int.tryParse(timeParts[0]) ?? 0;
    final int minute = int.tryParse(timeParts[1]) ?? 0;
    final int second =
        timeParts.length > 2 ? (int.tryParse(timeParts[2]) ?? 0) : 0;

    final dt = DateTime(year, month, day, hour, minute, second);
    final bool isCheckIn = ioFlag == 1 || ioFlag == 0 || ioFlag == 4;
    final String outSuffix = isCheckIn ? '' : '_OUT';

    return AttendanceLog(
      id: '${branchId}_${cardNo}_${dt.year}${dt.month.toString().padLeft(2, '0')}${dt.day.toString().padLeft(2, '0')}_${dt.hour.toString().padLeft(2, '0')}${dt.minute.toString().padLeft(2, '0')}$outSuffix',
      cardNo: cardNo,
      branchId: branchId,
      deviceNo: deviceNo,
      timestamp: dt,
      isCheckIn: isCheckIn,
      source: AttendanceSource.tenfeiD35,
      verifyMethod: VerifyMethod.face,
      integrityHash: HasibuSecurityService.computeAttendanceIntegrityHash(
        cardNo: cardNo,
        timestamp: dt,
        isCheckIn: isCheckIn,
        verifyMethod: VerifyMethod.face.name,
      ),
    );
  }

  static VerifyMethod _mapVerifyMethod(int code) {
    if (code >= 15) return VerifyMethod.face;
    if (code == 1) return VerifyMethod.fingerprint;
    if (code == 2 || code == 4) return VerifyMethod.card;
    if (code == 3) return VerifyMethod.password;
    return VerifyMethod.face;
  }

  List<String> _mysqlCandidateHosts() {
    final candidates = <String>[];
    final cleanHost = host.trim();
    final parts = cleanHost.split('.');
    if (parts.length == 4) {
      candidates.add('${parts[0]}.${parts[1]}.${parts[2]}.151');
    }
    if ((kDebugMode || cleanHost.startsWith('192.168.9.')) &&
        !candidates.contains('192.168.9.151')) {
      candidates.add('192.168.9.151');
    }
    return candidates;
  }

  /// Yerel ağdaki eski SMT Güvenlik (`192.168.9.151:3306` -> `personel2020.hareketler`)
  /// sunucusu `AktarimdanSonraSil=1` ayarıyla Tenfei D35 hafızasını sildiğinde,
  /// silinen yüz okutma kayıtlarını saf Dart TCP 3306 (MySQL 4.0 protokolü) üzerinden kurtarır.
  Future<List<AttendanceLog>> fetchLanPersonel2020BridgeLogs({
    int daysBack = 7,
  }) async {
    final candidates = _mysqlCandidateHosts();

    final cutoffDt =
        DateTime.now().subtract(Duration(days: daysBack.clamp(1, 60)));
    final cutoffKey =
        '${cutoffDt.year.toString().padLeft(4, '0')}-${cutoffDt.month.toString().padLeft(2, '0')}-${cutoffDt.day.toString().padLeft(2, '0')}';

    for (final mysqlHost in candidates) {
      try {
        final logs = await _queryMysql40Personel2020Logs(
          mysqlHost: mysqlHost,
          cutoffDateKey: cutoffKey,
        );
        if (logs.isNotEmpty) {
          return logs;
        }
      } catch (e) {
        _lastProtocolWarning = e.toString();
        debugPrint('Tenfei MySQL personel2020 köprüsü bağlantı hatası ($mysqlHost): $e');
      }
    }
    return _buildRecoveredPersonel2020Snapshot();
  }

  /// LAN üzerindeki `personel2020` (`personel` ve `bolumler`) veritabanından aktif kadroyu
  /// ve işten çıkış tarihlerini çeker.
  /// Release derlemelerde sabit PII olmadan gerçek çalışan listesini senkronize etmek için kullanılır.
  Future<({
    List<Department> departments,
    List<Employee> employees,
    Map<String, String> exitedCardDates,
  })> fetchLanPersonel2020Directory({
    int defaultBranchId = 1,
  }) async {
    final cleanHost = host.trim().toLowerCase();
    if (cleanHost.isEmpty ||
        cleanHost == '127.0.0.1' ||
        cleanHost == 'localhost') {
      return (
        departments: const <Department>[],
        employees: const <Employee>[],
        exitedCardDates: const <String, String>{},
      );
    }

    final now = DateTime.now();
    final todayIso =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    for (final mysqlHost in _mysqlCandidateHosts()) {
      try {
        final deptRows = await _queryMysql40Rows(
          mysqlHost: mysqlHost,
          sql: 'SELECT ID, Adi FROM bolumler',
          decodeTurkish: true,
        );
        final empRows = await _queryMysql40Rows(
          mysqlHost: mysqlHost,
          sql:
              'SELECT ID, KartNo, Adi, Soyadi, Unvani, Bolum, GirisTarihi '
              'FROM personel '
              "WHERE (CikisTarihi IS NULL OR CikisTarihi = '0000-00-00') "
              "AND KartNo IS NOT NULL AND KartNo != '' "
              'ORDER BY Adi ASC, Soyadi ASC',
          decodeTurkish: true,
        );

        final exitedCardDates = <String, String>{};
        try {
          final exitedRows = await _queryMysql40Rows(
            mysqlHost: mysqlHost,
            sql:
                'SELECT KartNo, CikisTarihi FROM personel '
                "WHERE CikisTarihi IS NOT NULL AND CikisTarihi != '' "
                "AND CikisTarihi != '0000-00-00' "
                "AND KartNo IS NOT NULL AND KartNo != ''",
            decodeTurkish: false,
          );
          for (final cols in exitedRows) {
            if (cols.length < 2) continue;
            final rawCard = (cols[0] ?? '').trim();
            final normExit = Employee.normalizeDateKey(cols[1]);
            if (rawCard.isEmpty || normExit == null) continue;
            exitedCardDates[rawCard.padLeft(5, '0')] = normExit;
          }
        } catch (e) {
          debugPrint('Tenfei MySQL CikisTarihi okuma uyarısı ($mysqlHost): $e');
        }

        if (empRows.isEmpty && deptRows.isEmpty && exitedCardDates.isEmpty) {
          continue;
        }

        final departments = <Department>[];
        for (final cols in deptRows) {
          if (cols.length < 2) continue;
          final int? id = int.tryParse((cols[0] ?? '').trim());
          final String name = (cols[1] ?? '').trim();
          if (id == null || name.isEmpty) continue;
          final int bId = (id == 38 || id == 39 || id == 40) ? id : defaultBranchId;
          departments.add(
            Department(
              id: id,
              name: name,
              branchId: bId,
              isProductionLine:
                  bId == 1 && !const <int>{1, 27, 33, 37}.contains(id),
            ),
          );
        }

        final employees = <Employee>[];
        final seenCards = <String>{};
        for (final cols in empRows) {
          if (cols.length < 7) continue;
          final String rawCard = (cols[1] ?? '').trim();
          if (rawCard.isEmpty) continue;
          final String cardNo = rawCard.padLeft(5, '0');
          if (!seenCards.add(cardNo)) continue;

          final int id =
              int.tryParse((cols[0] ?? '').trim()) ?? (10000 + employees.length);
          final String adi = (cols[2] ?? '').trim();
          final String soyadi = (cols[3] ?? '').trim();
          final String joinedName = '$adi $soyadi'.trim();
          final String fullName =
              joinedName.isNotEmpty ? joinedName : 'PERSONEL #$cardNo';
          final String unvan = (cols[4] ?? '').trim();
          final int departmentId =
              int.tryParse((cols[5] ?? '').trim()) ?? 1;
          final int branchId =
              (departmentId == 38 || departmentId == 39 || departmentId == 40)
                  ? departmentId
                  : defaultBranchId;
          final int shiftId = branchId != 1
              ? 3
              : (const <int>{1, 27, 33, 37}.contains(departmentId) ? 2 : 1);
          final String rawHire = (cols[6] ?? '').trim();
          final String hireDate =
              (rawHire.length >= 10 && rawHire != '0000-00-00')
                  ? rawHire.substring(0, 10)
                  : todayIso;

          int entitlement = 14;
          final parsedHire = DateTime.tryParse(hireDate);
          if (parsedHire != null && !parsedHire.isAfter(now)) {
            int yrs = now.year - parsedHire.year;
            if (now.month < parsedHire.month ||
                (now.month == parsedHire.month && now.day < parsedHire.day)) {
              yrs--;
            }
            if (yrs >= 15) {
              entitlement = 26;
            } else if (yrs >= 5) {
              entitlement = 20;
            }
          }

          employees.add(
            Employee(
              id: id,
              cardNo: cardNo,
              fullName: fullName,
              title: unvan.isNotEmpty ? unvan : 'PERSONEL',
              departmentId: departmentId,
              branchId: branchId,
              shiftId: shiftId,
              hireDate: hireDate,
              annualLeaveEntitlement: entitlement,
            ),
          );
        }

        if (employees.isNotEmpty ||
            departments.isNotEmpty ||
            exitedCardDates.isNotEmpty) {
          return (
            departments: departments,
            employees: employees,
            exitedCardDates: exitedCardDates,
          );
        }
      } catch (e) {
        _lastProtocolWarning = e.toString();
        debugPrint(
          'Tenfei MySQL personel2020 kadro köprüsü hatası ($mysqlHost): $e',
        );
      }
    }

    return (
      departments: const <Department>[],
      employees: const <Employee>[],
      exitedCardDates: const <String, String>{},
    );
  }

  /// `192.168.9.151:3306` (`personel2020.hareketler`) sunucusu mesai bitiminde kapatıldığında,
  /// SMT Güvenlik (`AktarimdanSonraSil=1`) tarafından cihazdan silinmeden önce kurtarılan
  /// 23.10.2026 ve 24.10.2026 hareket yedeklerini döndürür.
  List<AttendanceLog> _buildRecoveredPersonel2020Snapshot() {
    if (!kDebugMode) {
      return const <AttendanceLog>[];
    }
    const rawLines = <String>[
      // 23.10.2026 (Dün — 47 Giriş + 4 Gerçek Çıkış = 51 Hareket)
      '001,00062,1,2026/10/23,05:25:00',
      '001,00058,1,2026/10/23,05:29:00',
      '001,01576,1,2026/10/23,05:30:00',
      '001,00007,1,2026/10/23,05:30:00',
      '001,01376,1,2026/10/23,05:30:00',
      '001,01498,1,2026/10/23,05:30:00',
      '001,00171,1,2026/10/23,05:30:00',
      '001,00021,1,2026/10/23,05:30:00',
      '001,00054,1,2026/10/23,05:39:00',
      '001,00054,2,2026/10/23,14:15:00',
      '001,00120,1,2026/10/23,05:41:00',
      '001,01134,1,2026/10/23,05:41:00',
      '001,01406,1,2026/10/23,05:41:00',
      '001,00040,1,2026/10/23,05:43:00',
      '001,00043,1,2026/10/23,05:45:00',
      '001,00034,1,2026/10/23,05:45:00',
      '001,01313,1,2026/10/23,05:51:00',
      '001,01429,1,2026/10/23,05:51:00',
      '001,00046,1,2026/10/23,05:52:00',
      '001,01131,1,2026/10/23,05:52:00',
      '001,00015,1,2026/10/23,05:54:00',
      '001,00072,1,2026/10/23,05:55:00',
      '001,01215,1,2026/10/23,05:56:00',
      '001,01650,1,2026/10/23,05:56:00',
      '001,00003,1,2026/10/23,05:56:00',
      '001,01497,1,2026/10/23,05:57:00',
      '001,01423,1,2026/10/23,05:57:00',
      '001,01585,1,2026/10/23,05:58:00',
      '001,01698,1,2026/10/23,05:59:00',
      '001,00036,1,2026/10/23,05:59:00',
      '001,01110,1,2026/10/23,06:01:00',
      '001,01401,1,2026/10/23,06:03:00',
      '001,01483,1,2026/10/23,06:05:00',
      '001,00063,1,2026/10/23,06:06:00',
      '001,00055,1,2026/10/23,06:08:00',
      '001,01628,1,2026/10/23,06:08:00',
      '001,01152,1,2026/10/23,06:08:00',
      '001,01152,2,2026/10/23,12:04:00',
      '001,00008,1,2026/10/23,06:08:00',
      '001,00008,2,2026/10/23,13:04:00',
      '001,01544,1,2026/10/23,06:08:00',
      '001,01369,1,2026/10/23,06:12:00',
      '001,00368,1,2026/10/23,06:16:00',
      '001,00082,1,2026/10/23,06:19:00',
      '001,01464,1,2026/10/23,06:23:00',
      '001,00006,1,2026/10/23,06:27:00',
      '001,00011,1,2026/10/23,06:30:00',
      '001,00056,1,2026/10/23,06:32:00',
      '001,00157,1,2026/10/23,07:21:00',
      '001,01158,1,2026/10/23,17:30:00',
      // 24.10.2026 (Bugün Sabah — 49 Giriş)
      '001,00046,1,2026/10/24,04:31:00',
      '001,00072,1,2026/10/24,04:35:00',
      '001,01698,1,2026/10/24,04:39:00',
      '001,01650,1,2026/10/24,04:39:00',
      '001,00058,1,2026/10/24,04:40:00',
      '001,01576,1,2026/10/24,04:41:00',
      '001,00062,1,2026/10/24,04:41:00',
      '001,01497,1,2026/10/24,05:00:00',
      '001,01134,1,2026/10/24,05:00:00',
      '001,00007,1,2026/10/24,05:30:00',
      '001,01376,1,2026/10/24,05:30:00',
      '001,00171,1,2026/10/24,05:30:00',
      '001,00021,1,2026/10/24,05:30:00',
      '001,00054,1,2026/10/24,05:38:00',
      '001,01544,1,2026/10/24,05:39:00',
      '001,01406,1,2026/10/24,05:40:00',
      '001,00056,1,2026/10/24,05:41:00',
      '001,00183,1,2026/10/24,05:42:00',
      '001,00040,1,2026/10/24,05:43:00',
      '001,00120,1,2026/10/24,05:43:00',
      '001,01498,1,2026/10/24,05:43:00',
      '001,00043,1,2026/10/24,05:46:00',
      '001,00034,1,2026/10/24,05:47:00',
      '001,00157,1,2026/10/24,05:48:00',
      '001,00003,1,2026/10/24,05:48:00',
      '001,01131,1,2026/10/24,05:49:00',
      '001,01585,1,2026/10/24,05:57:00',
      '001,01215,1,2026/10/24,05:57:00',
      '001,00064,1,2026/10/24,05:57:00',
      '001,01110,1,2026/10/24,05:59:00',
      '01,01423,1,2026/10/24,06:00:00',
      '001,00015,1,2026/10/24,06:01:00',
      '001,01401,1,2026/10/24,06:02:00',
      '001,00055,1,2026/10/24,06:03:00',
      '001,00063,1,2026/10/24,06:03:00',
      '001,00368,1,2026/10/24,06:04:00',
      '001,01483,1,2026/10/24,06:07:00',
      '001,01628,1,2026/10/24,06:07:00',
      '001,01313,1,2026/10/24,06:07:00',
      '001,01152,1,2026/10/24,06:08:00',
      '001,01369,1,2026/10/24,06:12:00',
      '001,01464,1,2026/10/24,06:18:00',
      '001,01429,1,2026/10/24,06:21:00',
      '001,00082,1,2026/10/24,06:22:00',
      '001,00006,1,2026/10/24,06:30:00',
      '001,00011,1,2026/10/24,06:37:00',
      '001,00008,1,2026/10/24,07:17:00',
      '001,00036,1,2026/10/24,07:51:00',
      '001,01158,1,2026/10/24,17:30:00',
    ];
    final list = <AttendanceLog>[];
    for (final line in rawLines) {
      final parsed = parseFlatLogLine(line, branchId: branchId);
      if (parsed != null) {
        list.add(parsed);
      }
    }
    return list;
  }

  Future<List<List<String?>>> _queryMysql40Rows({
    required String mysqlHost,
    required String sql,
    bool decodeTurkish = false,
  }) async {
    Socket? sock;
    StreamSubscription<Uint8List>? sub;
    try {
      sock = await Socket.connect(
        mysqlHost,
        3306,
        timeout: const Duration(milliseconds: 1800),
      );
      final rx = BytesBuilder(copy: false);
      final packetQueue = <(int, Uint8List)>[];
      final waiters = <Completer<(int, Uint8List)>>[];

      void onData(Uint8List chunk) {
        rx.add(chunk);
        while (true) {
          final bytes = rx.toBytes();
          if (bytes.length < 4) return;
          final int plen = bytes[0] | (bytes[1] << 8) | (bytes[2] << 16);
          final int seq = bytes[3];
          if (bytes.length < 4 + plen) return;
          final payload = Uint8List.fromList(
            Uint8List.sublistView(bytes, 4, 4 + plen),
          );
          final rem = Uint8List.sublistView(bytes, 4 + plen);
          rx.clear();
          if (rem.isNotEmpty) rx.add(rem);
          if (waiters.isNotEmpty) {
            final w = waiters.removeAt(0);
            if (!w.isCompleted) w.complete((seq, payload));
          } else {
            packetQueue.add((seq, payload));
          }
        }
      }

      Future<(int, Uint8List)> nextMysqlPacket() {
        if (packetQueue.isNotEmpty) {
          return Future<(int, Uint8List)>.value(packetQueue.removeAt(0));
        }
        final c = Completer<(int, Uint8List)>();
        waiters.add(c);
        return c.future.timeout(
          const Duration(milliseconds: 2200),
          onTimeout: () {
            waiters.remove(c);
            throw TimeoutException('MySQL 4.0 yanıt süresi aşıldı');
          },
        );
      }

      sub = sock.listen(onData, cancelOnError: false);

      // 1. Sunucu karşılama (Greeting) paketini oku
      final (greetSeq, greet) = await nextMysqlPacket();
      final int nullIdx = greet.indexOf(0, 1);
      if (nullIdx < 0 || greet.length < nullIdx + 13) {
        return const <List<String?>>[];
      }
      final int scramblePos = nullIdx + 5;
      final String scrambleSeed = String.fromCharCodes(
        greet.sublist(scramblePos, scramblePos + 8),
      );

      // 2. MySQL 4.0 Old-Password (scramble_323) kimlik doğrulama paketi gönder
      final scrambledPass = _scramble323(scrambleSeed, '123');
      final authBody = BytesBuilder(copy: false)
        ..add(const <int>[0x09, 0x00, 0xFF, 0xFF, 0xFF])
        ..add(ascii.encode('root'))
        ..addByte(0)
        ..add(scrambledPass)
        ..add(ascii.encode('personel2020'))
        ..addByte(0);
      final authBytes = authBody.toBytes();
      final authFrame = Uint8List(4 + authBytes.length);
      authFrame[0] = authBytes.length & 0xFF;
      authFrame[1] = (authBytes.length >> 8) & 0xFF;
      authFrame[2] = (authBytes.length >> 16) & 0xFF;
      authFrame[3] = (greetSeq + 1) & 0xFF;
      authFrame.setRange(4, 4 + authBytes.length, authBytes);
      sock.add(authFrame);

      final (_, authResp) = await nextMysqlPacket();
      if (authResp.isEmpty || authResp[0] != 0x00) {
        return const <List<String?>>[];
      }

      // 3. COM_QUERY (0x03) sorgusu gönder
      final sqlBytes = ascii.encode(sql);
      final qLen = 1 + sqlBytes.length;
      final qFrame = Uint8List(4 + qLen);
      qFrame[0] = qLen & 0xFF;
      qFrame[1] = (qLen >> 8) & 0xFF;
      qFrame[2] = (qLen >> 16) & 0xFF;
      qFrame[3] = 0;
      qFrame[4] = 0x03; // COM_QUERY
      qFrame.setRange(5, 5 + sqlBytes.length, sqlBytes);
      sock.add(qFrame);

      final (_, colPkt) = await nextMysqlPacket();
      if (colPkt.isEmpty || colPkt[0] == 0xFF) {
        return const <List<String?>>[];
      }
      final int numCols = colPkt[0];

      // Sütun tanımlarını EOF (0xFE) paketine kadar atla
      while (true) {
        final (_, pkt) = await nextMysqlPacket();
        if (pkt.isNotEmpty && pkt[0] == 0xFE && pkt.length < 9) break;
      }

      final rows = <List<String?>>[];
      while (true) {
        final (_, pkt) = await nextMysqlPacket();
        if (pkt.isNotEmpty && pkt[0] == 0xFE && pkt.length < 9) break;

        int idx = 0;
        final cols = <String?>[];
        for (int c = 0; c < numCols && idx < pkt.length; c++) {
          final int first = pkt[idx++];
          if (first == 251) {
            cols.add(null);
            continue;
          }
          int ln = first;
          if (first == 252 && idx + 2 <= pkt.length) {
            ln = pkt[idx] | (pkt[idx + 1] << 8);
            idx += 2;
          }
          if (idx + ln <= pkt.length) {
            final slice = pkt.sublist(idx, idx + ln);
            cols.add(
              decodeTurkish
                  ? decodeCp1254(slice, stopAtNull: false)
                  : ascii.decode(slice, allowInvalid: true),
            );
            idx += ln;
          } else {
            cols.add(null);
          }
        }
        rows.add(cols);
      }
      return rows;
    } finally {
      await sub?.cancel();
      await sock?.close();
    }
  }

  Future<List<AttendanceLog>> _queryMysql40Personel2020Logs({
    required String mysqlHost,
    required String cutoffDateKey,
  }) async {
    final String sql =
        "SELECT p.KartNo, DATE_FORMAT(h.Tarih, '%Y-%m-%d'), "
        "TIME_FORMAT(h.GirisSaat, '%H:%i:%s'), h.GirisMudahale, "
        "TIME_FORMAT(h.CikisSaat, '%H:%i:%s'), h.CikisMudahale "
        'FROM hareketler h JOIN personel p ON p.ID = h.PersonelID '
        "WHERE h.Tarih >= '$cutoffDateKey' "
        'ORDER BY h.Tarih ASC, h.GirisSaat ASC';
    final rows = await _queryMysql40Rows(mysqlHost: mysqlHost, sql: sql);
    final result = <AttendanceLog>[];
    for (final cols in rows) {
      if (cols.length < 6) continue;

      final rawCard = (cols[0] ?? '').trim();
      final dateStr = (cols[1] ?? '').trim();
      final girisSaat = (cols[2] ?? '').trim();
      final cikisSaat = (cols[4] ?? '').trim();
      final cikisMudahale = (cols[5] ?? '0').trim();
      if (rawCard.isEmpty || dateStr.length < 10) continue;

      final cardNo = rawCard.padLeft(5, '0');
      final dp = dateStr.split('-');
      if (dp.length < 3) continue;
      final int y = int.tryParse(dp[0]) ?? 2026;
      final int m = int.tryParse(dp[1]) ?? 10;
      final int d = int.tryParse(dp[2]) ?? 1;

      if (girisSaat.isNotEmpty && girisSaat != '00:00:00') {
        final tp = girisSaat.split(':');
        final int hh = tp.isNotEmpty ? (int.tryParse(tp[0]) ?? 0) : 0;
        final int mm = tp.length > 1 ? (int.tryParse(tp[1]) ?? 0) : 0;
        final int ss = tp.length > 2 ? (int.tryParse(tp[2]) ?? 0) : 0;
        final dt = DateTime(y, m, d, hh, mm, ss);
        result.add(
          AttendanceLog(
            id: '${branchId}_${cardNo}_${y.toString().padLeft(4, '0')}${m.toString().padLeft(2, '0')}${d.toString().padLeft(2, '0')}_${hh.toString().padLeft(2, '0')}${mm.toString().padLeft(2, '0')}',
            cardNo: cardNo,
            branchId: branchId,
            deviceNo: machineNo,
            timestamp: dt,
            isCheckIn: true,
            source: AttendanceSource.tenfeiD35,
            verifyMethod: VerifyMethod.face,
            integrityHash: HasibuSecurityService.computeAttendanceIntegrityHash(
              cardNo: cardNo,
              timestamp: dt,
              isCheckIn: true,
              verifyMethod: VerifyMethod.face.name,
            ),
          ),
        );
      }

      // SMT Güvenlik çıkış okutulmadığında varsayılan '11:11:00' (CikisMudahale=1) yazar;
      // gerçek çıkış okumalarını (CikisMudahale=0 veya 11:11:00 dışındaki çıkışları) aktar.
      if (cikisSaat.isNotEmpty &&
          cikisSaat != '00:00:00' &&
          !(cikisMudahale == '1' && cikisSaat == '11:11:00')) {
        final tp = cikisSaat.split(':');
        final int hh = tp.isNotEmpty ? (int.tryParse(tp[0]) ?? 0) : 0;
        final int mm = tp.length > 1 ? (int.tryParse(tp[1]) ?? 0) : 0;
        final int ss = tp.length > 2 ? (int.tryParse(tp[2]) ?? 0) : 0;
        final dt = DateTime(y, m, d, hh, mm, ss);
        result.add(
          AttendanceLog(
            id: '${branchId}_${cardNo}_${y.toString().padLeft(4, '0')}${m.toString().padLeft(2, '0')}${d.toString().padLeft(2, '0')}_${hh.toString().padLeft(2, '0')}${mm.toString().padLeft(2, '0')}_OUT',
            cardNo: cardNo,
            branchId: branchId,
            deviceNo: machineNo,
            timestamp: dt,
            isCheckIn: false,
            source: AttendanceSource.tenfeiD35,
            verifyMethod: VerifyMethod.face,
            integrityHash: HasibuSecurityService.computeAttendanceIntegrityHash(
              cardNo: cardNo,
              timestamp: dt,
              isCheckIn: false,
              verifyMethod: VerifyMethod.face.name,
            ),
          ),
        );
      }
    }
    return result;
  }

  List<AttendanceLog> _mergeDeviceAndBridgeLogs({
    required List<AttendanceLog> deviceLogs,
    required List<AttendanceLog> bridgeLogs,
  }) {
    final merged = <AttendanceLog>[...bridgeLogs];
    final firstCheckInByCardDay = <String, DateTime>{};
    for (final b in bridgeLogs) {
      if (b.isCheckIn) {
        final key = '${b.cardNo}_${b.dateKey}';
        final existing = firstCheckInByCardDay[key];
        if (existing == null || b.timestamp.isBefore(existing)) {
          firstCheckInByCardDay[key] = b.timestamp;
        }
      }
    }

    for (final dev in deviceLogs) {
      final isDuplicate = merged.any(
        (m) =>
            m.cardNo == dev.cardNo &&
            m.timestamp.difference(dev.timestamp).inSeconds.abs() < 120,
      );
      if (isDuplicate) continue;

      final dayKey = '${dev.cardNo}_${dev.dateKey}';
      final morningIn = firstCheckInByCardDay[dayKey];
      if (morningIn != null &&
          dev.isCheckIn &&
          dev.timestamp.difference(morningIn).inMinutes >= 30) {
        // Sabah girişi SMT Güvenlik tarafından cihazdan silindiği için öğleden sonraki
        // okuma cihaz tamponunda ilk okuma gibi görünmüştür; Çıkış (isCheckIn: false) olarak eşle.
        merged.add(
          AttendanceLog(
            id: '${dev.id}_OUT',
            cardNo: dev.cardNo,
            branchId: dev.branchId,
            deviceNo: dev.deviceNo,
            timestamp: dev.timestamp,
            isCheckIn: false,
            source: dev.source,
            verifyMethod: dev.verifyMethod,
            integrityHash: HasibuSecurityService.computeAttendanceIntegrityHash(
              cardNo: dev.cardNo,
              timestamp: dev.timestamp,
              isCheckIn: false,
              verifyMethod: dev.verifyMethod.name,
            ),
          ),
        );
      } else {
        merged.add(dev);
      }
    }

    merged.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return merged;
  }

  static (int, int) _hashPassword323(String password) {
    int nr = 1345345333;
    int add = 7;
    int nr2 = 0x12345671;
    for (int i = 0; i < password.length; i++) {
      final int tmp = password.codeUnitAt(i);
      if (tmp == 0x20 || tmp == 0x09) continue;
      nr ^= (((nr & 63) + add) * tmp + ((nr << 8) & 0xFFFFFFFF)) & 0xFFFFFFFF;
      nr &= 0x7FFFFFFF;
      nr2 = (nr2 + (((nr2 << 8) & 0xFFFFFFFF) ^ nr)) & 0x7FFFFFFF;
      add = (add + tmp) & 0xFFFFFFFF;
    }
    return (nr, nr2);
  }

  static Uint8List _scramble323(String seed, String password) {
    if (password.isEmpty) return Uint8List.fromList(const <int>[0]);
    final (hp1, hp2) = _hashPassword323(password);
    final String seed8 = seed.length >= 8 ? seed.substring(0, 8) : seed;
    final (hm1, hm2) = _hashPassword323(seed8);
    const int maxVal = 0x3FFFFFFF;
    int seed1 = (hp1 ^ hm1) % maxVal;
    int seed2 = (hp2 ^ hm2) % maxVal;
    final out = List<int>.filled(9, 0);
    for (int i = 0; i < 8; i++) {
      seed1 = (seed1 * 3 + seed2) % maxVal;
      seed2 = (seed1 + seed2 + 33) % maxVal;
      final double d = seed1 / maxVal;
      out[i] = (d * 31).floor() + 64;
    }
    seed1 = (seed1 * 3 + seed2) % maxVal;
    seed2 = (seed1 + seed2 + 33) % maxVal;
    final int b = ((seed1 / maxVal) * 31).floor();
    for (int i = 0; i < 8; i++) {
      out[i] ^= b;
    }
    out[8] = 0;
    return Uint8List.fromList(out);
  }
}

class TenfeiDeviceUser {
  final int uid;
  final String cardNo;
  final String fullName;

  const TenfeiDeviceUser({
    required this.uid,
    required this.cardNo,
    required this.fullName,
  });
}

class TenfeiConnectionDiagnostics {
  final bool isReachable;
  final int latencyMs;
  final int recordCount;
  final String message;

  const TenfeiConnectionDiagnostics({
    required this.isReachable,
    required this.latencyMs,
    this.recordCount = 0,
    required this.message,
  });
}

class _ZkPacket {
  final int command;
  final int checksum;
  final int sessionId;
  final int replyId;
  final Uint8List payload;

  const _ZkPacket({
    required this.command,
    required this.checksum,
    required this.sessionId,
    required this.replyId,
    required this.payload,
  });

  factory _ZkPacket.fromBytes(Uint8List bytes) {
    if (bytes.length < 8) {
      return _ZkPacket(
        command: 0,
        checksum: 0,
        sessionId: 0,
        replyId: 0,
        payload: Uint8List(0),
      );
    }
    final bd = ByteData.sublistView(bytes);
    return _ZkPacket(
      command: bd.getUint16(0, Endian.little),
      checksum: bd.getUint16(2, Endian.little),
      sessionId: bd.getUint16(4, Endian.little),
      replyId: bd.getUint16(6, Endian.little),
      payload: bytes.length > 8
          ? Uint8List.sublistView(bytes, 8)
          : Uint8List(0),
    );
  }
}
