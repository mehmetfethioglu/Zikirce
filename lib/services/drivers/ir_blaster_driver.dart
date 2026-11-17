import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../domain/tv_driver_contract.dart';
import '../../models/cue_models.dart';

/// Profile describing a supported Android IR Blaster television brand.
@immutable
class IrBrandProfile {
  const IrBrandProfile({
    required this.code,
    required this.displayName,
    required this.protocolName,
    required this.carrierHz,
    required this.customCode,
    required this.commands,
  });

  final String code;
  final String displayName;
  final String protocolName; // 'nec' | 'samsung32' | 'rc5' | 'sony12'
  final int carrierHz;
  final int customCode;
  final Map<TvKeyCommand, int> commands;
}

/// Zero-Wi-Fi Android hardware Infrared Blaster driver (`ConsumerIrManager`)
/// supporting Arçelik/Beko, Vestel/Regal, Samsung, LG, Sony, Philips, and TCL/Sunny/Onvo.
class IrBlasterDriver implements TvRemoteDriver {
  IrBlasterDriver({TvDiagLogger? logger}) : _log = logger;

  static const MethodChannel _irChannel = MethodChannel(
    'com.akarworks.cuedeck/ir',
  );

  final TvDiagLogger? _log;
  bool? _cachedHasEmitter;

  @override
  TvConnectionProtocol get protocol => TvConnectionProtocol.irBlasterHardware;

  @override
  Set<TvCapability> get capabilities => const <TvCapability>{
        TvCapability.keyNavigation,
        TvCapability.irBlaster,
      };

  static const Map<TvKeyCommand, int> _standardNecKeys = <TvKeyCommand, int>{
    TvKeyCommand.power: 0x08,
    TvKeyCommand.mute: 0x09,
    TvKeyCommand.volUp: 0x02,
    TvKeyCommand.volDown: 0x03,
    TvKeyCommand.channelUp: 0x00,
    TvKeyCommand.channelDown: 0x01,
    TvKeyCommand.up: 0x40,
    TvKeyCommand.down: 0x41,
    TvKeyCommand.left: 0x07,
    TvKeyCommand.right: 0x06,
    TvKeyCommand.ok: 0x44,
    TvKeyCommand.back: 0x28,
    TvKeyCommand.home: 0x7C,
    TvKeyCommand.menu: 0x43,
    TvKeyCommand.inputs: 0x0B,
    TvKeyCommand.playPause: 0xB0,
    TvKeyCommand.rewind: 0x8F,
    TvKeyCommand.fastForward: 0x8E,
  };

