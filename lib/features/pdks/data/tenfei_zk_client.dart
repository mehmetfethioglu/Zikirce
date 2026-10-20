import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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

  final BytesBuilder _rxBuffer = BytesBuilder(copy: false);
  int _sessionId = 0;
  int _replyId = 0;
  bool _isConnected = false;

  TenfeiZkClient({
    required this.host,
    this.port = 4370,
    this.branchId = 1,
    this.machineNo = 1,
    this.commKey = 0,
    this.timeout = const Duration(seconds: 5),
  });

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
        } catch (_) {}
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
      final authPayload = makeCommKey(commKey, _sessionId);
      final authResp = await _sendCommand(cmdAuth, authPayload);
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
  Future<List<AttendanceLog>> fetchAttendanceLogs() async {
    final bool openedHere = !_isConnected;
    if (openedHere) {
      await connect();
    }

    try {
      try {
        await _sendCommand(cmdDisableDevice);
      } catch (_) {}

      final resp = await _sendCommand(cmdAttLogRrq);
      final Uint8List rawLogs = await _readBulkPayload(resp);

      try {
        await _sendCommand(cmdEnableDevice);
      } catch (_) {}

      return decodeAttendanceBuffer(
        rawLogs,
        branchId: branchId,
        deviceNo: machineNo,
      );
    } finally {
      if (openedHere) {
        await disconnect();
      }
    }
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
      final raw = await _packetController.stream.first.timeout(timeout);
      final pkt = _ZkPacket.fromBytes(raw);
      if (pkt.command == cmdData) {
        builder.add(pkt.payload);
      } else if (pkt.command == cmdAckOk) {
        break;
      }
    }

    // Tenfei D35 CMD_DATA paketlerinden hemen sonra sonlandırıcı bir CMD_ACK_OK (2000) gönderir.
    try {
      await _packetController.stream.first.timeout(
        const Duration(milliseconds: 350),
      );
    } catch (_) {}

    try {
      await _sendCommand(cmdFreeData).timeout(
        const Duration(milliseconds: 800),
      );
    } catch (_) {}

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

      final zkPayload = Uint8List.sublistView(bytes, 8, totalPacketSize);
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
      } else if (!_packetController.isClosed) {
        _packetController.add(zkPayload);
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

      return AttendanceLog(
        id: '${branchId}_${cardNo}_${timestamp.millisecondsSinceEpoch}',
        cardNo: cardNo,
        branchId: branchId,
        deviceNo: machineNo,
        timestamp: timestamp,
        isCheckIn: inOutState == 0 || inOutState == 4 || inOutState == 2,
        source: AttendanceSource.tenfeiD35,
        verifyMethod: _mapVerifyMethod(verifyCode),
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

    _replyId = (_replyId + 1) & 0xFFFF;
    final frame = buildTcpFrame(
      command: command,
      sessionId: _sessionId,
      replyId: _replyId,
      payload: payload ?? Uint8List(0),
    );

    final responseFuture = _packetController.stream.first.timeout(timeout);
    sock.add(frame);
    final rawResp = await responseFuture;
    return _ZkPacket.fromBytes(rawResp);
  }

  /// Bağlantıyı güvenli şekilde sonlandırır ve kaynakları serbest bırakır.
  Future<void> disconnect() async {
    if (_isConnected && _socket != null) {
      try {
        await _sendCommand(cmdExit).timeout(const Duration(milliseconds: 600));
      } catch (_) {}
    }
    _isConnected = false;
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

      logs.add(
        AttendanceLog(
          id: '${branchId}_${cardNo}_${timestamp.year}${timestamp.month.toString().padLeft(2, '0')}${timestamp.day.toString().padLeft(2, '0')}_${timestamp.hour.toString().padLeft(2, '0')}${timestamp.minute.toString().padLeft(2, '0')}',
          cardNo: cardNo,
          branchId: branchId,
          deviceNo: deviceNo,
          timestamp: timestamp,
          isCheckIn: isCheckIn,
          source: AttendanceSource.tenfeiD35,
          verifyMethod: _mapVerifyMethod(verifyType),
        ),
      );
    }
    return logs;
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

    return AttendanceLog(
      id: '${branchId}_${cardNo}_${dt.year}${dt.month.toString().padLeft(2, '0')}${dt.day.toString().padLeft(2, '0')}_${dt.hour.toString().padLeft(2, '0')}${dt.minute.toString().padLeft(2, '0')}',
      cardNo: cardNo,
      branchId: branchId,
      deviceNo: deviceNo,
      timestamp: dt,
      isCheckIn: isCheckIn,
      source: AttendanceSource.tenfeiD35,
      verifyMethod: VerifyMethod.face,
    );
  }

  static VerifyMethod _mapVerifyMethod(int code) {
    if (code >= 15) return VerifyMethod.face;
    if (code == 1) return VerifyMethod.fingerprint;
    if (code == 2 || code == 4) return VerifyMethod.card;
    if (code == 3) return VerifyMethod.password;
    return VerifyMethod.face;
  }
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
