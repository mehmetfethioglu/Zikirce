import 'dart:convert';
import 'dart:typed_data';

import '../../domain/tv_network_validators.dart';

/// Pure mDNS / DNS-SD packet builders and record decoders (Layer 1).
class TvDiscoveryHelpers {
  TvDiscoveryHelpers._();

  /// Builds a standard mDNS PTR query packet (`QTYPE = 12`, `QCLASS = IN`).
  static Uint8List buildMdnsPtrQueryPacket(String serviceDomain) {
    final labels = serviceDomain.split('.');
    final bytes = <int>[
      0x00, 0x00,
      0x00, 0x00,
      0x00, 0x01,
      0x00, 0x00,
      0x00, 0x00,
      0x00, 0x00,
    ];
    for (final label in labels) {
      final encoded = ascii.encode(label);
      bytes.add(encoded.length & 0xFF);
      bytes.addAll(encoded);
    }
    bytes.add(0x00);
    bytes.addAll(const <int>[0x00, 0x0C, 0x00, 0x01]);
    return Uint8List.fromList(bytes);
  }

  /// Extracts a human-readable device label from an mDNS response payload.
  static String extractReadableMdnsLabel(Uint8List packet) {
    if (packet.length < 16) return '';
    final printable = StringBuffer();
    final candidates = <String>[];
    for (final b in packet.skip(12)) {
      if ((b >= 48 && b <= 57) ||
          (b >= 65 && b <= 90) ||
          (b >= 97 && b <= 122) ||
          b == 45 ||
          b == 32) {
        printable.writeCharCode(b);
      } else {
        if (printable.length >= 4) {
          candidates.add(printable.toString().trim());
        }
        printable.clear();
      }
    }
    if (printable.length >= 4) {
      candidates.add(printable.toString().trim());
    }
    for (final item in candidates) {
      final lower = item.toLowerCase();
      if (lower == 'local' ||
          lower == 'androidtvremote2' ||
          lower == 'googlecast' ||
          lower.startsWith('_')) {
        continue;
      }
      if (item.length >= 4 && item.length <= 36) {
        return item;
      }
    }
    return '';
  }

  static ({String name, int next}) _dnsReadName(Uint8List d, int off) {
    final labels = <String>[];
    var pos = off;
    var next = -1;
    var jumps = 0;
    while (pos < d.length) {
      final len = d[pos];
      if (len == 0) {
        pos++;
        break;
      }
      if ((len & 0xC0) == 0xC0) {
        if (pos + 1 >= d.length) break;
        if (next < 0) next = pos + 2;
        pos = ((len & 0x3F) << 8) | d[pos + 1];
        if (++jumps > 20) break;
        continue;
      }
      pos++;
      if (pos + len > d.length) break;
      labels.add(utf8.decode(d.sublist(pos, pos + len), allowMalformed: true));
      pos += len;
    }
    return (name: labels.join('.'), next: next >= 0 ? next : pos);
  }

  /// Decodes PTR / SRV / TXT / A records of an mDNS response packet into text lines.
  static List<String> describeDnsRecords(Uint8List d) {
    final out = <String>[];
    if (d.length < 12) return out;
    final bd = ByteData.sublistView(d);
    final qd = bd.getUint16(4);
    final total = bd.getUint16(6) + bd.getUint16(8) + bd.getUint16(10);
    var pos = 12;
    for (var i = 0; i < qd && pos < d.length; i++) {
      pos = _dnsReadName(d, pos).next + 4;
    }
    for (var i = 0; i < total && pos + 10 <= d.length; i++) {
      final n = _dnsReadName(d, pos);
      pos = n.next;
      if (pos + 10 > d.length) break;
      final type = bd.getUint16(pos);
      final rdLen = bd.getUint16(pos + 8);
      pos += 10;
      if (pos + rdLen > d.length) break;
      switch (type) {
        case 12:
          out.add('PTR ${n.name} -> ${_dnsReadName(d, pos).name}');
        case 33:
          if (rdLen >= 6) {
            out.add(
              'SRV ${n.name} port=${bd.getUint16(pos + 4)} '
              'hedef=${_dnsReadName(d, pos + 6).name}',
            );
          }
        case 16:
          final parts = <String>[];
          var t = pos;
          while (t < pos + rdLen) {
            final l = d[t];
            t++;
            if (t + l > pos + rdLen) break;
            parts.add(utf8.decode(d.sublist(t, t + l), allowMalformed: true));
            t += l;
          }
          out.add('TXT ${n.name} -> ${parts.join(' ; ')}');
        case 1:
          if (rdLen == 4) {
            out.add(
              'A ${n.name} -> ${d[pos]}.${d[pos + 1]}.${d[pos + 2]}.${d[pos + 3]}',
            );
          }
        default:
          out.add('TYPE$type ${n.name}');
      }
      pos += rdLen;
    }
    return out;
  }

