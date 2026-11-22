import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/tv_driver_contract.dart';
import '../../domain/tv_network_validators.dart';

/// Encrypted persistent vault for Smart TV pairing tokens (Samsung Tizen `token`,
/// LG webOS `client-key`, Sony `PSK`) backed by `AndroidKeyStore` (`com.akarworks.cuedeck/storage`)
/// with a deterministic SharedPreferences fallback on headless test runners / non-Android platforms.
class EncryptedTvSecretVault implements TvSecretVault {
  EncryptedTvSecretVault();

  static const MethodChannel _storageChannel = MethodChannel(
    'com.akarworks.cuedeck/storage',
  );
  static const String _prefsPrefix = 'cuedeck_tv_secret_v1_';

  final Map<String, String> _memoryCache = <String, String>{};

  @override
  Future<String?> readSecret(String key) async {
    final cleanKey = key.trim();
    if (cleanKey.isEmpty) return null;
    if (_memoryCache.containsKey(cleanKey)) {
      return _memoryCache[cleanKey];
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_prefsPrefix$cleanKey');
      if (raw == null || raw.isEmpty) return null;

      if (raw.startsWith('plain:')) {
        final val = raw.substring(6);
        _memoryCache[cleanKey] = val;
        return val;
      }

      try {
        final decrypted = await _storageChannel.invokeMethod<String>(
          'decryptSecret',
          <String, dynamic>{'cipherText': raw},
        );
        if (decrypted != null && decrypted.isNotEmpty) {
          _memoryCache[cleanKey] = decrypted;
          return decrypted;
        }
      } catch (e) {
        debugPrint('TvSecretVault decrypt fallback ($cleanKey): $e');
      }
      return raw;
    } catch (e) {
      debugPrint('TvSecretVault readSecret error ($cleanKey): $e');
      return null;
    }
  }

  @override
  Future<void> writeSecret(String key, String value) async {
    final cleanKey = key.trim();
    final cleanVal = value.trim();
    if (cleanKey.isEmpty || cleanVal.isEmpty) return;

    _memoryCache[cleanKey] = cleanVal;
    try {
      String toPersist = 'plain:$cleanVal';
      try {
        final encrypted = await _storageChannel.invokeMethod<String>(
          'encryptSecret',
          <String, dynamic>{'plainText': cleanVal},
        );
        if (encrypted != null && encrypted.isNotEmpty) {
          toPersist = encrypted;
        }
      } catch (e) {
        debugPrint('TvSecretVault encrypt fallback ($cleanKey): $e');
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_prefsPrefix$cleanKey', toPersist);
    } catch (e) {
      debugPrint('TvSecretVault writeSecret error ($cleanKey): $e');
    }
  }

  @override
  Future<void> deleteSecret(String key) async {
    final cleanKey = key.trim();
    if (cleanKey.isEmpty) return;
    _memoryCache.remove(cleanKey);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_prefsPrefix$cleanKey');
    } catch (e) {
      debugPrint('TvSecretVault deleteSecret error ($cleanKey): $e');
    }
  }
}

/// Pure-Dart Wake-on-LAN (WoL) 102-byte magic packet builder and UDP broadcaster.
class WakeOnLanService {
  WakeOnLanService._();

  /// Builds a standard 102-byte Wake-on-LAN magic packet (`6x 0xFF` + `16x MAC`).
  static Uint8List buildMagicPacket(String macAddress) {
    final cleanMac = TvNetworkValidators.normalizeMacAddress(macAddress);
    if (cleanMac.isEmpty) {
      return Uint8List(0);
    }
    final cleanHex = cleanMac.replaceAll(':', '');
    final macBytes = Uint8List(6);
    for (var i = 0; i < 6; i++) {
      macBytes[i] = int.parse(cleanHex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    final packet = Uint8List(102);
    for (var i = 0; i < 6; i++) {
      packet[i] = 0xFF;
    }
    for (var rep = 0; rep < 16; rep++) {
      packet.setRange(6 + rep * 6, 12 + rep * 6, macBytes);
    }
    return packet;
  }

  /// Sends a Wake-on-LAN magic packet to [macAddress] via broadcast (`255.255.255.255`)
  /// and subnet directed broadcast (`x.x.x.255`) on ports `9` and `7`.
  static Future<bool> sendMagicPacket(
    String macAddress, {
    String? targetIp,
    String? localSubnetIp,
    int burstCount = 2,
  }) async {
    final cleanMac = TvNetworkValidators.normalizeMacAddress(macAddress);
    if (cleanMac.isEmpty) {
      return false;
    }
    final packet = buildMagicPacket(cleanMac);
    if (packet.length != 102) return false;

    final targets = <String>{'255.255.255.255'};
    var hasDirectedBroadcast = false;
    void addDirectedSubnet(String? ip) {
      final clean = ip?.trim() ?? '';
      if (!TvNetworkValidators.isValidIp(clean)) return;
      final parts = clean.split('.');
      if (parts.length == 4) {
        targets.add('${parts[0]}.${parts[1]}.${parts[2]}.255');
        hasDirectedBroadcast = true;
      }
    }

    addDirectedSubnet(targetIp);
    addDirectedSubnet(localSubnetIp);

    if (!hasDirectedBroadcast &&
        !Platform.environment.containsKey('FLUTTER_TEST')) {
      try {
        final interfaces = await NetworkInterface.list(
          type: InternetAddressType.IPv4,
          includeLoopback: false,
        );
        for (final iface in interfaces) {
          final lowerName = iface.name.toLowerCase();
          final isCellularOrTunnel =
              lowerName.startsWith('pdp') ||
              lowerName.startsWith('utun') ||
              lowerName.startsWith('awdl') ||
              lowerName.contains('vethernet');
          if (isCellularOrTunnel) continue;
          for (final addr in iface.addresses) {
            final ip = addr.address.trim();
            if (TvNetworkValidators.isPrivateLanIp(ip) &&
                !ip.startsWith('127.')) {
              addDirectedSubnet(ip);
            }
          }
        }
      } catch (e) {
        debugPrint('WakeOnLanService interface discovery error: $e');
      }
    }

    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;
      var sent = false;
      final passes = burstCount.clamp(1, 3);
      for (var pass = 0; pass < passes; pass++) {
        for (final host in targets) {
          final addr = InternetAddress(host);
          for (final port in const <int>[9, 7]) {
            final n = socket.send(packet, addr, port);
            if (n > 0) sent = true;
          }
        }
      }
      return sent;
    } catch (e) {
      debugPrint('WakeOnLanService send error: $e');
      return false;
    } finally {
      socket?.close();
    }
  }
}
