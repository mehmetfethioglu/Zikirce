import '../../domain/entities/book_entity.dart';

class BookModel {
  static BookEntity fromMap(Map<String, dynamic> map) {
    return BookEntity(
      id: map['id'] as int?,
      title: map['title'] as String,
      author: map['author'] as String,
      filePath: map['file_path'] as String,
      coverImagePath: map['cover_image_path'] as String?,
      format: BookFormat.values.firstWhere(
        (f) => f.name == map['format'],
        orElse: () => BookFormat.pdf,
      ),
      totalPages: map['total_pages'] as int,
      currentPage: map['current_page'] as int? ?? 1,
      progressPercentage: (map['progress_percentage'] as num?)?.toDouble() ?? 0.0,
      totalReadingTimeSeconds: map['total_reading_time_seconds'] as int? ?? 0,
      estimatedRemainingMinutes: map['estimated_remaining_minutes'] as int? ?? 0,
      addedDate: DateTime.parse(map['added_date'] as String),
      lastReadDate: DateTime.parse(map['last_read_date'] as String),
      isCompleted: (map['is_completed'] as int? ?? 0) == 1,
      completedDate: map['completed_date'] != null
          ? DateTime.tryParse(map['completed_date'] as String)
          : null,
    );
  }

  static Map<String, dynamic> toMap(BookEntity entity) {
    return {
      if (entity.id != null) 'id': entity.id,
      'title': entity.title,
      'author': entity.author,
      'file_path': entity.filePath,
      'cover_image_path': entity.coverImagePath,
      'format': entity.format.name,
      'total_pages': entity.totalPages,
      'current_page': entity.currentPage,
      'progress_percentage': entity.progressPercentage,
      'total_reading_time_seconds': entity.totalReadingTimeSeconds,
      'estimated_remaining_minutes': entity.estimatedRemainingMinutes,
      'added_date': entity.addedDate.toIso8601String(),
      'last_read_date': entity.lastReadDate.toIso8601String(),
      'is_completed': entity.isCompleted ? 1 : 0,
      'completed_date': entity.completedDate?.toIso8601String(),
    };
  }
}
