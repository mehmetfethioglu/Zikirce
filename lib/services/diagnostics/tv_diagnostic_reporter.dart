import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../domain/tv_network_validators.dart';
import '../../models/cue_models.dart';
import '../discovery/tv_discovery_helpers.dart';

typedef LanSocketOpener = Future<Socket> Function(
  String ip,
  int port, {
  required Duration timeout,
});

typedef MtlsContextLoader = Future<SecurityContext?> Function();

/// Modular Smart TV LAN diagnostic report generator (TCP port scan, HTTP probes,
/// WebSocket variants, mDNS/DNS-SD records, TLS mTLS inspection, and SSDP).
class TvDiagnosticReporter {
  const TvDiagnosticReporter({
    required this.openLanSocket,
    required this.loadMtlsContext,
  });

  final LanSocketOpener openLanSocket;
  final MtlsContextLoader loadMtlsContext;

  static const List<int> _curatedPorts = <int>[
    21, 22, 23, 53, 80, 81, 443, 554, 1080, 1400, 1900, 1925, 1926, 1986,
    2869, 3000, 3001, 4352, 4660, 5000, 5555, 6466, 6467, 7000, 7001, 7345,
    7547, 7676, 7681, 8000, 8001, 8002, 8008, 8009, 8060, 8080, 8081, 8082,
    8085, 8088, 8090, 8180, 8200, 8443, 8888, 9000, 9080, 9090, 9197, 9999,
    10000, 36669, 36866, 37777, 49152, 49153, 49154, 49155, 52235, 55000,
    55001, 56789, 56790, 56791, 56792, 56793, 56794, 56795, 60000, 60001,
  ];

