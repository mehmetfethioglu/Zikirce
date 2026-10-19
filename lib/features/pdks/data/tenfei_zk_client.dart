import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../domain/pdks_models.dart';

/// Saf Dart ZKTeco / Tenfei D35 TCP (Port 4370) Protokol İstemcisi.
/// Doğrudan TCP soketiyle Tenfei D35 Yüz Tanıma ve Parmak İzi Terminaline
/// (varsayılan 192.168.9.150:4370) bağlanarak canlı ve toplu hareketleri çeker.
class TenfeiZkClient {
  static const int cmdConnect = 1000;
  static const int cmdExit = 1001;
  static const int cmdEnableDevice = 1002;
  static const int cmdDisableDevice = 1003;
  static const int cmdAckOk = 2000;
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
    this.timeout = const Duration(seconds: 4),
  });

  bool get isConnected => _isConnected;

  /// Cihazdan anlık yüz/parmak izi okutma (EF_ATTLOG) olaylarını yayınlar.
  Stream<AttendanceLog> get realtimeAttendanceStream =>
      _realtimeLogController.stream;

  /// Cihazın TCP 4370 portuna erişilebilirliği ve protokol el sıkışmasını test eder.
  Future<TenfeiConnectionDiagnostics> testConnection() async {
    final sw = Stopwatch()..start();
    try {
      await connect();
      sw.stop();
      await disconnect();
      return TenfeiConnectionDiagnostics(
        isReachable: true,
        latencyMs: sw.elapsedMilliseconds,
        message: 'Tenfei D35 ($host:$port) bağlantısı başarılı (${sw.elapsedMilliseconds} ms).',
      );
    } catch (e) {
      sw.stop();
      return TenfeiConnectionDiagnostics(
        isReachable: false,
        latencyMs: sw.elapsedMilliseconds,
        message: 'Cihaza ulaşılamadı ($host:$port) — Aynı yerel ağda (192.168.9.x) olduğunuzdan emin olun.',
      );
    }
  }

  /// Tenfei D35 terminaline TCP 4370 üzerinden bağlanır ve oturum açar.
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
      await _sendCommand(cmdDisableDevice);
      final resp = await _sendCommand(cmdAttLogRrq);
      final Uint8List rawLogs = await _readBulkPayload(resp);
      await _sendCommand(cmdEnableDevice);
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

    await _sendCommand(cmdFreeData);
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
        await _sendCommand(cmdExit).timeout(const Duration(milliseconds: 800));
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
  static List<AttendanceLog> decodeAttendanceBuffer(
    Uint8List raw, {
    int branchId = 1,
    int deviceNo = 1,
  }) {
    if (raw.isEmpty) return const <AttendanceLog>[];
    final logs = <AttendanceLog>[];

    // Standart 40-byte ZKTeco SSR/Face terminal kaydı
    const int recordSize = 40;
    for (int offset = 0;
        offset + recordSize <= raw.length;
        offset += recordSize) {
      final slice = Uint8List.sublistView(raw, offset, offset + recordSize);
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

      // Ayarlar.ini: Girisler=4,0,2 / Cikislar=1,5,3
      final bool isCheckIn = status == 0 || status == 2 || status == 4;

      logs.add(
        AttendanceLog(
          id: '${branchId}_${cardNo}_${timestamp.millisecondsSinceEpoch}',
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
    final int second = timeParts.length > 2 ? (int.tryParse(timeParts[2]) ?? 0) : 0;

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
  final String message;

  const TenfeiConnectionDiagnostics({
    required this.isReachable,
    required this.latencyMs,
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
