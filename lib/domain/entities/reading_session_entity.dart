class ReadingSessionEntity {
  final int? id;
  final int bookId;
  final DateTime sessionDate;
  final int durationSeconds;
  final int pagesRead;
  final int wordsRead;
  final double calculatedWpm;

  const ReadingSessionEntity({
    this.id,
    required this.bookId,
    required this.sessionDate,
    required this.durationSeconds,
    required this.pagesRead,
    required this.wordsRead,
    this.calculatedWpm = 0.0,
  });
}
