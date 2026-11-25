import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('tahrir.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 6,
      onCreate: _createDB,
      onUpgrade: _onUpgradeDB,
    );
  }

  Future<void> _onUpgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS scanned_ocr_cache (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          file_path TEXT NOT NULL,
          page_index INTEGER NOT NULL,
          raw_text TEXT NOT NULL,
          structured_json TEXT NOT NULL,
          has_non_latin INTEGER NOT NULL DEFAULT 0,
          word_boxes_json TEXT NOT NULL DEFAULT '[]',
          ocr_confidence REAL NOT NULL DEFAULT 1.0,
          recommended_mode TEXT NOT NULL DEFAULT 'textReflow',
          created_at TEXT NOT NULL,
          UNIQUE(file_path, page_index)
        )
      ''');
    }
    if (oldVersion < 3) {
      await db.execute(
        "UPDATE books SET total_pages = 5, current_page = 1 WHERE file_path LIKE 'sample://%' AND total_pages > 6",
      );
    }
    if (oldVersion < 4) {
      await db.execute('DELETE FROM scanned_ocr_cache');
    }
    if (oldVersion < 5) {
      await db.execute(
        "UPDATE books SET total_pages = 5, current_page = 1, progress_percentage = 0.0 WHERE file_path LIKE 'sample://%' AND total_pages > 6",
      );
    }
    if (oldVersion < 6 && oldVersion >= 2) {
      for (final colDef in const [
        "ALTER TABLE scanned_ocr_cache ADD COLUMN word_boxes_json TEXT NOT NULL DEFAULT '[]'",
        "ALTER TABLE scanned_ocr_cache ADD COLUMN ocr_confidence REAL NOT NULL DEFAULT 1.0",
        "ALTER TABLE scanned_ocr_cache ADD COLUMN recommended_mode TEXT NOT NULL DEFAULT 'textReflow'",
      ]) {
        try {
          await db.execute(colDef);
        } catch (e) {
          debugPrint('DatabaseHelper v6 migration note: $e');
        }
      }
    }
  }

  Future<void> _createDB(Database db, int version) async {
    // 1. Books table
    await db.execute('''
      CREATE TABLE books (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        author TEXT NOT NULL,
        file_path TEXT NOT NULL,
        cover_image_path TEXT,
        format TEXT NOT NULL,
        total_pages INTEGER NOT NULL,
        current_page INTEGER NOT NULL DEFAULT 1,
        progress_percentage REAL NOT NULL DEFAULT 0.0,
        total_reading_time_seconds INTEGER NOT NULL DEFAULT 0,
        estimated_remaining_minutes INTEGER NOT NULL DEFAULT 0,
        added_date TEXT NOT NULL,
        last_read_date TEXT NOT NULL,
        is_completed INTEGER NOT NULL DEFAULT 0,
        completed_date TEXT
      )
    ''');

    // 2. Reading Sessions table
    await db.execute('''
      CREATE TABLE reading_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        book_id INTEGER NOT NULL,
        session_date TEXT NOT NULL,
        duration_seconds INTEGER NOT NULL,
        pages_read INTEGER NOT NULL,
        words_read INTEGER NOT NULL,
        calculated_wpm REAL NOT NULL DEFAULT 0.0,
        FOREIGN KEY (book_id) REFERENCES books (id) ON DELETE CASCADE
      )
    ''');

    // 3. Highlights and Marginalia table
    await db.execute('''
      CREATE TABLE highlights (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        book_id INTEGER NOT NULL,
        page_number INTEGER NOT NULL,
        selected_text TEXT NOT NULL,
        user_note TEXT,
        category TEXT NOT NULL,
        color_hex TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (book_id) REFERENCES books (id) ON DELETE CASCADE
      )
    ''');

    // 4. Footnotes table
    await db.execute('''
      CREATE TABLE footnotes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        book_id INTEGER NOT NULL,
        page_number INTEGER NOT NULL,
        anchor_key TEXT NOT NULL,
        footnote_content TEXT NOT NULL,
        FOREIGN KEY (book_id) REFERENCES books (id) ON DELETE CASCADE
      )
    ''');

    // 5. Habit profile table
    await db.execute('''
      CREATE TABLE habit_profiles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        last_active_date TEXT NOT NULL,
        current_streak INTEGER NOT NULL DEFAULT 0,
        longest_streak INTEGER NOT NULL DEFAULT 0,
        daily_goal_minutes INTEGER NOT NULL DEFAULT 20,
        earned_seals TEXT NOT NULL DEFAULT ''
      )
    ''');

    // 6. Scanned PDF OCR Cache table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS scanned_ocr_cache (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        file_path TEXT NOT NULL,
        page_index INTEGER NOT NULL,
        raw_text TEXT NOT NULL,
        structured_json TEXT NOT NULL,
        has_non_latin INTEGER NOT NULL DEFAULT 0,
        word_boxes_json TEXT NOT NULL DEFAULT '[]',
        ocr_confidence REAL NOT NULL DEFAULT 1.0,
        recommended_mode TEXT NOT NULL DEFAULT 'textReflow',
        created_at TEXT NOT NULL,
        UNIQUE(file_path, page_index)
      )
    ''');

    // Seed default sample demo book if fresh install
    await _seedSampleData(db);
  }

  Future<void> _seedSampleData(Database db) async {
    final now = DateTime.now().toIso8601String();
    
    // Sample Book 1: Divan-ı Hikmet (Reflow & Classical Aesthetic)
    await db.insert('books', {
      'title': 'Kutadgu Bilig (Seçmeler)',
      'author': 'Yusuf Has Hacib',
      'file_path': 'sample://kutadgu_bilig',
      'cover_image_path': null,
      'format': 'markdown',
      'total_pages': 5,
      'current_page': 1,
      'progress_percentage': 0.0,
      'total_reading_time_seconds': 0,
      'estimated_remaining_minutes': 8,
      'added_date': now,
      'last_read_date': now,
      'is_completed': 0,
      'completed_date': null,
    });

    // Sample Book 2: Seyahatname
    await db.insert('books', {
      'title': 'Seyahatname (Tahrir & Şerh)',
      'author': 'Evliya Çelebi',
      'file_path': 'sample://seyahatname',
      'cover_image_path': null,
      'format': 'epub',
      'total_pages': 5,
      'current_page': 1,
      'progress_percentage': 0.0,
      'total_reading_time_seconds': 0,
      'estimated_remaining_minutes': 10,
      'added_date': now,
      'last_read_date': now,
      'is_completed': 0,
      'completed_date': null,
    });

    // Sample Book 3: PDF Hat & Dipnot Dönüşüm Numunesi
    await db.insert('books', {
      'title': 'İslam Âdâb-ı Muaşereti (PDF Numunesi)',
      'author': 'Abdülfettah Ebû Gudde',
      'file_path': 'sample://adab_muaseret',
      'cover_image_path': null,
      'format': 'pdf',
      'total_pages': 5,
      'current_page': 1,
      'progress_percentage': 0.0,
      'total_reading_time_seconds': 0,
      'estimated_remaining_minutes': 8,
      'added_date': now,
      'last_read_date': now,
      'is_completed': 0,
      'completed_date': null,
    });

    // Sample Habit profile (dürüst sıfır başlangıç)
    await db.insert('habit_profiles', {
      'last_active_date': now,
      'current_streak': 0,
      'longest_streak': 0,
      'daily_goal_minutes': 20,
      'earned_seals': '',
    });
  }

  /// Taranmış PDF OCR sayfa önbelleğini sorgular
  Future<Map<String, dynamic>?> getScannedOcrPage(String filePath, int pageIndex) async {
    final db = await database;
    final results = await db.query(
      'scanned_ocr_cache',
      where: 'file_path = ? AND page_index = ?',
      whereArgs: [filePath, pageIndex],
      limit: 1,
    );
    if (results.isNotEmpty) {
      return results.first;
    }
    return null;
  }

  /// Taranmış PDF OCR sayfasını ve kelime koordinatlarını kalıcı olarak SQLite'a kaydeder
  Future<void> saveScannedOcrPage({
    required String filePath,
    required int pageIndex,
    required String rawText,
    required String structuredJson,
    required bool hasNonLatin,
    String wordBoxesJson = '[]',
    double ocrConfidence = 1.0,
    String recommendedMode = 'textReflow',
  }) async {
    final db = await database;
    await db.insert(
      'scanned_ocr_cache',
      {
        'file_path': filePath,
        'page_index': pageIndex,
        'raw_text': rawText,
        'structured_json': structuredJson,
        'has_non_latin': hasNonLatin ? 1 : 0,
        'word_boxes_json': wordBoxesJson,
        'ocr_confidence': ocrConfidence,
        'recommended_mode': recommendedMode,
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
