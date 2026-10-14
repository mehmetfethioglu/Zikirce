import '../../domain/entities/footnote_entity.dart';

class FootnoteModel {
  static InlineFootnoteEntity fromMap(Map<String, dynamic> map) {
    return InlineFootnoteEntity(
      id: map['id'] as int?,
      bookId: map['book_id'] as int,
      pageNumber: map['page_number'] as int,
      anchorKey: map['anchor_key'] as String,
      footnoteContent: map['footnote_content'] as String,
    );
  }

  static Map<String, dynamic> toMap(InlineFootnoteEntity entity) {
    return {
      if (entity.id != null) 'id': entity.id,
      'book_id': entity.bookId,
      'page_number': entity.pageNumber,
      'anchor_key': entity.anchorKey,
      'footnote_content': entity.footnoteContent,
    };
  }
}
