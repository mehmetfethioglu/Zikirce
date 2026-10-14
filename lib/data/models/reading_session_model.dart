import '../../domain/entities/reading_session_entity.dart';

class ReadingSessionModel {
  static ReadingSessionEntity fromMap(Map<String, dynamic> map) {
    return ReadingSessionEntity(
      id: map['id'] as int?,
      bookId: map['book_id'] as int,
      sessionDate: DateTime.parse(map['session_date'] as String),
      durationSeconds: map['duration_seconds'] as int,
      pagesRead: map['pages_read'] as int,
      wordsRead: map['words_read'] as int,
      calculatedWpm: (map['calculated_wpm'] as num?)?.toDouble() ?? 0.0,
    );
  }

  static Map<String, dynamic> toMap(ReadingSessionEntity entity) {
    return {
      if (entity.id != null) 'id': entity.id,
      'book_id': entity.bookId,
      'session_date': entity.sessionDate.toIso8601String(),
      'duration_seconds': entity.durationSeconds,
      'pages_read': entity.pagesRead,
      'words_read': entity.wordsRead,
      'calculated_wpm': entity.calculatedWpm,
    };
  }
}
