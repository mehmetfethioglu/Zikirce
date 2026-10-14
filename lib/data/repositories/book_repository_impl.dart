import '../../core/errors/app_error.dart';
import '../../domain/entities/book_entity.dart';
import '../../domain/entities/footnote_entity.dart';
import '../../domain/entities/reading_session_entity.dart';
import '../../domain/repositories/book_repository.dart';
import '../datasources/database_helper.dart';
import '../models/book_model.dart';
import '../models/footnote_model.dart';
import '../models/reading_session_model.dart';

class BookRepositoryImpl implements BookRepository {
  final DatabaseHelper _dbHelper;

  BookRepositoryImpl({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  @override
  Future<Result<List<BookEntity>>> getAllBooks() async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query('books', orderBy: 'last_read_date DESC');
      final books = maps.map(BookModel.fromMap).toList();
      return Result.success(books);
    } catch (e, st) {
      return Result.failure(StorageError('Kitaplar yüklenemedi: $e', cause: e, stackTrace: st));
    }
  }

  @override
  Future<Result<BookEntity?>> getBookById(int id) async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query(
        'books',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (maps.isEmpty) return const Result.success(null);
      return Result.success(BookModel.fromMap(maps.first));
    } catch (e, st) {
      return Result.failure(StorageError('Kitap bulunamadı: $e', cause: e, stackTrace: st));
    }
  }

  @override
  Future<Result<int>> insertBook(BookEntity book) async {
    try {
      final db = await _dbHelper.database;
      final id = await db.insert('books', BookModel.toMap(book));
      return Result.success(id);
    } catch (e, st) {
      return Result.failure(StorageError('Kitap eklenemedi: $e', cause: e, stackTrace: st));
    }
  }

  @override
  Future<Result<void>> updateBookProgress({
    required int bookId,
    required int currentPage,
    required double progressPercentage,
    required int additionalReadingTimeSeconds,
  }) async {
    try {
      final db = await _dbHelper.database;
      final now = DateTime.now().toIso8601String();
      await db.rawUpdate('''
        UPDATE books 
        SET current_page = ?, 
            progress_percentage = ?, 
            total_reading_time_seconds = total_reading_time_seconds + ?,
            last_read_date = ?
        WHERE id = ?
      ''', [currentPage, progressPercentage, additionalReadingTimeSeconds, now, bookId]);
      return const Result.success(null);
    } catch (e, st) {
      return Result.failure(StorageError('İlerleme güncellenemedi: $e', cause: e, stackTrace: st));
    }
  }

  @override
  Future<Result<void>> markBookCompleted(int bookId) async {
    try {
      final db = await _dbHelper.database;
      final now = DateTime.now().toIso8601String();
      await db.update(
        'books',
        {
          'is_completed': 1,
          'progress_percentage': 1.0,
          'completed_date': now,
          'last_read_date': now,
        },
        where: 'id = ?',
        whereArgs: [bookId],
      );
      return const Result.success(null);
    } catch (e, st) {
      return Result.failure(StorageError('Kitap tamamlama kaydedilemedi: $e', cause: e, stackTrace: st));
    }
  }

  @override
  Future<Result<void>> deleteBook(int id) async {
    try {
      final db = await _dbHelper.database;
      await db.delete('books', where: 'id = ?', whereArgs: [id]);
      return const Result.success(null);
    } catch (e, st) {
      return Result.failure(StorageError('Kitap silinemedi: $e', cause: e, stackTrace: st));
    }
  }

  @override
  Future<Result<void>> recordReadingSession(ReadingSessionEntity session) async {
    try {
      final db = await _dbHelper.database;
      await db.insert('reading_sessions', ReadingSessionModel.toMap(session));
      return const Result.success(null);
    } catch (e, st) {
      return Result.failure(StorageError('Oturum kaydedilemedi: $e', cause: e, stackTrace: st));
    }
  }

  @override
  Future<Result<List<ReadingSessionEntity>>> getReadingSessions({int? limitDays}) async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query(
        'reading_sessions',
        orderBy: 'session_date DESC',
        limit: limitDays != null ? limitDays * 5 : 100,
      );
      final list = maps.map(ReadingSessionModel.fromMap).toList();
      return Result.success(list);
    } catch (e, st) {
      return Result.failure(StorageError('Oturumlar getirilemedi: $e', cause: e, stackTrace: st));
    }
  }

  @override
  Future<Result<List<InlineFootnoteEntity>>> getFootnotesForBook(int bookId, {int? pageNumber}) async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query(
        'footnotes',
        where: pageNumber != null ? 'book_id = ? AND page_number = ?' : 'book_id = ?',
        whereArgs: pageNumber != null ? [bookId, pageNumber] : [bookId],
      );
      return Result.success(maps.map(FootnoteModel.fromMap).toList());
    } catch (e, st) {
      return Result.failure(StorageError('Dipnotlar yüklenemedi: $e', cause: e, stackTrace: st));
    }
  }

  @override
  Future<Result<void>> insertFootnote(InlineFootnoteEntity footnote) async {
    try {
      final db = await _dbHelper.database;
      await db.insert('footnotes', FootnoteModel.toMap(footnote));
      return const Result.success(null);
    } catch (e, st) {
      return Result.failure(StorageError('Dipnot eklenemedi: $e', cause: e, stackTrace: st));
    }
  }
}
