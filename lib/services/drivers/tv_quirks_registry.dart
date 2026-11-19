import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/cue_models.dart';

/// Immutable remote control / protocol compatibility profile for an OEM TV chassis.
@immutable
class TvQuirkProfile {
  const TvQuirkProfile({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.protocol,
    required this.port,
    this.brandKeywords = const <String>[],
    this.useDialFirst = true,
    this.keyOverrides = const <String, String>{},
  });

  final String id;
  final String label;
  final String subtitle;
  final TvConnectionProtocol protocol;
  final int port;
  final List<String> brandKeywords;
  final bool useDialFirst;
  final Map<String, String> keyOverrides;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'label': label,
        'subtitle': subtitle,
        'protocol': protocol.name,
        'port': port,
        'brandKeywords': brandKeywords,
        'useDialFirst': useDialFirst,
        'keyOverrides': keyOverrides,
      };

  static TvQuirkProfile? tryFromJson(Map<String, dynamic> map) {
    final id = map['id']?.toString().trim() ?? '';
    final label = map['label']?.toString().trim() ?? '';
    final subtitle = map['subtitle']?.toString().trim() ?? '';
    final protoName = map['protocol']?.toString().trim() ?? '';
    final rawPort = map['port'];
    final port = rawPort is int ? rawPort : int.tryParse('$rawPort') ?? -1;
    if (id.isEmpty || label.isEmpty || port < 0 || port > 65535) {
      return null;
    }

    TvConnectionProtocol? resolvedProto;
    for (final p in TvConnectionProtocol.values) {
      if (p.name == protoName) {
        resolvedProto = p;
        break;
      }
    }
    if (resolvedProto == null) return null;

    final keywords = <String>[];
    final rawKeywords = map['brandKeywords'];
    if (rawKeywords is List) {
      for (final k in rawKeywords) {
        final clean = k.toString().trim().toLowerCase();
        if (clean.isNotEmpty) keywords.add(clean);
      }
    }

    final overrides = <String, String>{};
    final rawOverrides = map['keyOverrides'];
    if (rawOverrides is Map) {
      for (final entry in rawOverrides.entries) {
        final k = entry.key.toString().trim();
        final v = entry.value.toString().trim();
        if (k.isNotEmpty && v.isNotEmpty) overrides[k] = v;
      }
    }

    return TvQuirkProfile(
      id: id,
      label: label,
      subtitle: subtitle.isEmpty ? resolvedProto.label : subtitle,
      protocol: resolvedProto,
      port: port,
      brandKeywords: List<String>.unmodifiable(keywords),
      useDialFirst: map['useDialFirst'] is bool
          ? map['useDialFirst'] as bool
          : true,
      keyOverrides: Map<String, String>.unmodifiable(overrides),
    );
  }
}

/// OTA-updatable OCP registry holding global Smart TV protocol & chassis quirks.
/// Starts with compiled golden defaults and safely merges validated JSON overrides
/// from `SharedPreferences` or an optional remote manifest without risking regressions.
class TvQuirksRegistry {
  static const String prefsOtaKey = 'cuedeck_tv_quirks_ota_v1';

