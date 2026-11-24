import 'dart:convert';
import '../../core/errors/app_error.dart';
import '../../domain/entities/highlight_entity.dart';
import '../../domain/repositories/highlight_repository.dart';
import '../datasources/database_helper.dart';
import '../models/highlight_model.dart';

class HighlightRepositoryImpl implements HighlightRepository {
  final DatabaseHelper _dbHelper;

  HighlightRepositoryImpl({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  @override
  Future<Result<List<HighlightEntity>>> getHighlightsForBook(int bookId) async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query(
        'highlights',
        where: 'book_id = ?',
        whereArgs: [bookId],
        orderBy: 'page_number ASC, created_at ASC',
      );
      return Result.success(maps.map(HighlightModel.fromMap).toList());
    } catch (e, st) {
      return Result.failure(StorageError('Vurgular getirilemedi: $e', cause: e, stackTrace: st));
    }
  }

  @override
  Future<Result<List<HighlightEntity>>> getAllHighlights() async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query('highlights', orderBy: 'created_at DESC');
      return Result.success(maps.map(HighlightModel.fromMap).toList());
    } catch (e, st) {
      return Result.failure(StorageError('Vurgular listelenemedi: $e', cause: e, stackTrace: st));
    }
  }

  @override
  Future<Result<int>> insertHighlight(HighlightEntity highlight) async {
    try {
      final db = await _dbHelper.database;
      final id = await db.insert('highlights', HighlightModel.toMap(highlight));
      return Result.success(id);
    } catch (e, st) {
      return Result.failure(StorageError('Vurgu kaydedilemedi: $e', cause: e, stackTrace: st));
    }
  }

  @override
  Future<Result<void>> updateHighlightNote(int id, String note) async {
    try {
      final db = await _dbHelper.database;
      await db.update(
        'highlights',
        {'user_note': note},
        where: 'id = ?',
        whereArgs: [id],
      );
      return const Result.success(null);
    } catch (e, st) {
      return Result.failure(StorageError('Not güncellenemedi: $e', cause: e, stackTrace: st));
    }
  }

  @override
  Future<Result<void>> deleteHighlight(int id) async {
    try {
      final db = await _dbHelper.database;
      await db.delete('highlights', where: 'id = ?', whereArgs: [id]);
      return const Result.success(null);
    } catch (e, st) {
      return Result.failure(StorageError('Vurgu silinemedi: $e', cause: e, stackTrace: st));
    }
  }

  @override
  Future<Result<String>> exportHighlightsToMarkdown({int? bookId}) async {
    try {
      final result = bookId != null ? await getHighlightsForBook(bookId) : await getAllHighlights();
      if (result.isFailure) return Result.failure(result.errorOrNull!);
      final list = result.dataOrNull ?? [];

      final buffer = StringBuffer();
      buffer.writeln('# 📜 Tahrir Not & Alıntı Arşivi');
      buffer.writeln('**Dışa Aktarma Tarihi:** ${DateTime.now().toLocal()}\n');

      for (final h in list) {
        buffer.writeln('### Sayfa ${h.pageNumber} - [${h.category.displayName}]');
        buffer.writeln('> "${h.selectedText}"\n');
        if (h.userNote != null && h.userNote!.isNotEmpty) {
          buffer.writeln('✍️ **Tahrir Notu:** ${h.userNote}\n');
        }
        buffer.writeln('---\n');
      }

      return Result.success(buffer.toString());
    } catch (e, st) {
      return Result.failure(GeneralError('Markdown üretilemedi: $e', cause: e, stackTrace: st));
    }
  }

  @override
  Future<Result<int>> importHighlightsFromPayload(String payload) async {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! List) return const Result.failure(ParsingError('Geçersiz paket formatı'));
      final db = await _dbHelper.database;
      int imported = 0;
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          await db.insert('highlights', {
            'book_id': item['book_id'] ?? 1,
            'page_number': item['page_number'] ?? 1,
            'selected_text': item['selected_text'] ?? '',
            'user_note': item['user_note'],
            'category': item['category'] ?? 'thought',
            'color_hex': item['color_hex'] ?? '#FFE58F',
            'created_at': DateTime.now().toIso8601String(),
          });
          imported++;
        }
      }
      return Result.success(imported);
    } catch (e, st) {
      return Result.failure(ParsingError('İçe aktarma hatası: $e', cause: e, stackTrace: st));
    }
  }
}