  Future<String> buildReport(
    TvDevice device, {
    required String appVersion,
    required String detectedWifiIp,
    required bool localNetworkPermissionDenied,
    required List<String> recentDiagLog,
    List<int>? scanPortsOverride,
  }) async {
    final ip = device.ip.trim();
    final b = StringBuffer()
      ..writeln('=== CueDeck Bağlantı Tanılama Raporu ===')
      ..writeln('Tarih: ${DateTime.now().toIso8601String()}')
      ..writeln('Uygulama: $appVersion')
      ..writeln(
        'Telefon: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
      )
      ..writeln('Telefon Wi-Fi IP: $detectedWifiIp')
      ..writeln('Yerel ağ izni reddi (iOS): $localNetworkPermissionDenied')
      ..writeln(
        'Seçili TV: "${device.name}" ip=$ip port=${device.port} '
        'protokol=${device.protocol.name} eşleşti=${device.isPaired} '
        'çevrimiçi=${device.isOnline}',
      )
      ..writeln('Kart bilgisi: ${device.boardInfo}');

    if (!TvNetworkValidators.isValidIp(ip)) {
      b.writeln('!! Geçerli TV IP adresi yok; önce TV seçin veya IP girin.');
      _appendDiagTail(b, recentDiagLog);
      return b.toString();
    }

    final scanStart = DateTime.now();
    final List<int> scanPorts;
    final int concurrency;
    final Duration perPortTimeout;
    if (scanPortsOverride != null) {
      scanPorts = scanPortsOverride;
      concurrency = 16;
      perPortTimeout = const Duration(milliseconds: 1200);
    } else if (Platform.isIOS) {
      scanPorts = _curatedPorts;
      concurrency = 8;
      perPortTimeout = const Duration(milliseconds: 1800);
    } else {
      scanPorts = List<int>.generate(65535, (i) => i + 1);
      concurrency = 256;
      perPortTimeout = const Duration(milliseconds: 450);
    }

    final scan = await _portScan(
      ip,
      scanPorts,
      concurrency: concurrency,
      timeout: perPortTimeout,
    );
    final openPorts = scan.open;
    b
      ..writeln('')
      ..writeln(
        '--- Port Taraması (${scanPorts.length} port, '
        '${DateTime.now().difference(scanStart).inSeconds} sn) ---',
      )
      ..writeln(
        'AÇIK: ${openPorts.isEmpty ? "(hiçbiri)" : openPorts.join(", ")}',
      )
      ..writeln(
        'Reddedildi(RST): ${scan.refused}  Zaman aşımı: ${scan.timedOut}  '
        'Diğer hata: ${scan.otherErrors}',
      )
      ..writeln('')
      ..writeln('--- Açık Port Yanıtları ---');

    for (final p in openPorts.take(24)) {
      final banner = await _bannerProbe(ip, p);
      final http = await _rawHttpProbe(ip, p, '/');
      b.writeln(':$p banner=$banner');
      b.writeln(':$p GET / -> $http');
      if (http == '(yanıt yok)') {
        b.writeln(':$p WebSocket -> ${await _webSocketProbe(ip, p)}');
      }
    }

    const httpProbes = <int, List<String>>{
      8008: <String>[
        '/setup/eureka_info?params=name,device_info',
        '/ssdp/device-desc.xml',
      ],
      56789: <String>[
        '/dd.xml',
        '/apps/',
        '/apps/YouTube',
        '/apps/Netflix',
        '/apps/SmartCenter',
        '/description.xml',
        '/rootDesc.xml',
      ],
      56790: <String>['/dd.xml', '/apps/', '/apps/YouTube'],
      8080: <String>['/sendrcpackage?keyid=-2490&keysymbol=13', '/info'],
      8085: <String>['/sendrcpackage?keyid=-2490&keysymbol=13'],
      1925: <String>['/6/system', '/1/system'],
      8060: <String>['/query/device-info'],
      8001: <String>['/api/v2/'],
    };

    b
      ..writeln('')
      ..writeln('--- Bilinen HTTP Yolları ---');
    for (final p in openPorts) {
      final paths = httpProbes[p];
      if (paths == null) continue;
      for (final path in paths) {
        b.writeln('GET :$p$path -> ${await _rawHttpProbe(ip, p, path)}');
      }
    }

    b
      ..writeln('')
      ..writeln('--- mDNS Servisleri ---')
      ..writeln(await _mdnsProbe(ip))
      ..writeln('')
      ..writeln('--- Arçelik Kumanda Servisi (_arceliktvremote._tcp) ---')
      ..writeln(await _arcelikServiceRecords(ip));

    for (final p in <int>[3697, 8080]) {
      if (openPorts.contains(p)) {
        b.writeln(':$p yavaş TCP denemesi -> ${await _slowRawProbe(ip, p)}');
      }
    }
    if (openPorts.contains(7681)) {
      b.writeln(':7681 WebSocket varyantları:');
      b.writeln(await _webSocketVariants(ip, 7681));
    }

    for (final p in <int>[6466, 6467]) {
      if (!openPorts.contains(p)) continue;
      b.writeln('');
      b.writeln('--- TLS :$p ---');
      b.writeln('Sertifikasız: ${await _tlsProbe(ip, p, useClientCert: false)}');
      b.writeln('mTLS ile: ${await _tlsProbe(ip, p, useClientCert: true)}');
    }

    b
      ..writeln('')
      ..writeln('--- SSDP (UPnP) Yanıtları ---')
      ..writeln(await _ssdpProbe(ip));

    _appendDiagTail(b, recentDiagLog);
    return b.toString();
  }

  Future<({List<int> open, int refused, int timedOut, int otherErrors})>
  _portScan(
    String ip,
    List<int> ports, {
    required int concurrency,
    required Duration timeout,
  }) async {
    final open = <int>[];
    var refused = 0;
    var timedOut = 0;
    var other = 0;
    var next = 0;
    final useBoundSocket = Platform.isIOS;

    Future<void> worker() async {
      while (next < ports.length) {
        final p = ports[next++];
        Socket? s;
        try {
          s = useBoundSocket
              ? await openLanSocket(ip, p, timeout: timeout)
              : await Socket.connect(ip, p, timeout: timeout);
          open.add(p);
        } on SocketException catch (e) {
          final code = e.osError?.errorCode ?? 0;
          final msg = e.message.toLowerCase();
          if (code == 111 || code == 61 || msg.contains('refused')) {
            refused++;
          } else if (msg.contains('timed out') || code == 110 || code == 60) {
            timedOut++;
          } else {
            other++;
          }
        } on TimeoutException {
          timedOut++;
        } catch (e) {
          other++;
        } finally {
          try {
            s?.destroy();
          } catch (e) {
            other = other;
          }
        }
      }
    }

    await Future.wait<void>(
      List<Future<void>>.generate(concurrency, (_) => worker()),
    );
    open.sort();
    return (
      open: open,
      refused: refused,
      timedOut: timedOut,
      otherErrors: other,
    );
  }

