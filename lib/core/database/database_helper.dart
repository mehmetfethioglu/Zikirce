import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'organicscore.db');

    return await openDatabase(
      path,
      version: 10,
      onCreate: _onCreate,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          try {
            await db.execute('ALTER TABLE offline_ai_snapshots ADD COLUMN brand TEXT');
          } catch (_) {}
        }
        if (oldVersion < 3) {
          try {
            await db.rawDelete('DELETE FROM family_profiles WHERE id NOT IN (SELECT MIN(id) FROM family_profiles GROUP BY profile_name)');
          } catch (_) {}
        }
        if (oldVersion < 4) {
          try {
            await db.execute('DROP TABLE IF EXISTS crowdsourced_queue');
            await db.execute('''
              CREATE TABLE crowdsourced_queue (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                type TEXT NOT NULL,
                barcode TEXT NOT NULL,
                payload_json TEXT NOT NULL,
                status TEXT DEFAULT 'PENDING'
              )
            ''');
          } catch (_) {}
        }
        if (oldVersion < 5) {
          try {
            final String tagsisString = await rootBundle.loadString('assets/data/taklit_tagsis_list.json');
            final List<dynamic> tagsisJson = jsonDecode(tagsisString);
            await db.delete('taklit_tagsis');
            final int now = DateTime.now().millisecondsSinceEpoch;
            for (var item in tagsisJson) {
              await db.insert('taklit_tagsis', {
                'company_name': item['company_name'],
                'brand_name': item['brand_name'],
                'product_name': item['product_name'],
                'reason': item['reason'],
                'category': item['category'] ?? 'Gıda',
                'announced_at': item['announced_at'] ?? now,
              }, conflictAlgorithm: ConflictAlgorithm.replace);
            }
          } catch (_) {}
        }
        if (oldVersion < 6) {
          try {
            final String boycottString = await rootBundle.loadString('assets/data/boycott_list.json');
            final List<dynamic> boycottJson = jsonDecode(boycottString);
            await db.delete('boycott_brands');
            for (var item in boycottJson) {
              await db.insert('boycott_brands', {
                'brand_name': item['brand_name'],
                'parent_company': item['brand_name'],
                'status_flag': item['boycott_status'] ?? 'FLAGGED',
                'reason': item['reason'],
              }, conflictAlgorithm: ConflictAlgorithm.replace);
            }
          } catch (_) {}
        }
        if (oldVersion < 7) {
          try {
            await db.execute('ALTER TABLE boycott_brands ADD COLUMN evidence_url TEXT');
          } catch (_) {}
          try {
            await db.execute('ALTER TABLE boycott_brands ADD COLUMN category TEXT');
          } catch (_) {}
          try {
            final String boycottString = await rootBundle.loadString('assets/data/boycott_list.json');
            final List<dynamic> boycottJson = jsonDecode(boycottString);
            await db.delete('boycott_brands');
            for (var item in boycottJson) {
              await db.insert('boycott_brands', {
                'brand_name': item['brand_name'],
                'parent_company': item['parent_company'] ?? item['brand_name'],
                'status_flag': item['boycott_status'] ?? 'FLAGGED',
                'reason': item['reason'],
                'evidence_url': item['evidence_url'],
                'category': item['category'],
              }, conflictAlgorithm: ConflictAlgorithm.replace);
            }
          } catch (_) {}
        }
        if (oldVersion < 8) {
          try {
            await db.execute('ALTER TABLE family_profiles ADD COLUMN sensitivity_json TEXT');
          } catch (_) {}
        }
        if (oldVersion < 9) {
          try {
            final String tagsisString = await rootBundle.loadString('assets/data/taklit_tagsis_list.json');
            final List<dynamic> tagsisJson = jsonDecode(tagsisString);
            final int now = DateTime.now().millisecondsSinceEpoch;
            for (var item in tagsisJson) {
              await db.insert('taklit_tagsis', {
                'company_name': item['company_name'],
                'brand_name': item['brand_name'],
                'product_name': item['product_name'],
                'reason': item['reason'],
                'category': item['category'] ?? 'Gıda',
                'announced_at': item['announced_at'] ?? now,
              }, conflictAlgorithm: ConflictAlgorithm.ignore);
            }
          } catch (_) {}
        }
        if (oldVersion < 10) {
          try {
            final String snapshotsString = await rootBundle.loadString('assets/data/top_turkiye_ai_snapshots.json');
            final List<dynamic> snapshotsJson = jsonDecode(snapshotsString);
            final int now = DateTime.now().millisecondsSinceEpoch;
            final batch = db.batch();
            for (var item in snapshotsJson) {
              batch.insert('offline_ai_snapshots', {
                'barcode': item['barcode'],
                'product_name': item['product_name'],
                'brand': item['brand'] ?? '',
                'ai_summary_json': jsonEncode(item['ai_summary_json']),
                'synced_at': now,
              }, conflictAlgorithm: ConflictAlgorithm.replace);
            }
            await batch.commit(noResult: true);
          } catch (_) {}
        }
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE e_numbers (
        code TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        risk_level TEXT CHECK(risk_level IN ('LOW', 'MODERATE', 'HIGH', 'TOXIC')),
        health_hazards TEXT NOT NULL,
        category TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE boycott_brands (
        brand_name TEXT PRIMARY KEY,
        parent_company TEXT NOT NULL,
        status_flag TEXT CHECK(status_flag IN ('CLEAR', 'CAUTION', 'FLAGGED')),
        reason TEXT NOT NULL,
        evidence_url TEXT,
        category TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE family_profiles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        profile_name TEXT NOT NULL UNIQUE,
        is_active INTEGER DEFAULT 0,
        restrictions_json TEXT NOT NULL,
        sensitivity_json TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE offline_ai_snapshots (
        barcode TEXT PRIMARY KEY,
        product_name TEXT,
        brand TEXT,
        ai_summary_json TEXT NOT NULL,
        synced_at INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE product_history (
        barcode TEXT PRIMARY KEY,
        product_name TEXT,
        brand TEXT,
        organicscore INTEGER,
        nova_group INTEGER,
        raw_ingredients TEXT,
        scanned_at INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE crowdsourced_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        barcode TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        status TEXT DEFAULT 'PENDING'
      )
    ''');

    await db.execute('''
      CREATE TABLE taklit_tagsis (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_name TEXT NOT NULL,
        brand_name TEXT NOT NULL,
        product_name TEXT NOT NULL,
        reason TEXT NOT NULL,
        category TEXT,
        announced_at INTEGER
      )
    ''');

    await _seedInitialData(db);
  }

  Future<void> _seedInitialData(Database db) async {
    final int now = DateTime.now().millisecondsSinceEpoch;

    try {
      // 1. Seed E-Numbers
      final eNumbersString = await rootBundle.loadString('assets/data/e_numbers.json');
      final List<dynamic> eNumbersJson = jsonDecode(eNumbersString);
      for (var item in eNumbersJson) {
        await db.insert('e_numbers', {
          'code': item['code'],
          'name': item['name'],
          'risk_level': item['risk_level'],
          'health_hazards': item['health_hazards'],
          'category': item['category'],
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      // 2. Seed Boycott Brands
      try {
        final boycottString = await rootBundle.loadString('assets/data/boycott_list.json');
        final List<dynamic> boycottJson = jsonDecode(boycottString);
        for (var item in boycottJson) {
          await db.insert('boycott_brands', {
            'brand_name': item['brand_name'],
            'parent_company': item['parent_company'] ?? item['brand_name'],
            'status_flag': item['boycott_status'] ?? 'FLAGGED',
            'reason': item['reason'],
            'evidence_url': item['evidence_url'],
            'category': item['category'],
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      } catch (_) {}

      // 3. Seed Default Family Profiles
      await db.insert('family_profiles', {
        'profile_name': 'Çocuk Profili (Katkı Maddesiz & Şekersiz)',
        'is_active': 1,
        'restrictions_json': jsonEncode([
          'SYNTHETIC_COLORS',
          'HIGH_SUGAR',
          'PALM_OIL'
        ]),
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      await db.insert('family_profiles', {
        'profile_name': 'Kendi Profilim (Glutensiz & Helal)',
        'is_active': 0,
        'restrictions_json': jsonEncode([
          'GLUTEN',
          'HALAL'
        ]),
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      // 4. Seed Offline AI Snapshots
      try {
        final snapshotsString = await rootBundle.loadString('assets/data/top_turkiye_ai_snapshots.json');
        final List<dynamic> snapshotsJson = jsonDecode(snapshotsString);
        final batch = db.batch();
        for (var item in snapshotsJson) {
          batch.insert('offline_ai_snapshots', {
            'barcode': item['barcode'],
            'product_name': item['product_name'],
            'brand': item['brand'] ?? '',
            'ai_summary_json': jsonEncode(item['ai_summary_json']),
            'synced_at': now,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        await batch.commit(noResult: true);
      } catch (_) {}

      // 5. Seed Ministry Taklit & Tağşiş List
      try {
        final tagsisString = await rootBundle.loadString('assets/data/taklit_tagsis_list.json');
        final List<dynamic> tagsisJson = jsonDecode(tagsisString);
        for (var item in tagsisJson) {
          await db.insert('taklit_tagsis', {
            'company_name': item['company_name'],
            'brand_name': item['brand_name'],
            'product_name': item['product_name'],
            'reason': item['reason'],
            'category': item['category'] ?? 'Gıda',
            'announced_at': item['announced_at'] ?? now,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      } catch (_) {}
    } catch (e) {
      // Seed fallback in non-asset environment
    }
  }

  /// Inserts or updates an individual verified product snapshot in local SQLite.
  Future<void> saveSnapshot({
    required String barcode,
    required String productName,
    required String brand,
    required Map<String, dynamic> aiSummaryJson,
  }) async {
    final db = await database;
    await db.insert('offline_ai_snapshots', {
      'barcode': barcode,
      'product_name': productName,
      'brand': brand,
      'ai_summary_json': jsonEncode(aiSummaryJson),
      'synced_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Returns total count of verified offline product snapshots.
  Future<int> getVerifiedProductsCount() async {
    final db = await database;
    final res = await db.rawQuery('SELECT COUNT(*) as count FROM offline_ai_snapshots');
    return Sqflite.firstIntValue(res) ?? 0;
  }

  /// Forces a re-sync of offline snapshots from the bundled asset.
  Future<int> syncSnapshotsFromAsset() async {
    final db = await database;
    try {
      final snapshotsString = await rootBundle.loadString('assets/data/top_turkiye_ai_snapshots.json');
      final List<dynamic> snapshotsJson = jsonDecode(snapshotsString);
      final int now = DateTime.now().millisecondsSinceEpoch;
      final batch = db.batch();
      for (var item in snapshotsJson) {
        batch.insert('offline_ai_snapshots', {
          'barcode': item['barcode'],
          'product_name': item['product_name'],
          'brand': item['brand'] ?? '',
          'ai_summary_json': jsonEncode(item['ai_summary_json']),
          'synced_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
      return snapshotsJson.length;
    } catch (_) {
      return 0;
    }
  }
}
