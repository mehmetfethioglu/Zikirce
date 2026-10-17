
class VerseChunk {
  final int chunkIndex;
  final int totalChunks;
  final String text;
  final List<String> words;
  final String? punctuationSymbol;

  VerseChunk({
    required this.chunkIndex,
    required this.totalChunks,
    required this.text,
    required this.words,
    this.punctuationSymbol,
  });
}

class VerseChunkerService {
  static const List<String> standalonePunctuationWords = [
    'ج',
    'قلى',
    'صلى',
    'ز',
    'ط',
    'م',
    'لا',
  ];

  static const List<String> quranicPunctuationSymbols = [
    'ۖ',
    'ۗ',
    'ۚ',
    'ۛ',
    'ۜ',
    '۪',
    'ۘ',
  ];

  /// Ayeti kelime sayısına ve vakıf/durak işaretlerine göre mantıksal parçalara böler.
  /// [arabicText]: Arapça ayet metni
  /// [maxWordThreshold]: Parçalamayı tetikleyecek maksimum kelime eşiği (varsayılan: 15)
  /// [targetFallbackChunkSize]: Durak olmaması durumunda hedeflenen parça kelime büyüklüğü (varsayılan: 10)
  List<VerseChunk> chunkVerse(
    String arabicText, {
    int maxWordThreshold = 15,
    int targetFallbackChunkSize = 10,
  }) {
    if (arabicText.trim().isEmpty) {
      return [];
    }

    final allWords = arabicText
        .split(RegExp(r'\s+'))
        .where((w) => w.trim().isNotEmpty)
        .toList();

    if (allWords.length <= maxWordThreshold) {
      return [
        VerseChunk(
          chunkIndex: 1,
          totalChunks: 1,
          text: allWords.join(' '),
          words: allWords,
        ),
      ];
    }

    // 1. Aşama: Durak / Vakıf işaretlerine göre bölme denemesi
    final initialChunks = _splitByPunctuation(allWords);

    // 2. Aşama: Durak bulunmayan veya parçalandıktan sonra halen > maxWordThreshold kalan kısımlarda Fallback parçalama
    final finalChunks = <VerseChunk>[];

    for (final chunk in initialChunks) {
      if (chunk.words.length > maxWordThreshold) {
        final subChunks = _splitByWordBoundary(chunk.words, targetFallbackChunkSize);
        finalChunks.addAll(subChunks);
      } else {
        finalChunks.add(chunk);
      }
    }

    // TotalChunks ve ChunkIndex numaralandırması
    final count = finalChunks.length;
    return List.generate(count, (i) {
      final old = finalChunks[i];
      return VerseChunk(
        chunkIndex: i + 1,
        totalChunks: count,
        text: old.text,
        words: old.words,
        punctuationSymbol: old.punctuationSymbol,
      );
    });
  }

  List<VerseChunk> _splitByPunctuation(List<String> words) {
    final result = <VerseChunk>[];
    var currentWords = <String>[];
    String? currentPunctuation;

    for (int i = 0; i < words.length; i++) {
      final word = words[i];
      currentWords.add(word);

      final matchedPunctuation = _getMatchingPunctuation(word);
      final isLastWord = (i == words.length - 1);

      if (matchedPunctuation != null || isLastWord) {
        currentPunctuation = matchedPunctuation;
        result.add(
          VerseChunk(
            chunkIndex: 1,
            totalChunks: 1,
            text: currentWords.join(' '),
            words: List.from(currentWords),
            punctuationSymbol: currentPunctuation,
          ),
        );
        currentWords = <String>[];
        currentPunctuation = null;
      }
    }

    if (currentWords.isNotEmpty) {
      result.add(
        VerseChunk(
          chunkIndex: 1,
          totalChunks: 1,
          text: currentWords.join(' '),
          words: List.from(currentWords),
        ),
      );
    }

    return result;
  }

  String? _getMatchingPunctuation(String word) {
    if (word.trim().isEmpty) return null;

    for (final p in standalonePunctuationWords) {
      if (word == p) return p;
    }

    for (final p in quranicPunctuationSymbols) {
      if (word.contains(p)) return p;
    }

    return null;
  }

  List<VerseChunk> _splitByWordBoundary(List<String> words, int chunkSize) {
    final result = <VerseChunk>[];
    for (int i = 0; i < words.length; i += chunkSize) {
      final end = (i + chunkSize < words.length) ? i + chunkSize : words.length;
      final group = words.sublist(i, end);
      result.add(
        VerseChunk(
          chunkIndex: 1,
          totalChunks: 1,
          text: group.join(' '),
          words: group,
        ),
      );
    }
    return result;
  }
}
