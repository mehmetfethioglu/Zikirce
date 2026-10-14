enum BookFormat {
  pdf,
  epub,
  markdown,
  txt,
  webArticle,
}

class BookEntity {
  final int? id;
  final String title;
  final String author;
  final String filePath;
  final String? coverImagePath;
  final BookFormat format;
  final int totalPages;
  final int currentPage;
  final double progressPercentage;
  final int totalReadingTimeSeconds;
  final int estimatedRemainingMinutes;
  final DateTime addedDate;
  final DateTime lastReadDate;
  final bool isCompleted;
  final DateTime? completedDate;

  const BookEntity({
    this.id,
    required this.title,
    required this.author,
    required this.filePath,
    this.coverImagePath,
    required this.format,
    required this.totalPages,
    this.currentPage = 1,
    this.progressPercentage = 0.0,
    this.totalReadingTimeSeconds = 0,
    this.estimatedRemainingMinutes = 0,
    required this.addedDate,
    required this.lastReadDate,
    this.isCompleted = false,
    this.completedDate,
  });

  BookEntity copyWith({
    int? id,
    String? title,
    String? author,
    String? filePath,
    String? coverImagePath,
    BookFormat? format,
    int? totalPages,
    int? currentPage,
    double? progressPercentage,
    int? totalReadingTimeSeconds,
    int? estimatedRemainingMinutes,
    DateTime? addedDate,
    DateTime? lastReadDate,
    bool? isCompleted,
    DateTime? completedDate,
  }) {
    return BookEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      filePath: filePath ?? this.filePath,
      coverImagePath: coverImagePath ?? this.coverImagePath,
      format: format ?? this.format,
      totalPages: totalPages ?? this.totalPages,
      currentPage: currentPage ?? this.currentPage,
      progressPercentage: progressPercentage ?? this.progressPercentage,
      totalReadingTimeSeconds: totalReadingTimeSeconds ?? this.totalReadingTimeSeconds,
      estimatedRemainingMinutes: estimatedRemainingMinutes ?? this.estimatedRemainingMinutes,
      addedDate: addedDate ?? this.addedDate,
      lastReadDate: lastReadDate ?? this.lastReadDate,
      isCompleted: isCompleted ?? this.isCompleted,
      completedDate: completedDate ?? this.completedDate,
    );
  }
}
