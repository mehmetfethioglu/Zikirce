import 'dart:convert';
import 'dart:typed_data';

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
}
