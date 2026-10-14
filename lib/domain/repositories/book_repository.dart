import '../../core/errors/app_error.dart';
import '../entities/book_entity.dart';
import '../entities/reading_session_entity.dart';
import '../entities/footnote_entity.dart';

abstract interface class BookRepository {
  Future<Result<List<BookEntity>>> getAllBooks();
  Future<Result<BookEntity?>> getBookById(int id);
  Future<Result<int>> insertBook(BookEntity book);
  Future<Result<void>> updateBookProgress({
    required int bookId,
    required int currentPage,
    required double progressPercentage,
    required int additionalReadingTimeSeconds,
  });
  Future<Result<void>> markBookCompleted(int bookId);
  Future<Result<void>> deleteBook(int id);

  // Sessions & Analytics
  Future<Result<void>> recordReadingSession(ReadingSessionEntity session);
  Future<Result<List<ReadingSessionEntity>>> getReadingSessions({int? limitDays});

  // Footnotes
  Future<Result<List<InlineFootnoteEntity>>> getFootnotesForBook(int bookId, {int? pageNumber});
  Future<Result<void>> insertFootnote(InlineFootnoteEntity footnote);
}
