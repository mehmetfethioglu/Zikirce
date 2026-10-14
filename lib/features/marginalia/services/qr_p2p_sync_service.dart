import 'dart:convert';
import '../../../core/errors/app_error.dart';
import '../../../domain/repositories/highlight_repository.dart';

class QrP2pSyncService {
  final HighlightRepository _highlightRepository;

  QrP2pSyncService(this._highlightRepository);

  /// Serializes highlights for a book or all highlights into a compact payload for QR generation
  Future<Result<String>> generateSharePayload({int? bookId}) async {
    try {
      final result = bookId != null
          ? await _highlightRepository.getHighlightsForBook(bookId)
          : await _highlightRepository.getAllHighlights();

      if (result.isFailure) return Result.failure(result.errorOrNull!);
      final list = result.dataOrNull ?? [];

      final minified = list.map((h) => {
            'book_id': h.bookId,
            'page_number': h.pageNumber,
            'selected_text': h.selectedText,
            'user_note': h.userNote,
            'category': h.category.name,
            'color_hex': h.colorHex,
          }).toList();

      final jsonStr = jsonEncode(minified);
      return Result.success(jsonStr);
    } catch (e, st) {
      return Result.failure(GeneralError('QR paketi hazırlanamadı: $e', cause: e, stackTrace: st));
    }
  }

  /// Deserializes scanned QR payload and writes highlights into local SQLite DB
  Future<Result<int>> importFromPayload(String payload) async {
    return _highlightRepository.importHighlightsFromPayload(payload);
  }
}
