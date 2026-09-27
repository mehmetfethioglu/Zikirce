import 'package:shared_preferences/shared_preferences.dart';

/// Type-safe SharedPreferences utility that handles inconsistent types
/// (e.g. Strings stored in XML from .NET MAUI migrations, JSON decodes, or previous versions).
class PrefUtils {
  /// Safely gets an int value. Parses String, num, double, bool safely without casting errors.
  static int getInt(SharedPreferences prefs, String key, [int defaultValue = 0]) {
    final value = prefs.get(key);
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final trimmed = value.trim();
      final parsed = int.tryParse(trimmed);
      if (parsed != null) return parsed;
      final doubleParsed = double.tryParse(trimmed);
      if (doubleParsed != null) return doubleParsed.toInt();
    }
    if (value is bool) return value ? 1 : 0;
    return defaultValue;
  }

  /// Safely gets an int or null if not found or unparseable.
  static int? getIntOrNull(SharedPreferences prefs, String key) {
    final value = prefs.get(key);
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      final parsed = int.tryParse(trimmed);
      if (parsed != null) return parsed;
      final doubleParsed = double.tryParse(trimmed);
      if (doubleParsed != null) return doubleParsed.toInt();
    }
    return null;
  }

  /// Safely gets a double value. Parses String, num, int safely.
  static double getDouble(SharedPreferences prefs, String key, [double defaultValue = 0.0]) {
    final value = prefs.get(key);
    if (value == null) return defaultValue;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.trim()) ?? defaultValue;
    }
    return defaultValue;
  }

  /// Safely gets a bool value. Parses String ("true", "1", "yes", "false", "0", "no"), num, int.
  static bool getBool(SharedPreferences prefs, String key, [bool defaultValue = false]) {
    final value = prefs.get(key);
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final lower = value.toLowerCase().trim();
      if (lower == 'true' || lower == '1' || lower == 'yes') return true;
      if (lower == 'false' || lower == '0' || lower == 'no') return false;
    }
    return defaultValue;
  }

  /// Safely gets a String value.
  static String getString(SharedPreferences prefs, String key, [String defaultValue = '']) {
    final value = prefs.get(key);
    if (value == null) return defaultValue;
    return value.toString();
  }

  /// Safely gets a String or null if not present or empty.
  static String? getStringOrNull(SharedPreferences prefs, String key) {
    final value = prefs.get(key);
    if (value == null) return null;
    final str = value.toString().trim();
    return str.isEmpty ? null : str;
  }

  /// Tries multiple keys in order and returns the first found integer value.
  static int getIntFromKeys(SharedPreferences prefs, List<String> keys, [int defaultValue = 0]) {
    for (final k in keys) {
      if (prefs.containsKey(k)) {
        final val = getIntOrNull(prefs, k);
        if (val != null) return val;
      }
    }
    return defaultValue;
  }

  /// Tries multiple keys in order and returns the first found boolean value.
  static bool getBoolFromKeys(SharedPreferences prefs, List<String> keys, [bool defaultValue = false]) {
    for (final k in keys) {
      if (prefs.containsKey(k)) {
        final val = prefs.get(k);
        if (val != null) {
          return getBool(prefs, k, defaultValue);
        }
      }
    }
    return defaultValue;
  }

  /// Tries multiple keys in order and returns the first found String value.
  static String getStringFromKeys(SharedPreferences prefs, List<String> keys, [String defaultValue = '']) {
    for (final k in keys) {
      if (prefs.containsKey(k)) {
        final str = getStringOrNull(prefs, k);
        if (str != null) return str;
      }
    }
    return defaultValue;
  }
}
