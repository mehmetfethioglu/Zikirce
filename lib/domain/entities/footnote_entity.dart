class InlineFootnoteEntity {
  final int? id;
  final int bookId;
  final int pageNumber;
  final String anchorKey; // örn: [1], *, §
  final String footnoteContent;

  const InlineFootnoteEntity({
    this.id,
    required this.bookId,
    required this.pageNumber,
    required this.anchorKey,
    required this.footnoteContent,
  });
}
