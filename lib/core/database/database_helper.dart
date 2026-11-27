import 'dart:convert';
import 'package:flutter/foundation.dart';
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
      version: 16,
      onCreate: _onCreate,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          try {
            await db.execute('ALTER TABLE offline_ai_snapshots ADD COLUMN brand TEXT');
          } catch (e) {
            debugPrint('DB v2 upgrade note: $e');
          }
        }
        if (oldVersion < 3) {
          try {
            await db.rawDelete(
              'DELETE FROM family_profiles WHERE id NOT IN (SELECT MIN(id) FROM family_profiles GROUP BY profile_name)',
            );
          } catch (e) {
            debugPrint('DB v3 upgrade note: $e');
          }
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
          } catch (e) {
            debugPrint('DB v4 upgrade note: $e');
          }
        }
        if (oldVersion < 5) {
          try {
            final String tagsisString = await rootBundle.loadString('assets/data/taklit_tagsis_list.json');
            final List<dynamic> tagsisJson = jsonDecode(tagsisString);
            await db.delete('taklit_tagsis');
            final int now = DateTime.now().millisecondsSinceEpoch;
            for (final item in tagsisJson) {
              await db.insert('taklit_tagsis', {
                'company_name': item['company_name'],
                'brand_name': item['brand_name'],
                'product_name': item['product_name'],
                'reason': item['reason'],
                'category': item['category'] ?? 'Gıda',
                'announced_at': item['announced_at'] ?? now,
              }, conflictAlgorithm: ConflictAlgorithm.replace);
            }
          } catch (e) {
            debugPrint('DB v5 upgrade note: $e');
          }
        }
        if (oldVersion < 6) {
          try {
            final String boycottString = await rootBundle.loadString('assets/data/boycott_list.json');
            final List<dynamic> boycottJson = jsonDecode(boycottString);
            await db.delete('boycott_brands');
            for (final item in boycottJson) {
              await db.insert('boycott_brands', {
                'brand_name': item['brand_name'],
                'parent_company': item['brand_name'],
                'status_flag': item['boycott_status'] ?? 'FLAGGED',
                'reason': item['reason'],
              }, conflictAlgorithm: ConflictAlgorithm.replace);
            }
          } catch (e) {
            debugPrint('DB v6 upgrade note: $e');
          }
        }
        if (oldVersion < 7) {
          try {
            await db.execute('ALTER TABLE boycott_brands ADD COLUMN evidence_url TEXT');
          } catch (e) {
            debugPrint('DB v7 col1 note: $e');
          }
          try {
            await db.execute('ALTER TABLE boycott_brands ADD COLUMN category TEXT');
          } catch (e) {
            debugPrint('DB v7 col2 note: $e');
          }
          try {
            final String boycottString = await rootBundle.loadString('assets/data/boycott_list.json');
            final List<dynamic> boycottJson = jsonDecode(boycottString);
            await db.delete('boycott_brands');
            for (final item in boycottJson) {
              await db.insert('boycott_brands', {
                'brand_name': item['brand_name'],
                'parent_company': item['parent_company'] ?? item['brand_name'],
                'status_flag': item['boycott_status'] ?? 'FLAGGED',
                'reason': item['reason'],
                'evidence_url': item['evidence_url'],
                'category': item['category'],
              }, conflictAlgorithm: ConflictAlgorithm.replace);
            }
          } catch (e) {
            debugPrint('DB v7 seed note: $e');
          }
        }
        if (oldVersion < 8) {
          try {
            await db.execute('ALTER TABLE family_profiles ADD COLUMN sensitivity_json TEXT');
          } catch (e) {
            debugPrint('DB v8 upgrade note: $e');
          }
        }
        if (oldVersion < 9) {
          try {
            final String tagsisString = await rootBundle.loadString('assets/data/taklit_tagsis_list.json');
            final List<dynamic> tagsisJson = jsonDecode(tagsisString);
            final int now = DateTime.now().millisecondsSinceEpoch;
            for (final item in tagsisJson) {
              await db.insert('taklit_tagsis', {
                'company_name': item['company_name'],
                'brand_name': item['brand_name'],
                'product_name': item['product_name'],
                'reason': item['reason'],
                'category': item['category'] ?? 'Gıda',
                'announced_at': item['announced_at'] ?? now,
              }, conflictAlgorithm: ConflictAlgorithm.ignore);
            }
          } catch (e) {
            debugPrint('DB v9 upgrade note: $e');
          }
        }
        if (oldVersion < 10) {
          try {
            final String snapshotsString = await rootBundle.loadString('assets/data/top_turkiye_ai_snapshots.json');
            final List<dynamic> snapshotsJson = jsonDecode(snapshotsString);
            final int now = DateTime.now().millisecondsSinceEpoch;
            final batch = db.batch();
            for (final item in snapshotsJson) {
              batch.insert('offline_ai_snapshots', {
                'barcode': item['barcode'],
                'product_name': item['product_name'],
                'brand': item['brand'] ?? '',
                'ai_summary_json': jsonEncode(item['ai_summary_json']),
                'synced_at': now,
              }, conflictAlgorithm: ConflictAlgorithm.replace);
            }
            await batch.commit(noResult: true);
          } catch (e) {
            debugPrint('DB v10 upgrade note: $e');
          }
        }
        if (oldVersion < 11) {
          try {
            final String eNumbersString = await rootBundle.loadString('assets/data/e_numbers.json');
            final List<dynamic> eNumbersJson = jsonDecode(eNumbersString);
            final batch = db.batch();
            for (final item in eNumbersJson) {
              batch.insert('e_numbers', {
                'code': item['code'],
                'name': item['name'],
                'risk_level': item['risk_level'],
                'health_hazards': item['health_impact'],
                'category': item['description'] ?? 'Gıda Katkısı',
              }, conflictAlgorithm: ConflictAlgorithm.replace);
            }
            await batch.commit(noResult: true);
          } catch (e) {
            debugPrint('DB v11 upgrade note: $e');
          }
        }
        if (oldVersion < 12) {
          try {
            await _createKilerceTables(db);
            await _seedStarterPantryItems(db);
          } catch (e) {
            debugPrint('DB v12 Kilerce upgrade note: $e');
          }
        }
        if (oldVersion < 13) {
          try {
            await _purgeInvalidSnapshots(db);
            await _syncSnapshotsWithDb(db);
          } catch (e) {
            debugPrint('DB v13 verified snapshots upgrade note: $e');
          }
        }
        if (oldVersion < 14) {
          try {
            await _createMealModuleTables(db);
          } catch (e) {
            debugPrint('DB v14 meal module upgrade note: $e');
          }
        }
        if (oldVersion < 15) {
          try {
            await _createMealLifecycleTables(db);
          } catch (e) {
            debugPrint('DB v15 meal lifecycle upgrade note: $e');
          }
        }
        if (oldVersion < 16) {
          try {
            await _createIndexes(db);
          } catch (e) {
            debugPrint('DB v16 index upgrade note: $e');
          }
          await _repairEmptySeedTables(db);
        }
      },
    );
  }

  /// Normalizes an E-number asset/JSON entry into the SQLite `e_numbers` schema.
  static Map<String, Object?> mapENumberRow(Map<String, dynamic> item) {
    final String rawHazards = (item['health_hazards'] ?? item['health_impact'] ?? 'Bilgi yok').toString().trim();
    final String rawCategory = (item['category'] ?? item['description'] ?? 'Gıda Katkısı').toString().trim();
    return {
      'code': (item['code'] ?? '').toString().trim(),
      'name': (item['name'] ?? '').toString().trim(),
      'risk_level': (item['risk_level'] ?? 'LOW').toString().trim(),
      'health_hazards': rawHazards.isEmpty ? 'Bilgi yok' : rawHazards,
      'category': rawCategory.isEmpty ? 'Gıda Katkısı' : rawCategory,
    };
  }

  Future<void> _createIndexes(Database db) async {
    const statements = [
      'CREATE INDEX IF NOT EXISTS idx_pantry_tag_zone ON pantry_items(normalized_tag, storage_zone)',
      'CREATE INDEX IF NOT EXISTS idx_pantry_expires ON pantry_items(expires_at)',
      'CREATE INDEX IF NOT EXISTS idx_shopping_checked ON shopping_list(is_checked, added_at)',
      'CREATE INDEX IF NOT EXISTS idx_snapshots_name ON offline_ai_snapshots(product_name)',
      'CREATE INDEX IF NOT EXISTS idx_snapshots_brand ON offline_ai_snapshots(brand)',
      'CREATE INDEX IF NOT EXISTS idx_tagsis_brand ON taklit_tagsis(brand_name)',
      'CREATE INDEX IF NOT EXISTS idx_tagsis_announced ON taklit_tagsis(announced_at)',
      'CREATE INDEX IF NOT EXISTS idx_history_scanned ON product_history(scanned_at)',
      'CREATE INDEX IF NOT EXISTS idx_crowd_status_type ON crowdsourced_queue(status, type)',
      'CREATE INDEX IF NOT EXISTS idx_meal_plan_date_slot ON meal_plan_entries(plan_date, meal_slot)',
    ];
    for (final sql in statements) {
      await db.execute(sql);
    }
  }

  Future<int> _tableCount(Database db, String table) async {
    return Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM $table')) ?? 0;
  }

  Future<void> _repairEmptySeedTables(Database db) async {
    if (await _tableCount(db, 'e_numbers') == 0) {
      await _seedENumbers(db);
    }
    if (await _tableCount(db, 'boycott_brands') == 0) {
      await _seedBoycottBrands(db);
    }
    if (await _tableCount(db, 'family_profiles') == 0) {
      await _seedDefaultFamilyProfiles(db);
    }
    if (await _tableCount(db, 'offline_ai_snapshots') == 0) {
      try {
        await _syncSnapshotsWithDb(db);
      } catch (e) {
        debugPrint('DB v16 snapshots repair note: $e');
      }
    }
    if (await _tableCount(db, 'taklit_tagsis') == 0) {
      await _seedTaklitTagsis(db);
    }
  }

  Future<void> _createMealLifecycleTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS meal_slot_checkins (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        plan_date TEXT NOT NULL,
        meal_slot TEXT NOT NULL,
        resolution_type TEXT NOT NULL,
        note TEXT,
        resolved_at INTEGER NOT NULL,
        UNIQUE(plan_date, meal_slot)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS recipe_photo_overrides (
        recipe_id TEXT PRIMARY KEY,
        local_path TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _createMealModuleTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS meal_plan_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        plan_date TEXT NOT NULL,
        meal_slot TEXT NOT NULL,
        recipe_id TEXT NOT NULL,
        servings INTEGER NOT NULL DEFAULT 2,
        is_cooked INTEGER NOT NULL DEFAULT 0,
        added_at INTEGER NOT NULL,
        UNIQUE(plan_date, meal_slot, recipe_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS recipe_favorites (
        recipe_id TEXT PRIMARY KEY,
        saved_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS recipe_cook_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        recipe_id TEXT NOT NULL,
        recipe_title TEXT NOT NULL,
        servings INTEGER NOT NULL DEFAULT 2,
        cooked_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS custom_recipes (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        subtitle TEXT NOT NULL,
        emoji TEXT NOT NULL,
        category TEXT NOT NULL,
        prep_minutes INTEGER NOT NULL,
        cook_minutes INTEGER NOT NULL DEFAULT 0,
        servings INTEGER NOT NULL DEFAULT 2,
        calories INTEGER NOT NULL DEFAULT 280,
        protein_grams INTEGER NOT NULL DEFAULT 12,
        payload_json TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _createKilerceTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pantry_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        barcode TEXT,
        name TEXT NOT NULL,
        normalized_tag TEXT NOT NULL,
        brand TEXT,
        category TEXT NOT NULL,
        storage_zone TEXT NOT NULL,
        quantity_level TEXT NOT NULL,
        unit_label TEXT,
        health_score INTEGER DEFAULT 88,
        added_at INTEGER NOT NULL,
        expires_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS shopping_list (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        normalized_tag TEXT NOT NULL,
        category TEXT NOT NULL,
        is_checked INTEGER DEFAULT 0,
        source_note TEXT,
        added_at INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _seedStarterPantryItems(Database db) async {
    final existingCount = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM pantry_items'),
        ) ??
        0;
    if (existingCount > 0) return;

    final int now = DateTime.now().millisecondsSinceEpoch;
    const int dayMs = 86400000;

    final List<Map<String, dynamic>> starterItems = [
      {
        'barcode': null,
        'name': 'Yumurta (Organik Köy)',
        'normalized_tag': 'yumurta',
        'brand': 'Doğal Çiftlik',
        'category': 'Et, Tavuk & Yumurta',
        'storage_zone': 'FRIDGE',
        'quantity_level': 'FULL',
        'unit_label': '10 Adet',
        'health_score': 96,
        'added_at': now,
        'expires_at': now + (14 * dayMs),
      },
      {
        'barcode': null,
        'name': 'Domates',
        'normalized_tag': 'domates',
        'brand': 'Taze Manav',
        'category': 'Sebze & Meyve',
        'storage_zone': 'FRIDGE',
        'quantity_level': 'FULL',
        'unit_label': '1 Kg',
        'health_score': 98,
        'added_at': now,
        'expires_at': now + (2 * dayMs),
      },
      {
        'barcode': null,
        'name': 'Sivri Biber',
        'normalized_tag': 'biber',
        'brand': 'Taze Manav',
        'category': 'Sebze & Meyve',
        'storage_zone': 'FRIDGE',
        'quantity_level': 'HALF',
        'unit_label': '500 gr',
        'health_score': 97,
        'added_at': now,
        'expires_at': now + (3 * dayMs),
      },
      {
        'barcode': null,
        'name': 'Kuru Soğan',
        'normalized_tag': 'sogan',
        'brand': 'Yerel Üretim',
        'category': 'Sebze & Meyve',
        'storage_zone': 'PANTRY',
        'quantity_level': 'FULL',
        'unit_label': '2 Kg',
        'health_score': 98,
        'added_at': now,
        'expires_at': now + (30 * dayMs),
      },
      {
        'barcode': null,
        'name': 'Sızma Zeytinyağı',
        'normalized_tag': 'zeytinyagi',
        'brand': 'Ege Sızma',
        'category': 'Sos, Yağ & Baharat',
        'storage_zone': 'PANTRY',
        'quantity_level': 'FULL',
        'unit_label': '1 Litre',
        'health_score': 99,
        'added_at': now,
        'expires_at': now + (180 * dayMs),
      },
      {
        'barcode': null,
        'name': 'Kırmızı Mercimek',
        'normalized_tag': 'kirmizi_mercimek',
        'brand': 'Anadolu Bakliyat',
        'category': 'Bakliyat & Tahıl',
        'storage_zone': 'PANTRY',
        'quantity_level': 'FULL',
        'unit_label': '1 Kg',
        'health_score': 95,
        'added_at': now,
        'expires_at': now + (180 * dayMs),
      },
    ];

    final batch = db.batch();
    for (final item in starterItems) {
      batch.insert('pantry_items', item);
    }
    await batch.commit(noResult: true);
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

    await _createKilerceTables(db);
    await _createMealModuleTables(db);
    await _createMealLifecycleTables(db);
    await _createIndexes(db);
    await _seedInitialData(db);
    await _seedStarterPantryItems(db);
  }

  Future<void> _seedENumbers(Database db) async {
    try {
      final eNumbersString = await rootBundle.loadString('assets/data/e_numbers.json');
      final List<dynamic> eNumbersJson = jsonDecode(eNumbersString) as List<dynamic>;
      final batch = db.batch();
      for (final raw in eNumbersJson) {
        if (raw is! Map) continue;
        final row = mapENumberRow(Map<String, dynamic>.from(raw));
        if ((row['code'] as String).isEmpty) continue;
        batch.insert('e_numbers', row, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    } catch (e) {
      debugPrint('E-numbers seed note: $e');
    }
  }

  Future<void> _seedBoycottBrands(Database db) async {
    try {
      final boycottString = await rootBundle.loadString('assets/data/boycott_list.json');
      final List<dynamic> boycottJson = jsonDecode(boycottString) as List<dynamic>;
      final batch = db.batch();
      for (final raw in boycottJson) {
        if (raw is! Map) continue;
        final item = Map<String, dynamic>.from(raw);
        batch.insert('boycott_brands', {
          'brand_name': item['brand_name'],
          'parent_company': item['parent_company'] ?? item['brand_name'],
          'status_flag': item['boycott_status'] ?? 'FLAGGED',
          'reason': item['reason'],
          'evidence_url': item['evidence_url'],
          'category': item['category'],
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    } catch (e) {
      debugPrint('Boycott seed note: $e');
    }
  }

  Future<void> _seedDefaultFamilyProfiles(Database db) async {
    try {
      await db.insert('family_profiles', {
        'profile_name': 'Çocuk Profili (Katkı Maddesiz & Şekersiz)',
        'is_active': 1,
        'restrictions_json': jsonEncode([
          'SYNTHETIC_COLORS',
          'HIGH_SUGAR',
          'PALM_OIL',
        ]),
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      await db.insert('family_profiles', {
        'profile_name': 'Kendi Profilim (Glutensiz & Helal)',
        'is_active': 0,
        'restrictions_json': jsonEncode([
          'GLUTEN',
          'HALAL',
        ]),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      debugPrint('Family profiles seed note: $e');
    }
  }

  Future<void> _seedTaklitTagsis(Database db) async {
    final int now = DateTime.now().millisecondsSinceEpoch;
    try {
      final tagsisString = await rootBundle.loadString('assets/data/taklit_tagsis_list.json');
      final List<dynamic> tagsisJson = jsonDecode(tagsisString) as List<dynamic>;
      final batch = db.batch();
      for (final raw in tagsisJson) {
        if (raw is! Map) continue;
        final item = Map<String, dynamic>.from(raw);
        batch.insert('taklit_tagsis', {
          'company_name': item['company_name'],
          'brand_name': item['brand_name'],
          'product_name': item['product_name'],
          'reason': item['reason'],
          'category': item['category'] ?? 'Gıda',
          'announced_at': item['announced_at'] ?? now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    } catch (e) {
      debugPrint('Tagsis seed note: $e');
    }
  }

  Future<void> _seedInitialData(Database db) async {
    await _seedENumbers(db);
    await _seedBoycottBrands(db);
    await _seedDefaultFamilyProfiles(db);
    try {
      await _syncSnapshotsWithDb(db);
    } catch (e) {
      debugPrint('Snapshots seed note: $e');
    }
    await _seedTaklitTagsis(db);
  }

  /// Validates GS1 EAN-8 / EAN-13 Modulo-10 check digit and rejects in-store PLU (20-29) & synthetic 8690772000 prefixes.
  static bool isValidGs1Barcode(String barcode) {
    final String cleaned = barcode.trim();
    if (cleaned.length != 8 && cleaned.length != 13) {
      return false;
    }
    for (int i = 0; i < cleaned.length; i++) {
      final int unit = cleaned.codeUnitAt(i);
      if (unit < 0x30 || unit > 0x39) {
        return false;
      }
    }
    if (RegExp(r'^0+$').hasMatch(cleaned)) {
      return false;
    }
    if (cleaned.startsWith('8690772000')) {
      return false;
    }
    if (cleaned.length == 13) {
      final int prefix2 = int.parse(cleaned.substring(0, 2));
      if (prefix2 >= 20 && prefix2 <= 29) {
        return false;
      }
    }

    int sum = 0;
    final int dataLen = cleaned.length - 1;
    for (int i = dataLen - 1; i >= 0; i--) {
      final int digit = cleaned.codeUnitAt(i) - 0x30;
      final int posFromRight = (dataLen - 1) - i;
      sum += digit * (posFromRight.isEven ? 3 : 1);
    }
    final int expectedCheck = (10 - (sum % 10)) % 10;
    final int actualCheck = cleaned.codeUnitAt(dataLen) - 0x30;
    return expectedCheck == actualCheck;
  }

  Future<void> _purgeInvalidSnapshots(Database db) async {
    await db.delete(
      'offline_ai_snapshots',
      where: 'barcode LIKE ?',
      whereArgs: ['8690772000%'],
    );

    final List<Map<String, dynamic>> existing = await db.query(
      'offline_ai_snapshots',
      columns: ['barcode'],
    );
    if (existing.isEmpty) return;

    final Batch purgeBatch = db.batch();
    int invalidCount = 0;
    for (final row in existing) {
      final String bc = (row['barcode']?.toString() ?? '').trim();
      if (!isValidGs1Barcode(bc)) {
        purgeBatch.delete(
          'offline_ai_snapshots',
          where: 'barcode = ?',
          whereArgs: [row['barcode']],
        );
        invalidCount++;
      }
    }
    if (invalidCount > 0) {
      await purgeBatch.commit(noResult: true);
    }
  }

  Future<int> _syncSnapshotsWithDb(Database db) async {
    final String snapshotsString = await rootBundle.loadString('assets/data/top_turkiye_ai_snapshots.json');
    final List<dynamic> snapshotsJson = jsonDecode(snapshotsString) as List<dynamic>;
    final int now = DateTime.now().millisecondsSinceEpoch;
    final Batch batch = db.batch();
    int validSynced = 0;

    for (final dynamic rawItem in snapshotsJson) {
      if (rawItem is! Map) continue;
      final String barcode = (rawItem['barcode']?.toString() ?? '').trim();
      if (!isValidGs1Barcode(barcode)) continue;

      final dynamic rawSummary = rawItem['ai_summary_json'];
      final String encodedSummary = rawSummary is String
          ? rawSummary
          : jsonEncode(rawSummary ?? const <String, dynamic>{});

      batch.insert(
        'offline_ai_snapshots',
        {
          'barcode': barcode,
          'product_name': rawItem['product_name']?.toString() ?? '',
          'brand': rawItem['brand']?.toString() ?? '',
          'ai_summary_json': encodedSummary,
          'synced_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      validSynced++;
    }
    await batch.commit(noResult: true);
    return validSynced;
  }

  /// Inserts or updates an individual verified product snapshot in local SQLite.
  Future<void> saveSnapshot({
    required String barcode,
    required String productName,
    required String brand,
    required Map<String, dynamic> aiSummaryJson,
  }) async {
    final String cleanBarcode = barcode.trim();
    if (!isValidGs1Barcode(cleanBarcode)) {
      debugPrint('Skipped saving snapshot with invalid GS1 barcode: $cleanBarcode');
      return;
    }
    final db = await database;
    await db.insert('offline_ai_snapshots', {
      'barcode': cleanBarcode,
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
      await _purgeInvalidSnapshots(db);
      return await _syncSnapshotsWithDb(db);
    } catch (e) {
      debugPrint('Sync snapshots from asset error: $e');
      return 0;
    }
  }

  /// Searches verified offline product snapshots by barcode, product name, brand, or market chain.
  Future<List<Map<String, dynamic>>> searchVerifiedProducts(
    String query, {
    String? marketChain,
    int limit = 30,
  }) async {
    final db = await database;
    final String trimmed = query.trim();
    final String? trimmedMarket = marketChain?.trim();
    final int safeLimit = limit.clamp(1, 200);

    final List<String> conditions = [];
    final List<Object?> args = [];

    if (trimmed.isNotEmpty) {
      final String likePattern = '%$trimmed%';
      conditions.add('(barcode LIKE ? OR product_name LIKE ? OR brand LIKE ?)');
      args.addAll([likePattern, likePattern, likePattern]);
    }

    if (trimmedMarket != null && trimmedMarket.isNotEmpty) {
      conditions.add('ai_summary_json LIKE ?');
      args.add('%$trimmedMarket%');
    }

    return await db.query(
      'offline_ai_snapshots',
      where: conditions.isEmpty ? null : conditions.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'synced_at DESC, product_name ASC',
      limit: safeLimit,
    );
  }

  /// Returns all E-numbers and additives sorted by code from SQLite.
  Future<List<Map<String, dynamic>>> getAllENumbers() async {
    final db = await database;
    return await db.query('e_numbers', orderBy: 'code ASC');
  }

  /// Returns real live row counts across the local food safety tables.
  Future<Map<String, int>> getDatabaseStats() async {
    final db = await database;
    final products = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM offline_ai_snapshots'),
        ) ??
        0;
    final eNumbers = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM e_numbers'),
        ) ??
        0;
    final tagsis = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM taklit_tagsis'),
        ) ??
        0;
    final boycott = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM boycott_brands'),
        ) ??
        0;
    final history = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM product_history'),
        ) ??
        0;
    return {
      'products': products,
      'e_numbers': eNumbers,
      'taklit_tagsis': tagsis,
      'boycott_brands': boycott,
      'product_history': history,
    };
  }

  Future<void> clearProductHistory() async {
    final db = await database;
    await db.delete('product_history');
  }

  Future<List<Map<String, dynamic>>> getScanHistory({int limit = 50}) async {
    final db = await database;
    return await db.query(
      'product_history',
      orderBy: 'scanned_at DESC',
      limit: limit,
    );
  }
}
