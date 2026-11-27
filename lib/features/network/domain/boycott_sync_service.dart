import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_helper.dart';
import '../../profile/domain/user_profile_service.dart';

class BoycottSyncService {
  static const String _boycottApiUrl = 'https://organicscore.akarworks.workers.dev/api/boycott';
  static const String _boycottReportUrl = 'https://organicscore.akarworks.workers.dev/api/boycott/report';
  static const String _etagPrefKey = 'organicscore_boycott_etag';

  static bool _isSyncing = false;

  /// Fetches incremental boycott updates from Cloudflare Edge Worker.
  /// Uses ETag / 304 Not Modified to eliminate bandwidth and compute Muda.
  static Future<bool> syncBoycottList() async {
    if (_isSyncing) return false;
    _isSyncing = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final lastEtag = prefs.getString(_etagPrefKey);

      final headers = <String, String>{
        'User-Agent': 'OrganicScoreApp/1.0',
        'Accept': 'application/json',
      };
      if (lastEtag != null && lastEtag.isNotEmpty) {
        headers['If-None-Match'] = lastEtag;
      }

      final response = await http
          .get(Uri.parse(_boycottApiUrl), headers: headers)
          .timeout(const Duration(seconds: 8));

      // 304 Not Modified -> Local SQLite list is already up to date!
      if (response.statusCode == 304) {
        if (kDebugMode) {
          debugPrint('BoycottSyncService: Boykot listesi güncel (304 Not Modified).');
        }
        return true;
      }

      if (response.statusCode == 200) {
        final List<dynamic> items = jsonDecode(response.body);
        final Database db = await DatabaseHelper().database;

        await db.transaction((txn) async {
          final batch = txn.batch();
          for (final item in items) {
            final brandName = item['brand_name'] as String?;
            if (brandName == null || brandName.trim().isEmpty) continue;

            batch.insert(
              'boycott_brands',
              {
                'brand_name': brandName.trim(),
                'parent_company': (item['parent_company'] as String?)?.trim() ?? brandName.trim(),
                'status_flag': (item['boycott_status'] as String?) ?? 'FLAGGED',
                'reason': (item['reason'] as String?) ?? 'Gazze işgali ve İsrail bağlantısı nedeniyle boykot listesinde.',
                'evidence_url': (item['evidence_url'] as String?) ?? '',
                'category': (item['category'] as String?) ?? 'Genel',
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
          await batch.commit(noResult: true);
        });

        final newEtag = response.headers['etag'];
        if (newEtag != null && newEtag.isNotEmpty) {
          await prefs.setString(_etagPrefKey, newEtag);
        }

        if (kDebugMode) {
          debugPrint('BoycottSyncService: ${items.length} boykot kaydı başarıyla senkronize edildi.');
        }
        return true;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('BoycottSyncService Sync Error: $e');
      }
    } finally {
      _isSyncing = false;
    }

    return false;
  }

  /// Replays a queued boycott dispute payload to the Cloudflare Edge Worker.
  static Future<bool> replayQueuedBoycottReport(Map<String, dynamic> payload) async {
    try {
      final response = await http
          .post(
            Uri.parse(_boycottReportUrl),
            headers: {
              'Content-Type': 'application/json',
              'User-Agent': 'KilerceApp/3.2',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 6));
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('BoycottSyncService.replayQueuedBoycottReport error: $e');
      return false;
    }
  }

  /// Submits a user report / dispute (e.g. false positive like Eti Lifalif, or missing boycotted brand)
  /// Directly to Cloudflare Edge Worker KV and queues into local SQLite crowdsourced_queue.
  static Future<bool> reportBoycottDispute({
    required String barcode,
    required String productName,
    required String brandName,
    required String reportType, // 'FALSE_POSITIVE' or 'NEW_BOYCOTT'
    required String reason,
  }) async {
    final Map<String, dynamic> payload = {
      'barcode': barcode,
      'product_name': productName,
      'brand_name': brandName,
      'report_type': reportType,
      'user_reason': reason,
      'reported_at': DateTime.now().millisecondsSinceEpoch,
    };

    int? queuedRowId;
    Database? db;

    // 1. Record locally in crowdsourced_queue for offline durability
    try {
      db = await DatabaseHelper().database;
      queuedRowId = await db.insert('crowdsourced_queue', {
        'type': 'BOYCOTT_REPORT',
        'barcode': barcode.isNotEmpty ? barcode : 'UNKNOWN',
        'payload_json': jsonEncode(payload),
        'status': 'PENDING',
      });
    } catch (e) {
      debugPrint('BoycottSyncService.reportBoycottDispute queue insert error: $e');
    }

    // 2. Transmit to Cloudflare Edge Worker
    try {
      final response = await http
          .post(
            Uri.parse(_boycottReportUrl),
            headers: {
              'Content-Type': 'application/json',
              'User-Agent': 'KilerceApp/3.2',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 6));

      UserProfileService.instance.recordBoycottReport();

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (db != null && queuedRowId != null) {
          await db.update(
            'crowdsourced_queue',
            {'status': 'SYNCED'},
            where: 'id = ?',
            whereArgs: [queuedRowId],
          );
        }
        return true;
      }
    } catch (e) {
      debugPrint('BoycottSyncService.reportBoycottDispute post error: $e');
      UserProfileService.instance.recordBoycottReport();
    }

    return false;
  }
}