  static const List<TvQuirkProfile> defaultProfiles = <TvQuirkProfile>[
    TvQuirkProfile(
      id: 'vestel_56789',
      label: 'Vestel / Regal SmartCenter (56789)',
      subtitle: 'Türkiye & Avrupa Vestel OEM şasileri • XML + DIAL',
      protocol: TvConnectionProtocol.vestelSmart56789,
      port: 56789,
      brandKeywords: <String>[
        'vestel',
        'regal',
        'toshiba',
        'telefunken',
        'jvc',
        'finlux',
        'hi-level',
        'seg',
      ],
    ),
    TvQuirkProfile(
      id: 'vestel_alt_56791',
      label: 'Vestel / Regal Alternatif Port (56791)',
      subtitle: 'Yeni nesil Regal/Toshiba vr/remote XML uç noktası',
      protocol: TvConnectionProtocol.vestelSmart56789,
      port: 56791,
      brandKeywords: <String>['vestel', 'regal', 'toshiba', 'jvc', 'telefunken'],
    ),
    TvQuirkProfile(
      id: 'arcelik_8085',
      label: 'Arçelik / Beko / Grundig (8085)',
      subtitle: 'Smart Inter@ctive RC paketi + UPnP medya kontrolü',
      protocol: TvConnectionProtocol.arcelikGrundig8085,
      port: 8085,
      brandKeywords: <String>['arcelik', 'arçelik', 'beko', 'grundig', 'altus'],
    ),
    TvQuirkProfile(
      id: 'samsung_tizen_8002',
      label: 'Samsung Smart TV • Tizen (8002)',
      subtitle: 'WSS şifreli WebSocket + token eşleştirmesi',
      protocol: TvConnectionProtocol.samsungTizen8001,
      port: 8002,
      brandKeywords: <String>['samsung', 'tizen', 'qled', 'crystal uhd'],
    ),
    TvQuirkProfile(
      id: 'lg_webos_3000',
      label: 'LG Smart TV • webOS (3000)',
      subtitle: 'SSAP WebSocket + imleç & kanal tuşları',
      protocol: TvConnectionProtocol.lgWebOs3000,
      port: 3000,
      brandKeywords: <String>['lg', 'webos', 'nanocell', 'oled'],
    ),
    TvQuirkProfile(
      id: 'philips_v6_1926',
      label: 'Philips JointSpace v6 • HTTPS + PIN (1926)',
      subtitle: '2016+ Android & Saphi TV 4 haneli PIN + Digest Auth',
      protocol: TvConnectionProtocol.philipsJointSpace1925,
      port: 1926,
      brandKeywords: <String>['philips', 'jointspace', 'saphi', 'ambilight'],
    ),
    TvQuirkProfile(
      id: 'philips_v1_1925',
      label: 'Philips Klasik JointSpace v1 (1925)',
      subtitle: 'Eski model Philips TV\'ler için şifresiz REST API',
      protocol: TvConnectionProtocol.philipsJointSpace1925,
      port: 1925,
      brandKeywords: <String>['philips', 'jointspace'],
    ),
    TvQuirkProfile(
      id: 'vidaa_mqtt_36669',
      label: 'Hisense / Toshiba VIDAA • MQTT TLS (36669)',
      subtitle: 'VIDAA U4–U8 şifreli MQTT + 4 haneli PIN desteği',
      protocol: TvConnectionProtocol.vidaaSmart36669,
      port: 36669,
      brandKeywords: <String>['hisense', 'vidaa', 'toshiba'],
    ),
    TvQuirkProfile(
      id: 'sony_bravia_ircc',
      label: 'Sony BRAVIA • IRCC SOAP + PSK (80)',
      subtitle: 'Pre-Shared Key SOAP IRCC kontrolü',
      protocol: TvConnectionProtocol.sonyBraviaIrcc,
      port: 80,
      brandKeywords: <String>['sony', 'bravia'],
    ),
    TvQuirkProfile(
      id: 'roku_ecp_8060',
      label: 'Roku OS & Evrensel ECP/DIAL (8060)',
      subtitle: 'TCL / Hisense Roku TV • Sıfır eşleşme HTTP API',
      protocol: TvConnectionProtocol.rokuEcp8060,
      port: 8060,
      brandKeywords: <String>['roku', 'tcl', 'hisense', 'onn', 'sharp'],
    ),
    TvQuirkProfile(
      id: 'android_tv_pin_6466',
      label: 'Google TV / Android TV • PIN (6466)',
      subtitle: 'Perakende TV\'lerde Geliştirici Seçeneği olmadan çalışır',
      protocol: TvConnectionProtocol.remotePort6466,
      port: 6466,
      brandKeywords: <String>[
        'google tv',
        'android',
        'tcl',
        'xiaomi',
        'mi tv',
        'sony',
        'philips',
        'vestel',
        'onvo',
      ],
    ),
    TvQuirkProfile(
      id: 'android_tv_adb_5555',
      label: 'Android TV • ADB Turbo & İmleç (5555)',
      subtitle: 'Tam klavye, fare oku ve derin bağlantı desteği',
      protocol: TvConnectionProtocol.adbPort5555,
      port: 5555,
      brandKeywords: <String>['android', 'google tv', 'xiaomi', 'mi box', 'tcl'],
    ),
    TvQuirkProfile(
      id: 'upnp_dlna_1900',
      label: 'Evrensel UPnP / DLNA Medya (1900)',
      subtitle: 'Ses, Sessiz ve Oynat/Durdur evrensel SOAP yedeği',
      protocol: TvConnectionProtocol.upnpDlnaControl,
      port: 1900,
      brandKeywords: <String>[],
    ),
  ];