  static final Map<String, IrBrandProfile> brandProfiles =
      <String, IrBrandProfile>{
    'arcelik_beko': const IrBrandProfile(
      code: 'arcelik_beko',
      displayName: 'Arçelik / Beko / Grundig',
      protocolName: 'rc5',
      carrierHz: 36000,
      customCode: 0x00,
      commands: <TvKeyCommand, int>{
        TvKeyCommand.power: 0x0C,
        TvKeyCommand.mute: 0x0D,
        TvKeyCommand.volUp: 0x10,
        TvKeyCommand.volDown: 0x11,
        TvKeyCommand.channelUp: 0x20,
        TvKeyCommand.channelDown: 0x21,
        TvKeyCommand.up: 0x50,
        TvKeyCommand.down: 0x51,
        TvKeyCommand.left: 0x55,
        TvKeyCommand.right: 0x56,
        TvKeyCommand.ok: 0x57,
        TvKeyCommand.back: 0x0A,
        TvKeyCommand.home: 0x54,
        TvKeyCommand.menu: 0x52,
        TvKeyCommand.inputs: 0x38,
        TvKeyCommand.playPause: 0x35,
        TvKeyCommand.rewind: 0x32,
        TvKeyCommand.fastForward: 0x34,
      },
    ),
    'vestel_regal': const IrBrandProfile(
      code: 'vestel_regal',
      displayName: 'Vestel / Regal / Toshiba / JVC',
      protocolName: 'rc5',
      carrierHz: 36000,
      customCode: 0x00,
      commands: <TvKeyCommand, int>{
        TvKeyCommand.power: 0x0C,
        TvKeyCommand.mute: 0x0D,
        TvKeyCommand.volUp: 0x10,
        TvKeyCommand.volDown: 0x11,
        TvKeyCommand.channelUp: 0x20,
        TvKeyCommand.channelDown: 0x21,
        TvKeyCommand.up: 0x14,
        TvKeyCommand.down: 0x13,
        TvKeyCommand.left: 0x15,
        TvKeyCommand.right: 0x16,
        TvKeyCommand.ok: 0x35,
        TvKeyCommand.back: 0x0A,
        TvKeyCommand.home: 0x3B,
        TvKeyCommand.menu: 0x30,
        TvKeyCommand.inputs: 0x38,
        TvKeyCommand.playPause: 0x32,
      },
    ),
    'samsung': const IrBrandProfile(
      code: 'samsung',
      displayName: 'Samsung TV',
      protocolName: 'samsung32',
      carrierHz: 38000,
      customCode: 0x0707,
      commands: <TvKeyCommand, int>{
        TvKeyCommand.power: 0x02,
        TvKeyCommand.mute: 0x0F,
        TvKeyCommand.volUp: 0x07,
        TvKeyCommand.volDown: 0x0B,
        TvKeyCommand.channelUp: 0x12,
        TvKeyCommand.channelDown: 0x10,
        TvKeyCommand.up: 0x60,
        TvKeyCommand.down: 0x61,
        TvKeyCommand.left: 0x65,
        TvKeyCommand.right: 0x62,
        TvKeyCommand.ok: 0x68,
        TvKeyCommand.back: 0x58,
        TvKeyCommand.home: 0x79,
        TvKeyCommand.menu: 0x1A,
        TvKeyCommand.inputs: 0x01,
        TvKeyCommand.playPause: 0x47,
        TvKeyCommand.rewind: 0x45,
        TvKeyCommand.fastForward: 0x48,
      },
    ),
    'lg': const IrBrandProfile(
      code: 'lg',
      displayName: 'LG TV',
      protocolName: 'nec',
      carrierHz: 38000,
      customCode: 0x20DF,
      commands: _standardNecKeys,
    ),
    'sony': const IrBrandProfile(
      code: 'sony',
      displayName: 'Sony TV',
      protocolName: 'sony12',
      carrierHz: 40000,
      customCode: 0x01,
      commands: <TvKeyCommand, int>{
        TvKeyCommand.power: 0x15,
        TvKeyCommand.mute: 0x14,
        TvKeyCommand.volUp: 0x12,
        TvKeyCommand.volDown: 0x13,
        TvKeyCommand.channelUp: 0x10,
        TvKeyCommand.channelDown: 0x11,
        TvKeyCommand.up: 0x74,
        TvKeyCommand.down: 0x75,
        TvKeyCommand.left: 0x34,
        TvKeyCommand.right: 0x33,
        TvKeyCommand.ok: 0x65,
        TvKeyCommand.back: 0x63,
        TvKeyCommand.home: 0x60,
        TvKeyCommand.menu: 0x60,
        TvKeyCommand.inputs: 0x25,
        TvKeyCommand.playPause: 0x1A,
      },
    ),
    'philips': const IrBrandProfile(
      code: 'philips',
      displayName: 'Philips TV',
      protocolName: 'rc5',
      carrierHz: 36000,
      customCode: 0x00,
      commands: <TvKeyCommand, int>{
        TvKeyCommand.power: 0x0C,
        TvKeyCommand.mute: 0x0D,
        TvKeyCommand.volUp: 0x10,
        TvKeyCommand.volDown: 0x11,
        TvKeyCommand.channelUp: 0x20,
        TvKeyCommand.channelDown: 0x21,
        TvKeyCommand.up: 0x50,
        TvKeyCommand.down: 0x51,
        TvKeyCommand.left: 0x55,
        TvKeyCommand.right: 0x56,
        TvKeyCommand.ok: 0x57,
        TvKeyCommand.back: 0x0A,
        TvKeyCommand.home: 0x54,
        TvKeyCommand.menu: 0x52,
        TvKeyCommand.inputs: 0x38,
      },
    ),
    'tcl_sunny_onvo': const IrBrandProfile(
      code: 'tcl_sunny_onvo',
      displayName: 'TCL / Sunny / Onvo / Axen',
      protocolName: 'nec',
      carrierHz: 38000,
      customCode: 0x04FB,
      commands: _standardNecKeys,
    ),
  };

