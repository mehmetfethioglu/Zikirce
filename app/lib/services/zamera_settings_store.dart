import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/zamera_preferences.dart';

/// Dependency-inverted persistence contract for [ZameraPreferences].
abstract interface class ZameraSettingsRepository {
  Future<ZameraPreferences> load();

  Future<bool> save(ZameraPreferences preferences);

  Future<bool> reset();
}

/// Production [SharedPreferences]-backed implementation of [ZameraSettingsRepository]
/// with deterministic timeouts and fault-tolerant JSON recovery.
class SharedPrefsZameraSettingsStore implements ZameraSettingsRepository {
  static const String defaultStorageKey = 'zamera_preferences_v1';
  static const Duration _ioTimeout = Duration(seconds: 3);

  final String storageKey;

  const SharedPrefsZameraSettingsStore({
    this.storageKey = defaultStorageKey,
  });

  @override
  Future<ZameraPreferences> load() async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(_ioTimeout);
      final rawJson = prefs.getString(storageKey);
      if (rawJson == null || rawJson.trim().isEmpty) {
        return ZameraPreferences.defaults;
      }
      final decoded = jsonDecode(rawJson);
      if (decoded is! Map<Object?, Object?>) {
        return ZameraPreferences.defaults;
      }
      return ZameraPreferences.fromJson(decoded);
    } catch (e, st) {
      debugPrint('SharedPrefsZameraSettingsStore.load error: $e\n$st');
      return ZameraPreferences.defaults;
    }
  }

  @override
  Future<bool> save(ZameraPreferences preferences) async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(_ioTimeout);
      final encoded = jsonEncode(preferences.toJson());
      return await prefs.setString(storageKey, encoded).timeout(_ioTimeout);
    } catch (e, st) {
      debugPrint('SharedPrefsZameraSettingsStore.save error: $e\n$st');
      return false;
    }
  }

  @override
  Future<bool> reset() async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(_ioTimeout);
      return await prefs.remove(storageKey).timeout(_ioTimeout);
    } catch (e, st) {
      debugPrint('SharedPrefsZameraSettingsStore.reset error: $e\n$st');
      return false;
    }
  }
}

/// Deterministic in-memory implementation of [ZameraSettingsRepository] for tests and previews.
class InMemoryZameraSettingsStore implements ZameraSettingsRepository {
  ZameraPreferences _current;

  InMemoryZameraSettingsStore([
    ZameraPreferences initial = ZameraPreferences.defaults,
  ]) : _current = initial;

  ZameraPreferences get current => _current;

  @override
  Future<ZameraPreferences> load() async => _current;

  @override
  Future<bool> save(ZameraPreferences preferences) async {
    _current = preferences;
    return true;
  }

  @override
  Future<bool> reset() async {
    _current = ZameraPreferences.defaults;
    return true;
  }
}
