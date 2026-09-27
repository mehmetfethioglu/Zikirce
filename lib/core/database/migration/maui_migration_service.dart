import 'dart:io';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart' as sql;
import '../app_database.dart';
import '../../services/google_drive_backup_service.dart';

class MauiMigrationService {
  static const String _migrationKey = 'maui_migration_v4_completed';

  /// Scans for legacy .NET MAUI SQLite database (`zikir.db`) and migrates all user records into Drift.
  static Future<bool> checkAndMigrate(AppDatabase db) async {
    final prefs = await SharedPreferences.getInstance();

    // Priority 1: Check for converted full MAUI backup in Downloads
    final tamDone = prefs.getBool('maui_tam_migration_v2_done') ?? false;
    if (!tamDone) {
      final tamBackupPaths = [
        '/sdcard/Android/data/com.akarworks.zikirce/files/Zikirce_Yedek_2026-09-03_TAM.json',
        '/storage/emulated/0/Android/data/com.akarworks.zikirce/files/Zikirce_Yedek_2026-09-03_TAM.json',
        '/sdcard/Download/Zikirce_Yedek_2026-09-03_TAM.json',
        '/storage/emulated/0/Download/Zikirce_Yedek_2026-09-03_TAM.json',
      ];
      for (final p in tamBackupPaths) {
        final f = File(p);
        if (f.existsSync()) {
          try {
            final content = await f.readAsString();
            final backupService = GoogleDriveBackupService(db: db);
            final count = await backupService.restoreFromJson(content);
            debugPrint('[MauiMigration] Successfully auto-migrated $count zikirs and all data from $p!');
            await prefs.setBool('maui_tam_migration_v2_done', true);
            await prefs.setBool(_migrationKey, true);
            await _reconcileZikirTotals(db, prefs);
            return true;
          } catch (e) {
            debugPrint('[MauiMigration] Error restoring from $p: $e');
          }
        }
      }
    }

    final isMigrated = prefs.getBool(_migrationKey) ?? false;
    if (isMigrated) {
      // Reconcile zikir total counts with logs if needed
      await _reconcileZikirTotals(db, prefs);
      debugPrint('[MauiMigration] Already completed prior migration.');
      return false;
    }

    // Possible MAUI database file locations on Android
    final possiblePaths = [
      '/data/user/0/com.akarworks.zikirce/files/zikir.db',
      '/data/data/com.akarworks.zikirce/files/zikir.db',
    ];

    File? legacyDbFile;
    for (final p in possiblePaths) {
      final f = File(p);
      if (f.existsSync()) {
        legacyDbFile = f;
        break;
      }
    }

    if (legacyDbFile == null) {
      debugPrint('[MauiMigration] No legacy MAUI database detected. Fresh installation.');
      await _reconcileZikirTotals(db, prefs);
      await prefs.setBool(_migrationKey, true);
      return false;
    }

    debugPrint('[MauiMigration] Legacy MAUI database found at: ${legacyDbFile.path}. Starting data migration...');

    try {
      final legacyDb = sql.sqlite3.open(legacyDbFile.path);

      // 1. Migrate Zikir Table
      int totalZikirsCount = 0;
      try {
        final zikirRows = legacyDb.select('SELECT * FROM Zikir;');
        for (final row in zikirRows) {
          final id = (row['ZikirId'] ?? row['Id']) as int?;
          final name = row['ZikirAdi']?.toString() ?? row['Name']?.toString() ?? 'Zikir';
          final arabic = row['ArapceMetin']?.toString() ?? row['ArabicName']?.toString();
          final target = (row['ZikirMiktar'] ?? row['Target']) as int? ?? 33;
          final current = (row['Sayac'] ?? row['CurrentCount']) as int? ?? 0;
          final total = (row['ZikirToplam'] ?? row['TotalCount']) as int? ?? 0;
          final lap = (row['Lap'] ?? (target > 0 ? (total ~/ target) : 0)) as int? ?? 0;
          final isFav = ((row['IsFavorite'] as int? ?? (row['IsFavorite'] == true ? 1 : 0)) == 1);
          final category = row['Kategori']?.toString() ?? row['Category']?.toString() ?? 'Genel';

          totalZikirsCount += total;

          await db.into(db.zikirs).insertOnConflictUpdate(
            ZikirsCompanion(
              id: id != null ? Value(id) : const Value.absent(),
              name: Value(name),
              arabic: Value(arabic),
              target: Value(target),
              currentCount: Value(current),
              totalCount: Value(total),
              lap: Value(lap),
              isFavorite: Value(isFav),
              category: Value(category),
            ),
          );
        }
        debugPrint('[MauiMigration] Migrated ${zikirRows.length} Zikir records (total count: $totalZikirsCount).');
      } catch (e) {
        debugPrint('[MauiMigration] Zikir migration warning: $e');
      }

      // 1.1 Migrate ZikirLog Table
      int totalLogsCount = 0;
      try {
        final logRows = legacyDb.select('SELECT * FROM ZikirLog;');
        for (final lRow in logRows) {
          final zId = (lRow['ZikirId'] ?? lRow['Id']) as int? ?? 1;
          final count = (lRow['CekilenMiktar'] ?? lRow['Count']) as int? ?? 1;
          final unix = lRow['Tarih'] as int? ?? lRow['TarihUnix'] as int? ?? lRow['Timestamp'] as int?;
          final dt = unix != null
              ? DateTime.fromMillisecondsSinceEpoch(unix > 100000000000 ? unix : unix * 1000)
              : DateTime.now();
          final dateStr = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

          totalLogsCount += count;

          await db.into(db.zikirLogs).insert(
            ZikirLogsCompanion.insert(
              zikirId: zId,
              count: count,
              dateStr: dateStr,
              timestamp: Value(dt),
            ),
          );
        }
        debugPrint('[MauiMigration] Migrated ${logRows.length} ZikirLog records (total logs: $totalLogsCount).');
      } catch (e) {
        debugPrint('[MauiMigration] ZikirLog migration warning / not present: $e');
      }

      // Reconcile and sync overall total zikir to preferences
      await _reconcileZikirTotals(db, prefs);

      // 2. Migrate UserStreak Table
      try {
        final streakRows = legacyDb.select('SELECT * FROM UserStreak LIMIT 1;');
        if (streakRows.isNotEmpty) {
          final sRow = streakRows.first;
          final lastDateVal = sRow['LastDate']?.toString() ??
              sRow['LastActiveDate']?.toString() ??
              sRow['LastStreakDate']?.toString();
          await (db.update(db.userStreaks)..where((t) => t.id.equals(1))).write(
            UserStreaksCompanion(
              currentStreak: Value(sRow['CurrentStreak'] as int? ?? 0),
              bestStreak: Value(sRow['BestStreak'] as int? ?? 0),
              totalDays: Value(sRow['TotalDays'] as int? ?? 0),
              lastDate: lastDateVal != null ? Value(lastDateVal) : const Value.absent(),
              freezeCount: Value(sRow['StreakShields'] as int? ?? 2),
              xp: Value(sRow['TotalXP'] as int? ?? 0),
              rank: Value(sRow['RankTitle']?.toString() ?? 'Mübtedi'),
            ),
          );
          debugPrint('[MauiMigration] Migrated UserStreak successfully.');
        }
      } catch (e) {
        debugPrint('[MauiMigration] UserStreak migration warning: $e');
      }

      // 3. Migrate KazaPrayers Table
      try {
        final kazaRows = legacyDb.select('SELECT * FROM KazaPrayer;');
        for (final kRow in kazaRows) {
          final pType = kRow['PrayerType']?.toString() ?? '';
          final total = kRow['TotalCount'] as int? ?? 0;
          final completed = kRow['CompletedCount'] as int? ?? 0;

          if (pType.isNotEmpty) {
            await (db.update(db.kazaPrayers)..where((t) => t.prayerType.equals(pType))).write(
              KazaPrayersCompanion(
                totalCount: Value(total),
                completedCount: Value(completed),
              ),
            );
          }
        }
        debugPrint('[MauiMigration] Migrated ${kazaRows.length} Kaza records.');
      } catch (e) {
        debugPrint('[MauiMigration] Kaza migration warning: $e');
      }

      // 4. Migrate Hatims
      try {
        final hatimRows = legacyDb.select('SELECT * FROM Hatim;');
        for (final hRow in hatimRows) {
          final hId = hRow['Id']?.toString() ?? '';
          final title = hRow['Title']?.toString() ?? 'Hatim';
          final compPages = hRow['CompletedPages'] as int? ?? 0;
          final isComp = (hRow['IsCompleted'] as int? ?? 0) == 1;

          if (hId.isNotEmpty) {
            await db.into(db.hatims).insertOnConflictUpdate(
              HatimsCompanion(
                id: Value(hId),
                title: Value(title),
                completedPages: Value(compPages),
                isCompleted: Value(isComp),
              ),
            );
          }
        }
        debugPrint('[MauiMigration] Migrated ${hatimRows.length} Hatim records.');
      } catch (e) {
        debugPrint('[MauiMigration] Hatim migration warning: $e');
      }

      legacyDb.dispose();
      await prefs.setBool(_migrationKey, true);
      debugPrint('[MauiMigration] Seamless migration completed successfully!');
      return true;
    } catch (e) {
      debugPrint('[MauiMigration] Error during MAUI data migration: $e');
      return false;
    }
  }

  /// Reconciles each zikir's totalCount with the sum of ZikirLogs
  static Future<void> _reconcileZikirTotals(AppDatabase db, SharedPreferences prefs) async {
    try {
      final allZikirs = await db.select(db.zikirs).get();
      final allLogs = await db.select(db.zikirLogs).get();
      int grandTotal = 0;

      for (final z in allZikirs) {
        final logsForZikir = allLogs.where((l) => l.zikirId == z.id);
        final sumLogs = logsForZikir.fold<int>(0, (sum, l) => sum + l.count);
        final effectiveTotal = sumLogs > z.totalCount ? sumLogs : z.totalCount;

        grandTotal += effectiveTotal;

        if (effectiveTotal != z.totalCount) {
          await (db.update(db.zikirs)..where((t) => t.id.equals(z.id))).write(
            ZikirsCompanion(
              totalCount: Value(effectiveTotal),
            ),
          );
        }
      }

      final curPrefsTotal = prefs.getInt('TotalZikir') ?? 0;
      if (grandTotal > curPrefsTotal) {
        await prefs.setInt('TotalZikir', grandTotal);
      }
    } catch (e) {
      debugPrint('[MauiMigration] Error in _reconcileZikirTotals: $e');
    }
  }
}
