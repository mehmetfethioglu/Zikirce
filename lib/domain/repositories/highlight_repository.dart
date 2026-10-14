import '../../core/errors/app_error.dart';
import '../entities/highlight_entity.dart';

abstract interface class HighlightRepository {
  Future<Result<List<HighlightEntity>>> getHighlightsForBook(int bookId);
  Future<Result<List<HighlightEntity>>> getAllHighlights();
  Future<Result<int>> insertHighlight(HighlightEntity highlight);
  Future<Result<void>> updateHighlightNote(int id, String note);
  Future<Result<void>> deleteHighlight(int id);
  Future<Result<String>> exportHighlightsToMarkdown({int? bookId});
  Future<Result<int>> importHighlightsFromPayload(String payload);
}
