import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/tv_mode_provider.dart';

/// Telefonun harici TV veya ekrana yansıtma bağlantı türü.
enum TvCastConnectionType {
  none,
  wireless,
  wired,
  airplayAudio,
}

/// Zikirce TV modu içindeki canlı ekran yansıtma (Mirroring / Cast / AirPlay) durumu.
class TvCastState {
  final bool isSupported;
  final bool isConnected;
  final bool isVisualMirroring;
  final String? deviceName;
  final TvCastConnectionType connectionType;
  final String platform;
  final bool pendingAutoPrompt;
  final bool isOpeningPicker;

  const TvCastState({
    this.isSupported = false,
    this.isConnected = false,
    this.isVisualMirroring = false,
    this.deviceName,
    this.connectionType = TvCastConnectionType.none,
    this.platform = 'other',
    this.pendingAutoPrompt = false,
    this.isOpeningPicker = false,
  });

  bool get isIos => platform == 'ios';
  bool get isAndroid => platform == 'android';

  TvCastState copyWith({
    bool? isSupported,
    bool? isConnected,
    bool? isVisualMirroring,
    String? deviceName,
    bool clearDeviceName = false,
    TvCastConnectionType? connectionType,
    String? platform,
    bool? pendingAutoPrompt,
    bool? isOpeningPicker,
  }) {
    return TvCastState(
      isSupported: isSupported ?? this.isSupported,
      isConnected: isConnected ?? this.isConnected,
      isVisualMirroring: isVisualMirroring ?? this.isVisualMirroring,
      deviceName: clearDeviceName ? null : (deviceName ?? this.deviceName),
      connectionType: connectionType ?? this.connectionType,
      platform: platform ?? this.platform,
      pendingAutoPrompt: pendingAutoPrompt ?? this.pendingAutoPrompt,
      isOpeningPicker: isOpeningPicker ?? this.isOpeningPicker,
    );
  }
}

/// Platform yansıtma kanalı için soyut geçit (DIP).
abstract class TvCastPlatformGateway {
  bool get isMobileCastPlatform;
  bool get isIosPlatform;
  Future<Map<String, dynamic>?> getCastStatus();
  Future<Map<String, dynamic>?> openCastPicker();
  void setOnStatusChanged(void Function(Map<String, dynamic> payload)? handler);
}

/// Android ve iOS yerel TV yansıtma MethodChannel adaptörü.
class MethodChannelTvCastGateway implements TvCastPlatformGateway {
  static const MethodChannel _channel =
      MethodChannel('com.akarworks.zikirce/tv_cast');

  @override
  bool get isMobileCastPlatform =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  @override
  bool get isIosPlatform => !kIsWeb && Platform.isIOS;

  @override
  Future<Map<String, dynamic>?> getCastStatus() async {
    if (!isMobileCastPlatform) return null;
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>('getCastStatus');
      return raw;
    } catch (e) {
      debugPrint('[TvCastGateway] getCastStatus error: $e');
      return null;
    }
  }

  @override
  Future<Map<String, dynamic>?> openCastPicker() async {
    if (!isMobileCastPlatform) return null;
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>('openCastPicker');
      return raw;
    } catch (e) {
      debugPrint('[TvCastGateway] openCastPicker error: $e');
      return null;
    }
  }

  @override
  void setOnStatusChanged(
    void Function(Map<String, dynamic> payload)? handler,
  ) {
    if (!isMobileCastPlatform) return;
    if (handler == null) {
      _channel.setMethodCallHandler(null);
      return;
    }
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onCastStateChanged' && call.arguments is Map) {
        final rawMap = call.arguments as Map;
        final normalized = <String, dynamic>{};
        for (final entry in rawMap.entries) {
          if (entry.key != null) {
            normalized[entry.key.toString()] = entry.value;
          }
        }
        handler(normalized);
      }
    });
  }
}

/// Canlı TV yansıtma durumunu ve sistem yansıtma seçici tetiklemelerini yönetir.
class TvCastNotifier extends StateNotifier<TvCastState> {
  final TvCastPlatformGateway _gateway;

