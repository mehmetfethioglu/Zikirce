import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../../features/kiler/domain/kiler_service.dart';
import '../../features/profile/domain/user_profile_service.dart';

/// Full-state backup & restore service (v2.0) covering user profile, pantry,
/// shopping list, family profiles, meal plans, favorites, custom recipes, and check-ins.
/// Backward compatible with v1.0 profile-only backups.
class KilerceBackupService {
  static const String currentSchemaVersion = '2.0.0';

  static const List<String> _backupTables = [
    'pantry_items',
    'shopping_list',
    'family_profiles',
    'meal_plan_entries',
    'recipe_favorites',
    'custom_recipes',
    'meal_slot_checkins',
  ];

  /// Pure payload encoder for unit testing and full export.
  static String encodeBackupPayload({
    required Map<String, dynamic> profileJson,
    required Map<String, List<Map<String, dynamic>>> tables,
    int? createdAtMs,
  }) {
    final int now = createdAtMs ?? DateTime.now().millisecondsSinceEpoch;
    return jsonEncode({
      'app': 'Kilerce',
      'version': currentSchemaVersion,
      'created_at': now,
      'profile': profileJson,
      'tables': tables,
    });
  }

  /// Pure payload parser supporting both v1.0 and v2.0 JSON backups.
  static Map<String, dynamic>? decodeBackupPayload(String jsonString) {
    try {
      final dynamic decoded = jsonDecode(jsonString);
      if (decoded is! Map) return null;
      return Map<String, dynamic>.from(decoded);
    } catch (e) {
      debugPrint('KilerceBackupService.decodeBackupPayload error: $e');
      return null;
    }
  }

  /// Exports profile + all local SQLite user tables into a single JSON backup string.
  static Future<String> exportFullBackupJson() async {
    final int now = DateTime.now().millisecondsSinceEpoch;
    await UserProfileService.instance.updateLastBackupTimestamp(now);

    final Map<String, List<Map<String, dynamic>>> tables = {};
    try {
      final Database db = await DatabaseHelper().database;
      for (final table in _backupTables) {
        final rows = await db.query(table);
        tables[table] = rows.map((r) => Map<String, dynamic>.from(r)).toList();
      }
    } catch (e) {
      debugPrint('KilerceBackupService.exportFullBackupJson DB read note: $e');
    }

    return encodeBackupPayload(
      profileJson: UserProfileService.instance.profile.toJson(),
      tables: tables,
      createdAtMs: now,
    );
  }

  /// Restores profile (v1.0 & v2.0) and SQLite user tables (v2.0) atomically.
  static Future<bool> importFullBackupJson(String jsonString) async {
    final Map<String, dynamic>? payload = decodeBackupPayload(jsonString);
    if (payload == null) return false;

    final bool profileOk = await UserProfileService.instance.importBackupJson(jsonString);
    if (!profileOk) return false;

    final dynamic rawTables = payload['tables'];
    if (rawTables is Map) {
      try {
        final Database db = await DatabaseHelper().database;
        await db.transaction((txn) async {
          for (final table in _backupTables) {
            final dynamic tableRows = rawTables[table];
            if (tableRows is! List) continue;
            await txn.delete(table);
            final batch = txn.batch();
            for (final rawRow in tableRows) {
              if (rawRow is! Map) continue;
              batch.insert(
                table,
                Map<String, Object?>.from(rawRow),
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            }
            await batch.commit(noResult: true);
          }
        });
        await KilerService.instance.loadAll();
      } catch (e) {
        debugPrint('KilerceBackupService.importFullBackupJson DB restore error: $e');
        return false;
      }
    }

    return true;
  }
}
