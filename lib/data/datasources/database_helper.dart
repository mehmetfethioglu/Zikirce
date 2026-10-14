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
      version: 2,
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
          created_at TEXT NOT NULL,
          UNIQUE(file_path, page_index)
        )
      ''');
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
      'total_pages': 42,
      'current_page': 1,
      'progress_percentage': 0.0,
      'total_reading_time_seconds': 120,
      'estimated_remaining_minutes': 35,
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
      'total_pages': 88,
      'current_page': 14,
      'progress_percentage': 0.16,
      'total_reading_time_seconds': 950,
      'estimated_remaining_minutes': 80,
      'added_date': now,
      'last_read_date': now,
      'is_completed': 0,
      'completed_date': null,
    });

    // Sample Habit profile
    await db.insert('habit_profiles', {
      'last_active_date': now,
      'current_streak': 3,
      'longest_streak': 7,
      'daily_goal_minutes': 20,
      'earned_seals': 'seal_first_book,seal_night_owl',
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

  /// Taranmış PDF OCR sayfasını kalıcı olarak SQLite'a kaydeder
  Future<void> saveScannedOcrPage({
    required String filePath,
    required int pageIndex,
    required String rawText,
    required String structuredJson,
    required bool hasNonLatin,
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
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
