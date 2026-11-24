enum HighlightCategory {
  thought,   // Kişisel düşünce
  quote,     // Alıntı
  question,  // Soru & Araştırma
  critical,  // Eleştiri
}

extension HighlightCategoryX on HighlightCategory {
  String get displayName => switch (this) {
        HighlightCategory.thought => 'Düşünce & Not',
        HighlightCategory.quote => 'Alıntı',
        HighlightCategory.question => 'Soru & Araştırma',
        HighlightCategory.critical => 'Eleştiri',
      };
}

class HighlightEntity {
  final int? id;
  final int bookId;
  final int pageNumber;
  final String selectedText;
  final String? userNote;
  final HighlightCategory category;
  final String colorHex;
  final DateTime createdAt;

  const HighlightEntity({
    this.id,
    required this.bookId,
    required this.pageNumber,
    required this.selectedText,
    this.userNote,
    this.category = HighlightCategory.thought,
    this.colorHex = '#FFE58F',
    required this.createdAt,
  });

  HighlightEntity copyWith({
    int? id,
    int? bookId,
    int? pageNumber,
    String? selectedText,
    String? userNote,
    HighlightCategory? category,
    String? colorHex,
    DateTime? createdAt,
  }) {
    return HighlightEntity(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      pageNumber: pageNumber ?? this.pageNumber,
      selectedText: selectedText ?? this.selectedText,
      userNote: userNote ?? this.userNote,
      category: category ?? this.category,
      colorHex: colorHex ?? this.colorHex,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