  /// Extracts and normalizes a Wake-on-LAN MAC address from an SSDP response
  /// (`WAKEUP: MAC=...;Timeout=...`, `X-MAC-ADDRESS:`, or `MAC:`).
  static String extractMacFromSsdpResponse(String rawSsdp) {
    final patterns = <RegExp>[
      RegExp(
        r'WAKEUP:\s*[^;\r\n]*MAC=([0-9A-Fa-f:\-\.]{12,17})',
        caseSensitive: false,
      ),
      RegExp(
        r'X-MAC-ADDRESS:\s*([0-9A-Fa-f:\-\.]{12,17})',
        caseSensitive: false,
      ),
      RegExp(
        r'(?:^|\r?\n)MAC:\s*([0-9A-Fa-f:\-\.]{12,17})',
        caseSensitive: false,
      ),
    ];
    for (final regex in patterns) {
      final match = regex.firstMatch(rawSsdp);
      if (match != null) {
        final normalized = TvNetworkValidators.normalizeMacAddress(
          match.group(1) ?? '',
        );
        if (normalized.isNotEmpty) return normalized;
      }
    }
    return '';
  }

  /// Extracts and normalizes a MAC address from Roku ECP, UPnP, or Smart TV XML metadata.
  static String extractMacFromXmlMetadata(String xml) {
    final networkType = RegExp(
      r'<network-type(?:\s[^>]*)?>([^<]+)</network-type>',
      caseSensitive: false,
    ).firstMatch(xml)?.group(1)?.toLowerCase() ?? '';
    final preferEthernet = networkType.contains('ethernet');

    final tags = <String>[
      if (preferEthernet) ...<String>['ethernet-mac', 'wifi-mac']
      else ...<String>['wifi-mac', 'ethernet-mac'],
      'wifiMac',
      'wiredMac',
      'macAddress',
      'mac-address',
      'wakeOnLanMac',
      'X_MAC',
      'wlanMac',
      'lanMac',
      'mac',
    ];
    for (final tag in tags) {
      final match = RegExp(
        '<$tag(?:\\s[^>]*)?>([^<]+)</$tag>',
        caseSensitive: false,
      ).firstMatch(xml);
      if (match != null) {
        final normalized = TvNetworkValidators.normalizeMacAddress(
          match.group(1) ?? '',
        );
        if (normalized.isNotEmpty) return normalized;
      }
    }
    return '';
  }

  /// Extracts and normalizes a TV MAC address from Samsung `8001/api/v2/` or
  /// Google Cast `8008/setup/eureka_info` JSON metadata without reading router `bssid`.
  static String extractMacFromJsonMetadata(Map<dynamic, dynamic> json) {
    final candidates = <Map<dynamic, dynamic>>[
      if (json['device'] is Map) json['device'] as Map<dynamic, dynamic>,
      json,
    ];
    const keys = <String>[
      'wifiMac',
      'wiredMac',
      'ethernet_mac_address',
      'mac_address',
      'wifi_mac_address',
      'macAddress',
      'mac',
    ];
    for (final map in candidates) {
      for (final key in keys) {
        final raw = map[key]?.toString() ?? '';
        if (raw.isEmpty) continue;
        final normalized = TvNetworkValidators.normalizeMacAddress(raw);
        if (normalized.isNotEmpty) return normalized;
      }
    }
    return '';
  }

  /// Extracts and normalizes a MAC address from mDNS TXT records (`deviceid=...`, `mac=...`).
  static String extractMacFromMdnsPacket(Uint8List packet) {
    final tokenRegex = RegExp(
      r'(?:deviceid|wifimac|ethmac|wolmac|mac)=([0-9A-Fa-f:\-\.]{12,17})',
      caseSensitive: false,
    );
    for (final line in describeDnsRecords(packet)) {
      if (!line.startsWith('TXT ')) continue;
      for (final match in tokenRegex.allMatches(line)) {
        final normalized = TvNetworkValidators.normalizeMacAddress(
          match.group(1) ?? '',
        );
        if (normalized.isNotEmpty) return normalized;
      }
    }
    return '';
  }

  /// Extracts and normalizes a MAC address from ADB shell output (`MAC=...` or standalone MAC line).
  static String extractMacFromShellOutput(String shellOutput) {
    final lines = shellOutput
        .split(RegExp(r'\r?\n'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty);
    final macLineRegex = RegExp(r'^MAC=(.+)$', caseSensitive: false);
    for (final line in lines) {
      final m = macLineRegex.firstMatch(line);
      if (m != null) {
        final normalized = TvNetworkValidators.normalizeMacAddress(
          m.group(1) ?? '',
        );
        if (normalized.isNotEmpty) return normalized;
      }
    }
    for (final line in lines) {
      final normalized = TvNetworkValidators.normalizeMacAddress(line);
      if (normalized.isNotEmpty) return normalized;
    }
    return '';
  }
}