  /// Encodes a standard 38 kHz NEC 32-bit IR frame (mark/space durations in microseconds).
  static List<int> buildNecFrame(int address16, int command8) {
    final addrLow = (address16 >> 8) & 0xFF;
    final addrHigh = address16 & 0xFF;
    final bits = <int>[
      addrLow,
      addrHigh == 0 ? (~addrLow & 0xFF) : addrHigh,
      command8 & 0xFF,
      (~command8) & 0xFF,
    ];
    final pulses = <int>[9000, 4500];
    for (final byteVal in bits) {
      for (var bit = 0; bit < 8; bit++) {
        pulses.add(560);
        pulses.add(((byteVal >> bit) & 1) == 1 ? 1690 : 560);
      }
    }
    pulses.add(560);
    return pulses;
  }

  /// Encodes a Samsung-32 IR frame (`4500us / 4500us` leader + 32 data bits).
  static List<int> buildSamsung32Frame(int custom16, int command8) {
    final c1 = (custom16 >> 8) & 0xFF;
    final c2 = custom16 & 0xFF;
    final bytes = <int>[c1, c2, command8 & 0xFF, (~command8) & 0xFF];
    final pulses = <int>[4500, 4500];
    for (final b in bytes) {
      for (var bit = 0; bit < 8; bit++) {
        pulses.add(560);
        pulses.add(((b >> bit) & 1) == 1 ? 1690 : 560);
      }
    }
    pulses.add(560);
    return pulses;
  }

  /// Encodes a Philips / Arçelik / Vestel RC-5 Manchester IR frame (`889us` half-bit).
  static List<int> buildRc5Frame(int address5, int command6) {
    final word =
        (1 << 13) | (1 << 12) | ((address5 & 0x1F) << 6) | (command6 & 0x3F);
    final rawTransitions = <int>[];
    for (var i = 13; i >= 0; i--) {
      final bit = (word >> i) & 1;
      if (bit == 1) {
        rawTransitions.addAll(const <int>[0, 1]); // space then mark
      } else {
        rawTransitions.addAll(const <int>[1, 0]); // mark then space
      }
    }
    // Strip leading space (bit 14 starts with mark on air)
    var idx = 0;
    while (idx < rawTransitions.length && rawTransitions[idx] == 0) {
      idx++;
    }
    final pulses = <int>[];
    if (idx < rawTransitions.length) {
      var curLevel = rawTransitions[idx];
      var count = 0;
      for (var i = idx; i < rawTransitions.length; i++) {
        if (rawTransitions[i] == curLevel) {
          count++;
        } else {
          pulses.add(count * 889);
          curLevel = rawTransitions[i];
          count = 1;
        }
      }
      pulses.add(count * 889);
    }
    if (pulses.length.isEven) {
      pulses.add(889);
    }
    return pulses;
  }

  /// Encodes a 12-bit Sony SIRC 40 kHz IR frame (`2400us` leader + 7-bit cmd + 5-bit addr).
  static List<int> buildSony12Frame(int address5, int command7) {
    final word = ((address5 & 0x1F) << 7) | (command7 & 0x7F);
    final pulses = <int>[2400, 600];
    for (var i = 0; i < 12; i++) {
      final bit = (word >> i) & 1;
      pulses.add(bit == 1 ? 1200 : 600);
      if (i < 11) pulses.add(600);
    }
    return pulses;
  }

