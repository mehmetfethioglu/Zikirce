import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_helper.dart';
import 'boycott_sync_service.dart';
import '../../profile/domain/user_profile_service.dart';

class EdgeWorkerSyncService {
  static const String _offWriteUrl = 'https://world.openfoodfacts.org/cgi/product_jqm2.pl';
  static const String _edgeWorkerUrl = 'https://organicscore.akarworks.workers.dev/api/crowdsource';

  static StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  static bool _isSyncing = false;

  /// Starts real-time connectivity listener that automatically flushes the local
  /// SQLite crowdsourced_queue and syncs live boycott lists whenever the phone reconnects to internet.
  static void initAutoSyncListener() {
    _connectivitySub?.cancel();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final bool hasConnection = !results.contains(ConnectivityResult.none);
      if (hasConnection) {
        syncPendingQueue();
        BoycottSyncService.syncBoycottList();
      }
    });

    // Immediate initial sync attempt if already online
    syncPendingQueue();
    BoycottSyncService.syncBoycottList();
  }

  /// Cancels subscription to prevent memory leaks
  static void dispose() {
    _connectivitySub?.cancel();
    _connectivitySub = null;
  }

  /// Uploads a single product contribution live to Cloudflare Edge Worker & Open Food Facts
  static Future<bool> submitProductToCloud({
    required String barcode,
    required String name,
    required String brand,
    required String ingredientsText,
    int? organicScore,
    int? novaGroup,
  }) async {
    if (barcode.trim().isEmpty) return false;

    bool offSuccess = false;
    bool workerSuccess = false;

    // 1. Submit to Open Food Facts
    try {
      final Map<String, String> offBody = {
        'code': barcode.trim(),
        'product_name': name.trim(),
        'product_name_tr': name.trim(),
        'brands': brand.trim(),
        'ingredients_text': ingredientsText.trim(),
        'ingredients_text_tr': ingredientsText.trim(),
        'countries_tags': 'en:turkey',
        'comment': 'OrganicScore Topluluk Katkısı ile eklendi',
        'user_id': 'OrganicScoreApp',
      };

      final response = await http.post(
        Uri.parse(_offWriteUrl),
        headers: {
          'User-Agent': 'OrganicScoreApp/1.0 (Mobile; TR)',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: offBody,
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200 || response.statusCode == 201) {
        offSuccess = true;
      }
    } catch (_) {}

    // 2. Submit to Cloudflare Worker & KV Cache
    try {
      final Map<String, dynamic> workerPayload = {
        'barcode': barcode.trim(),
        'product_name': name.trim(),
        'brand': brand.trim(),
        'ingredients_text': ingredientsText.trim(),
        'organic_score': organicScore ?? 50,
        'nova_group': novaGroup ?? 3,
        'verdict': 'Topluluk Doğrulamalı Ürün',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      final response = await http.post(
        Uri.parse(_edgeWorkerUrl),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'OrganicScoreApp/1.0',
        },
        body: jsonEncode(workerPayload),
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200 || response.statusCode == 201) {
        workerSuccess = true;
      }
    } catch (_) {}

    if (offSuccess || workerSuccess) {
      UserProfileService.instance.recordContribution();
    }

    return offSuccess || workerSuccess;
  }

  /// Iterates through local crowdsourced_queue SQLite table and syncs all PENDING submissions
  static Future<int> syncPendingQueue() async {
    if (_isSyncing) return 0;
    _isSyncing = true;
    int syncedCount = 0;

    try {
      final Database db = await DatabaseHelper().database;

      final List<Map<String, dynamic>> pendingRows = await db.query(
        'crowdsourced_queue',
        where: 'status = ?',
        whereArgs: ['PENDING'],
      );

      for (var row in pendingRows) {
        final int id = row['id'] as int;
        final String barcode = row['barcode'] as String? ?? '';
        final String payloadStr = row['payload_json'] as String? ?? '{}';

        try {
          final Map<String, dynamic> payload = jsonDecode(payloadStr);
          final String name = payload['product_name'] as String? ?? '';
          final String brand = payload['brand'] as String? ?? '';
          final String ingText = payload['ingredients_text'] as String? ?? '';
          final int? score = payload['organic_score'] as int?;
          final int? nova = payload['nova_group'] as int?;

          if (barcode.isNotEmpty) {
            final bool success = await submitProductToCloud(
              barcode: barcode,
              name: name.isNotEmpty ? name : 'Barkodlu Ürün',
              brand: brand.isNotEmpty ? brand : 'Yerli Üretici',
              ingredientsText: ingText,
              organicScore: score,
              novaGroup: nova,
            );

            if (success) {
              await db.update(
                'crowdsourced_queue',
                {'status': 'SYNCED'},
                where: 'id = ?',
                whereArgs: [id],
              );
              syncedCount++;
            }
          }
        } catch (e) {
          debugPrint('Sync row error: $e');
        }
      }
    } catch (e) {
      debugPrint('Sync pending queue error: $e');
    } finally {
      _isSyncing = false;
    }

    return syncedCount;
  }
}