  int _schemaVersion = 1;
  List<TvQuirkProfile> _profiles = List<TvQuirkProfile>.of(defaultProfiles);

  int get schemaVersion => _schemaVersion;

  List<TvQuirkProfile> get activeProfiles =>
      List<TvQuirkProfile>.unmodifiable(_profiles);

  /// Validates and merges an OTA quirks JSON document onto compiled defaults.
  /// Returns `false` cleanly on invalid JSON without corrupting existing profiles.
  bool applyOtaJson(String rawJson) {
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is! Map<String, dynamic>) return false;
      final version = decoded['schemaVersion'] is int
          ? decoded['schemaVersion'] as int
          : _schemaVersion;
      final rawList = decoded['profiles'];
      if (rawList is! List || rawList.isEmpty) return false;

      final parsedOverrides = <TvQuirkProfile>[];
      for (final item in rawList) {
        if (item is Map<String, dynamic>) {
          final parsed = TvQuirkProfile.tryFromJson(item);
          if (parsed != null) parsedOverrides.add(parsed);
        } else if (item is Map) {
          final parsed = TvQuirkProfile.tryFromJson(
            Map<String, dynamic>.from(item),
          );
          if (parsed != null) parsedOverrides.add(parsed);
        }
      }
      if (parsedOverrides.isEmpty) return false;

      final mergedById = <String, TvQuirkProfile>{
        for (final p in defaultProfiles) p.id: p,
      };
      for (final p in parsedOverrides) {
        mergedById[p.id] = p;
      }

      _schemaVersion = version;
      _profiles = List<TvQuirkProfile>.of(mergedById.values);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> loadCachedOverrides() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(prefsOtaKey);
      if (raw == null || raw.isEmpty) return false;
      return applyOtaJson(raw);
    } catch (_) {
      return false;
    }
  }

  Future<bool> saveOtaJson(String rawJson) async {
    if (!applyOtaJson(rawJson)) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefsOtaKey, rawJson);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> refreshFromRemote(
    Uri url, {
    Duration timeout = const Duration(seconds: 6),
  }) async {
    if (url.scheme != 'https' && url.scheme != 'http') return false;
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final req = await client.getUrl(url).timeout(timeout);
      final resp = await req.close().timeout(timeout);
      if (resp.statusCode != 200) return false;
      final raw = await resp.transform(utf8.decoder).join().timeout(timeout);
      return saveOtaJson(raw);
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }

  /// Returns candidate profiles ordered so regional OEM siblings & brand matches
  /// appear first, excluding [device]'s exact current `(protocol, port)` unless none match.
  List<TvQuirkProfile> suggestedAlternativeProfiles(TvDevice device) {
    final hay = '${device.name} ${device.boardInfo}'.toLowerCase();

    int scoreProfile(TvQuirkProfile profile) {
      var score = 0;
      for (final kw in profile.brandKeywords) {
        if (hay.contains(kw)) score += 10;
      }
      if (profile.protocol == device.protocol && profile.port != device.port) {
        score += 15;
      }
      if (device.protocol == TvConnectionProtocol.vestelSmart56789 &&
          (profile.protocol == TvConnectionProtocol.upnpDlnaControl ||
              profile.protocol == TvConnectionProtocol.remotePort6466)) {
        score += 4;
      }
      return score;
    }

    final candidates = _profiles
        .where((p) => !(p.protocol == device.protocol && p.port == device.port))
        .toList();
    candidates.sort((a, b) => scoreProfile(b).compareTo(scoreProfile(a)));
    return List<TvQuirkProfile>.unmodifiable(candidates);
  }
}