  /// Builds the exact microsecond IR pulse pattern + carrier frequency for a [TvDevice] & [TvKeyCommand].
  static ({int carrierHz, List<int> pattern})? buildPatternForDevice(
    TvDevice device,
    TvKeyCommand command,
  ) {
    final profile =
        brandProfiles[device.irBrandCode.trim()] ?? brandProfiles['arcelik_beko']!;
    final cmdCode = profile.commands[command];
    if (cmdCode == null) return null;

    final List<int> pattern;
    switch (profile.protocolName) {
      case 'samsung32':
        pattern = buildSamsung32Frame(profile.customCode, cmdCode);
      case 'rc5':
        pattern = buildRc5Frame(profile.customCode, cmdCode);
      case 'sony12':
        pattern = buildSony12Frame(profile.customCode, cmdCode);
      default:
        pattern = buildNecFrame(profile.customCode, cmdCode);
    }
    return (carrierHz: profile.carrierHz, pattern: pattern);
  }

  /// Checks whether this Android device includes a physical IR Blaster (`ConsumerIrManager`).
  Future<bool> hasIrEmitter() async {
    if (_cachedHasEmitter != null) return _cachedHasEmitter!;
    if (!Platform.isAndroid || Platform.environment.containsKey('FLUTTER_TEST')) {
      _cachedHasEmitter = false;
      return false;
    }
    try {
      final supported = await _irChannel.invokeMethod<bool>('hasIrEmitter');
      _cachedHasEmitter = supported ?? false;
      return _cachedHasEmitter!;
    } catch (e) {
      _log?.call('IR donanım sorgu hatası: $e');
      _cachedHasEmitter = false;
      return false;
    }
  }

  @override
  Future<TvDevice> pair(TvDevice device, {String? pinCode}) async {
    final brand =
        brandProfiles[device.irBrandCode.trim()] ?? brandProfiles['arcelik_beko']!;
    return device.copyWith(
      name: '${brand.displayName} (Kızılötesi)',
      ip: '',
      port: 0,
      protocol: TvConnectionProtocol.irBlasterHardware,
      irBrandCode: brand.code,
      isPaired: true,
      isOnline: true,
      boardInfo: 'Kızılötesi (IR) • Wi-Fi Gerektirmez',
    );
  }

  @override
  Future<bool> sendKey(TvDevice device, TvKeyCommand command) async {
    final payload = buildPatternForDevice(device, command);
    if (payload == null) return false;
    if (!Platform.isAndroid || Platform.environment.containsKey('FLUTTER_TEST')) {
      return false;
    }
    try {
      final ok = await _irChannel.invokeMethod<bool>(
        'transmitIr',
        <String, Object?>{
          'carrierHz': payload.carrierHz,
          'pattern': payload.pattern,
        },
      );
      return ok ?? false;
    } catch (e) {
      _log?.call('IR iletim hatası: $e');
      return false;
    }
  }

  @override
  Future<bool> movePointer(TvDevice device, double dx, double dy) async =>
      false;

  @override
  Future<bool> clickPointer(
    TvDevice device, {
    bool rightClick = false,
  }) async =>
      sendKey(device, rightClick ? TvKeyCommand.back : TvKeyCommand.ok);

  @override
  Future<bool> scrollWheel(TvDevice device, int wheelClicks) async => sendKey(
        device,
        wheelClicks > 0 ? TvKeyCommand.up : TvKeyCommand.down,
      );

  @override
  Future<bool> sendText(
    TvDevice device,
    String text, {
    bool submitEnter = false,
  }) async =>
      false;

  @override
  Future<bool> sendBackspace(TvDevice device, {int count = 1}) =>
      sendKey(device, TvKeyCommand.back);

  @override
  Future<bool> sendEnter(TvDevice device) => sendKey(device, TvKeyCommand.ok);

  @override
  Future<bool> launchContent(
    TvDevice device, {
    required StreamingPlatform platform,
    String deepLinkUrl = '',
    String fallbackSearchQuery = '',
  }) async =>
      false;

  @override
  Future<bool> wakeOnLan(TvDevice device) => sendKey(device, TvKeyCommand.power);

  @override
  void dispose() {}
}