  Future<String> _bannerProbe(String ip, int port) async {
    Socket? sock;
    try {
      sock = await openLanSocket(
        ip,
        port,
        timeout: const Duration(milliseconds: 1200),
      );
      final rx = <int>[];
      final done = Completer<void>();
      final sub = sock.listen(
        (chunk) {
          rx.addAll(chunk);
          if (rx.length >= 256 && !done.isCompleted) done.complete();
        },
        onError: (_) {
          if (!done.isCompleted) done.complete();
        },
        onDone: () {
          if (!done.isCompleted) done.complete();
        },
        cancelOnError: true,
      );
      await done.future.timeout(
        const Duration(milliseconds: 900),
        onTimeout: () {},
      );
      await sub.cancel();
      if (rx.isEmpty) return '(sessiz)';
      return _describeBytes(rx);
    } catch (e) {
      return 'HATA: $e';
    } finally {
      try {
        sock?.destroy();
      } catch (e) {
        sock = null;
      }
    }
  }

  Future<String> _webSocketProbe(String ip, int port) async {
    Socket? sock;
    try {
      sock = await openLanSocket(
        ip,
        port,
        timeout: const Duration(milliseconds: 1200),
      );
      final rx = <int>[];
      final done = Completer<void>();
      final sub = sock.listen(
        (chunk) {
          rx.addAll(chunk);
          if (rx.length >= 512 && !done.isCompleted) done.complete();
        },
        onError: (_) {
          if (!done.isCompleted) done.complete();
        },
        onDone: () {
          if (!done.isCompleted) done.complete();
        },
        cancelOnError: true,
      );
      sock.add(
        ascii.encode(
          'GET / HTTP/1.1\r\nHost: $ip:$port\r\nUpgrade: websocket\r\n'
          'Connection: Upgrade\r\nSec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n'
          'Sec-WebSocket-Version: 13\r\n\r\n',
        ),
      );
      await sock.flush();
      await done.future.timeout(
        const Duration(milliseconds: 1500),
        onTimeout: () {},
      );
      await sub.cancel();
      if (rx.isEmpty) return '(yanıt yok)';
      return _describeBytes(rx);
    } catch (e) {
      return 'HATA: $e';
    } finally {
      try {
        sock?.destroy();
      } catch (e) {
        sock = null;
      }
    }
  }

  String _describeBytes(List<int> rx) {
    final slice = rx.take(400).toList();
    final printable = slice
        .where((b) => b == 9 || b == 10 || b == 13 || (b >= 32 && b < 127))
        .length;
    if (printable >= slice.length * 0.8) {
      final text = utf8
          .decode(slice, allowMalformed: true)
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      return '"$text"';
    }
    final hex = slice
        .take(64)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join(' ');
    return 'ikili ${rx.length} bayt: $hex';
  }

