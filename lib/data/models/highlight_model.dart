import '../../domain/entities/highlight_entity.dart';

class HighlightModel {
  static HighlightEntity fromMap(Map<String, dynamic> map) {
    return HighlightEntity(
      id: map['id'] as int?,
      bookId: map['book_id'] as int,
      pageNumber: map['page_number'] as int,
      selectedText: map['selected_text'] as String,
      userNote: map['user_note'] as String?,
      category: HighlightCategory.values.firstWhere(
        (c) => c.name == map['category'],
        orElse: () => HighlightCategory.thought,
      ),
      colorHex: map['color_hex'] as String? ?? '#FFE58F',
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  static Map<String, dynamic> toMap(HighlightEntity entity) {
    return {
      if (entity.id != null) 'id': entity.id,
      'book_id': entity.bookId,
      'page_number': entity.pageNumber,
      'selected_text': entity.selectedText,
      'user_note': entity.userNote,
      'category': entity.category.name,
      'color_hex': entity.colorHex,
      'created_at': entity.createdAt.toIso8601String(),
    };
  }
}