  static const Map<String, TvCastConnectionType> _connectionTypeLookup = {
    'wireless': TvCastConnectionType.wireless,
    'wired': TvCastConnectionType.wired,
    'airplay_audio': TvCastConnectionType.airplayAudio,
    'none': TvCastConnectionType.none,
  };

  TvCastNotifier(this._gateway) : super(_initialState(_gateway)) {
    if (state.isSupported) {
      _gateway.setOnStatusChanged(_applyNativePayload);
      unawaited(refreshStatus());
    }
  }

  static TvCastState _initialState(TvCastPlatformGateway gateway) {
    if (gateway.isMobileCastPlatform && !TvModeService.isHardwareTv) {
      return TvCastState(
        isSupported: true,
        platform: gateway.isIosPlatform ? 'ios' : 'android',
      );
    }
    return const TvCastState();
  }

  void _applyNativePayload(Map<String, dynamic> payload) {
    if (!mounted) return;
    final hardwareTv = TvModeService.isHardwareTv;
    final rawSupported = payload['supported'] as bool?;
    final isSupported = !hardwareTv &&
        (rawSupported ?? _gateway.isMobileCastPlatform);
    final isConnected = payload['isConnected'] as bool? ?? false;
    final isVisualMirroring =
        payload['isVisualMirroring'] as bool? ?? isConnected;
    final rawName = (payload['deviceName'] as String?)?.trim();
    final deviceName =
        (rawName == null || rawName.isEmpty) ? null : rawName;
    final rawType = (payload['connectionType'] as String?) ?? 'none';
    final connectionType =
        _connectionTypeLookup[rawType] ?? TvCastConnectionType.none;
    final platform = (payload['platform'] as String?) ??
        (_gateway.isIosPlatform ? 'ios' : state.platform);

    state = state.copyWith(
      isSupported: isSupported,
      isConnected: isConnected,
      isVisualMirroring: isVisualMirroring,
      deviceName: deviceName,
      clearDeviceName: deviceName == null,
      connectionType: connectionType,
      platform: platform,
    );
  }

  /// Yerel işletim sisteminden güncel harici ekran / yansıtma durumunu sorgular.
  Future<void> refreshStatus() async {
    if (!state.isSupported || TvModeService.isHardwareTv) return;
    final payload = await _gateway.getCastStatus();
    if (payload != null) {
      _applyNativePayload(payload);
    }
  }

  /// Sistem TV / AirPlay yansıtma seçicisini açar ve dönüşte durumu yeniler.
  Future<bool> openCastPicker() async {
    if (!state.isSupported || state.isOpeningPicker) return false;
    state = state.copyWith(isOpeningPicker: true);
    try {
      final result = await _gateway.openCastPicker();
      await refreshStatus();
      return result?['opened'] == true;
    } finally {
      if (mounted) {
        state = state.copyWith(isOpeningPicker: false);
      }
    }
  }

  /// Ayarlar'dan TV modu açıldığında TV Hub'a girişte yansıtma penceresini önerir.
  void requestAutoPromptOnTvEntry() {
    if (!state.isSupported || TvModeService.isHardwareTv) return;
    state = state.copyWith(pendingAutoPrompt: true);
  }

  /// Tek seferlik otomatik yansıtma önerisi bayrağını tüketir.
  void consumeAutoPrompt() {
    if (state.pendingAutoPrompt) {
      state = state.copyWith(pendingAutoPrompt: false);
    }
  }

  @override
  void dispose() {
    _gateway.setOnStatusChanged(null);
    super.dispose();
  }
}

final tvCastGatewayProvider = Provider<TvCastPlatformGateway>(
  (ref) => MethodChannelTvCastGateway(),
);

final tvCastProvider = StateNotifierProvider<TvCastNotifier, TvCastState>(
  (ref) => TvCastNotifier(ref.watch(tvCastGatewayProvider)),
);