  Future<String> _mdnsProbe(String ip) async {
    final names = <String>{};
    final otherSenders = <String>{};
    RawDatagramSocket? sock;
    StreamSubscription<RawSocketEvent>? sub;
    try {
      sock = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
        reuseAddress: true,
      );
      sock.multicastHops = 255;
      sub = sock.listen((event) {
        if (event != RawSocketEvent.read) return;
        final dg = sock?.receive();
        if (dg == null) return;
        if (dg.address.address != ip) {
          otherSenders.add(dg.address.address);
          return;
        }
        final buf = StringBuffer();
        for (final byte in dg.data.skip(12)) {
          if (byte >= 32 && byte < 127) {
            buf.writeCharCode(byte);
          } else {
            final s = buf.toString().trim();
            if (s.length >= 3 && names.length < 30) names.add(s);
            buf.clear();
          }
        }
        final s = buf.toString().trim();
        if (s.length >= 3 && names.length < 30) names.add(s);
      });
      final target = InternetAddress('224.0.0.251');
      for (final svc in <String>[
        '_services._dns-sd._udp.local',
        '_http._tcp.local',
        '_androidtvremote2._tcp.local',
        '_googlecast._tcp.local',
        '_airplay._tcp.local',
        '_dial._tcp.local',
      ]) {
        sock.send(
          TvDiscoveryHelpers.buildMdnsPtrQueryPacket(svc),
          target,
          5353,
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 1400));
    } catch (e) {
      return 'mDNS HATA: $e';
    } finally {
      await sub?.cancel();
      sock?.close();
    }
    final b = StringBuffer();
    b.write(names.isEmpty ? '$ip: (yanıt yok)' : '$ip: ${names.join(' | ')}');
    if (otherSenders.isNotEmpty) {
      b.write(
        '\nmDNS yanıtlayan diğer cihazlar: ${otherSenders.take(12).join(', ')}',
      );
    }
    return b.toString();
  }

  Future<String> _arcelikServiceRecords(String ip) async {
    final records = <String>{};
    RawDatagramSocket? sock;
    StreamSubscription<RawSocketEvent>? sub;
    try {
      sock = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
        reuseAddress: true,
      );
      sock.multicastHops = 255;
      sub = sock.listen((event) {
        if (event != RawSocketEvent.read) return;
        final dg = sock?.receive();
        if (dg == null || dg.address.address != ip) return;
        for (final r in TvDiscoveryHelpers.describeDnsRecords(dg.data)) {
          if (records.length < 40) records.add(r);
        }
      });
      final target = InternetAddress('224.0.0.251');
      for (var i = 0; i < 2; i++) {
        sock.send(
          TvDiscoveryHelpers.buildMdnsPtrQueryPacket(
            '_arceliktvremote._tcp.local',
          ),
          target,
          5353,
        );
        await Future<void>.delayed(const Duration(milliseconds: 450));
      }
      await Future<void>.delayed(const Duration(milliseconds: 900));
    } catch (e) {
      return 'HATA: $e';
    } finally {
      await sub?.cancel();
      sock?.close();
    }
    return records.isEmpty ? '(kayıt alınamadı)' : records.join('\n');
  }

  Future<String> _slowRawProbe(String ip, int port) async {
    Socket? sock;
    try {
      sock = await Socket.connect(
        ip,
        port,
        timeout: const Duration(seconds: 3),
      );
      final rx = <int>[];
      var closedByServer = false;
      final sub = sock.listen(
        rx.addAll,
        onError: (_) {
          closedByServer = true;
        },
        onDone: () => closedByServer = true,
        cancelOnError: true,
      );
      await Future<void>.delayed(const Duration(milliseconds: 1800));
      final greeting = rx.isEmpty ? '(sessiz)' : _describeBytes(rx);
      final before = rx.length;
      if (!closedByServer) {
        sock.add(ascii.encode('\r\n'));
        await sock.flush();
        await Future<void>.delayed(const Duration(milliseconds: 1200));
      }
      final afterNewline = rx.length > before
          ? _describeBytes(rx.sublist(before))
          : '(yanıt yok)';
      await sub.cancel();
      return 'karşılama=$greeting, satırsonu sonrası=$afterNewline, '
          'sunucu kapattı=$closedByServer';
    } catch (e) {
      return 'HATA: $e';
    } finally {
      try {
        sock?.destroy();
      } catch (e) {
        sock = null;
      }
    }
  }

  Future<String> _webSocketVariants(String ip, int port) async {
    const paths = <String>[
      '/',
      '/ws',
      '/remote',
      '/tvremote',
      '/arceliktvremote',
      '/websocket',
      '/api',
      '/control',
    ];
    const protocols = <String?>[
      null,
      'arceliktvremote',
      'tvremote',
      'remote',
      'rc',
      'json',
      'lws-minimal',
    ];
    final results = <String, List<String>>{};
    for (final path in paths) {
      for (final proto in protocols) {
        for (final withOrigin in <bool>[false, true]) {
          if (withOrigin && (path != '/' || proto != null)) continue;
          final r = await _wsHandshake(
            ip,
            port,
            path,
            protocol: proto,
            origin: withOrigin ? 'http://$ip:$port' : null,
          );
          final label =
              '$path${proto != null ? ' [$proto]' : ''}${withOrigin ? ' +Origin' : ''}';
          results.putIfAbsent(r, () => <String>[]).add(label);
        }
      }
    }
    final b = StringBuffer();
    results.forEach((answer, labels) {
      final shown = labels.length > 6
          ? '${labels.take(6).join(', ')} … (+${labels.length - 6})'
          : labels.join(', ');
      b.writeln('  $answer  <=  $shown');
    });
    return b.toString().trimRight();
  }

  Future<String> _wsHandshake(
    String ip,
    int port,
    String path, {
    String? protocol,
    String? origin,
  }) async {
    Socket? sock;
    try {
      sock = await Socket.connect(
        ip,
        port,
        timeout: const Duration(milliseconds: 1200),
      );
      final rx = <int>[];
      final done = Completer<void>();
      final sub = sock.listen(
        (chunk) {
          rx.addAll(chunk);
          if (rx.length >= 600 && !done.isCompleted) done.complete();
        },
        onError: (_) {
          if (!done.isCompleted) done.complete();
        },
        onDone: () {
          if (!done.isCompleted) done.complete();
        },
        cancelOnError: true,
      );
      final req = StringBuffer()
        ..write('GET $path HTTP/1.1\r\n')
        ..write('Host: $ip:$port\r\n')
        ..write('Upgrade: websocket\r\nConnection: Upgrade\r\n')
        ..write('Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n')
        ..write('Sec-WebSocket-Version: 13\r\n');
      if (protocol != null) req.write('Sec-WebSocket-Protocol: $protocol\r\n');
      if (origin != null) req.write('Origin: $origin\r\n');
      req.write('\r\n');
      sock.add(ascii.encode(req.toString()));
      await sock.flush();
      await done.future.timeout(
        const Duration(milliseconds: 1200),
        onTimeout: () {},
      );
      await sub.cancel();
      if (rx.isEmpty) return '(yanıt yok)';
      final text = utf8.decode(rx, allowMalformed: true);
      final status = text.split('\r\n').first.trim();
      if (status.contains(' 101')) {
        final headerEnd = text.indexOf('\r\n\r\n');
        final proto = RegExp(
          r'Sec-WebSocket-Protocol:\s*([^\r\n]+)',
          caseSensitive: false,
        ).firstMatch(text)?.group(1);
        final extra = headerEnd >= 0 && rx.length > headerEnd + 4
            ? _describeBytes(rx.sublist(headerEnd + 4))
            : '(ilk çerçeve yok)';
        return '$status protokol=${proto ?? '-'} ilkVeri=$extra';
      }
      return status;
    } catch (e) {
      return 'HATA: ${e.runtimeType}';
    } finally {
      try {
        sock?.destroy();
      } catch (e) {
        sock = null;
      }
    }
  }

  void _appendDiagTail(StringBuffer b, List<String> recentDiagLog) {
    b
      ..writeln('')
      ..writeln('--- Son Bağlantı / Tuş Denemeleri ---');
    final tail = recentDiagLog.length > 60
        ? recentDiagLog.sublist(recentDiagLog.length - 60)
        : recentDiagLog;
    if (tail.isEmpty) {
      b.writeln(
        '(Henüz tuş denemesi yok — rapordan önce kumandada 1-2 tuşa basın)',
      );
    }
    for (final line in tail) {
      b.writeln(line);
    }
  }

  Future<String> _rawHttpProbe(String ip, int port, String path) async {
    Socket? sock;
    try {
      sock = await openLanSocket(
        ip,
        port,
        timeout: const Duration(milliseconds: 900),
      );
      final rx = <int>[];
      final done = Completer<void>();
      final sub = sock.listen(
        (chunk) {
          rx.addAll(chunk);
          if (rx.length >= 1500 && !done.isCompleted) done.complete();
        },
        onError: (_) {
          if (!done.isCompleted) done.complete();
        },
        onDone: () {
          if (!done.isCompleted) done.complete();
        },
        cancelOnError: true,
      );
      sock.add(
        ascii.encode(
          'GET $path HTTP/1.1\r\nHost: $ip:$port\r\n'
          'User-Agent: CueDeck-Diag\r\nAccept: */*\r\nConnection: close\r\n\r\n',
        ),
      );
      await sock.flush();
      await done.future.timeout(
        const Duration(milliseconds: 1200),
        onTimeout: () {},
      );
      await sub.cancel();
      if (rx.isEmpty) return '(yanıt yok)';
      final text = utf8
          .decode(rx.take(1500).toList(), allowMalformed: true)
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      return text.length > 420 ? '${text.substring(0, 420)}…' : text;
    } catch (e) {
      return 'HATA: $e';
    } finally {
      try {
        sock?.destroy();
      } catch (e) {
        sock = null;
      }
    }
  }

  Future<String> _tlsProbe(
    String ip,
    int port, {
    required bool useClientCert,
  }) async {
    String subject = '';
    SecureSocket? s;
    try {
      SecurityContext? ctx;
      if (useClientCert) {
        ctx = await loadMtlsContext();
        if (ctx == null) return 'istemci sertifikası oluşturulamadı';
      }
      s = await SecureSocket.connect(
        ip,
        port,
        context: ctx,
        onBadCertificate: (X509Certificate c) {
          subject = c.subject;
          return true;
        },
        timeout: const Duration(milliseconds: 1500),
      );
      subject = subject.isNotEmpty
          ? subject
          : (s.peerCertificate?.subject ?? '');
      final closed = Completer<String>();
      final sub = s.listen(
        (d) {
          if (!closed.isCompleted) {
            closed.complete('veri alındı (${d.length} bayt)');
          }
        },
        onError: (Object e) {
          if (!closed.isCompleted) closed.complete('hata: $e');
        },
        onDone: () {
          if (!closed.isCompleted) closed.complete('sunucu bağlantıyı kapattı');
        },
      );
      final after = await closed.future.timeout(
        const Duration(milliseconds: 900),
        onTimeout: () => 'açık kaldı',
      );
      await sub.cancel();
      return 'el sıkışma OK, sertifika="$subject", sonrası: $after';
    } catch (e) {
      return 'HATA: $e${subject.isNotEmpty ? ' (sertifika="$subject")' : ''}';
    } finally {
      try {
        s?.destroy();
      } catch (e) {
        s = null;
      }
    }
  }

  Future<String> _ssdpProbe(String targetIp) async {
    final lines = <String>[];
    final others = <String, String>{};
    RawDatagramSocket? sock;
    StreamSubscription<RawSocketEvent>? sub;
    try {
      sock = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      sub = sock.listen((event) {
        if (event != RawSocketEvent.read) return;
        final dg = sock?.receive();
        if (dg == null) return;
        final sender = dg.address.address;
        final text = utf8.decode(dg.data, allowMalformed: true);
        String header(String name) =>
            RegExp('^$name:\\s*(.+)\$', caseSensitive: false, multiLine: true)
                .firstMatch(text)
                ?.group(1)
                ?.trim() ??
            '';
        if (sender == targetIp) {
          final entry =
              'SERVER=${header('SERVER')} | ST=${header('ST')} | LOCATION=${header('LOCATION')}';
          if (!lines.contains(entry) && lines.length < 12) lines.add(entry);
        } else if (others.length < 12) {
          others[sender] = header('SERVER');
        }
      });
      const searchTargets = <String>[
        'ssdp:all',
        'upnp:rootdevice',
        'urn:dial-multiscreen-org:service:dial:1',
        'urn:schemas-upnp-org:device:MediaRenderer:1',
        'urn:schemas-upnp-org:device:Basic:1',
      ];
      for (final st in searchTargets) {
        final req =
            'M-SEARCH * HTTP/1.1\r\nHOST: 239.255.255.250:1900\r\n'
            'MAN: "ssdp:discover"\r\nMX: 2\r\nST: $st\r\n\r\n';
        sock.send(ascii.encode(req), InternetAddress('239.255.255.250'), 1900);
      }
      await Future<void>.delayed(const Duration(milliseconds: 1800));
    } catch (e) {
      return 'SSDP HATA: $e';
    } finally {
      await sub?.cancel();
      sock?.close();
    }
    final b = StringBuffer();
    if (lines.isEmpty) {
      b.write('$targetIp: (yanıt yok)');
    } else {
      b.write(lines.join('\n'));
    }
    if (others.isNotEmpty) {
      b.write(
        '\nDiğer SSDP cihazları: ${others.entries.map((e) => '${e.key}(${e.value})').join(', ')}',
      );
    }
    return b.toString();
  }
}
