class PageAiInsights {
  final List<String> summaryBulletPoints;
  final List<String> keyConcepts;
  final String complexityLevel;
  final int estimatedReadTimeSeconds;

  PageAiInsights({
    required this.summaryBulletPoints,
    required this.keyConcepts,
    required this.complexityLevel,
    required this.estimatedReadTimeSeconds,
  });
}

class OfflineAiService {
  const OfflineAiService();

  /// Analyzes text locally without internet and generates instant cognitive summary
  PageAiInsights analyzeText(String text) {
    if (text.trim().isEmpty) {
      return PageAiInsights(
        summaryBulletPoints: ['Metin içeriği bulunamadı.'],
        keyConcepts: [],
        complexityLevel: 'Belirsiz',
        estimatedReadTimeSeconds: 0,
      );
    }

    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final wordCount = words.length;
    final estimatedSeconds = ((wordCount / 200) * 60).round().clamp(10, 3600);

    // Identify candidate keywords (length > 5, capitalized or repeated)
    final frequency = <String, int>{};
    final stopWords = {
      'bir', 'bu', 've', 'için', 'ile', 'de', 'da', 'gibi', 'olan', 'kadar',
      'daha', 'çok', 'en', 'ise', 'her', 'kendi', 'sonra', 'önce', 'olarak',
      'the', 'and', 'for', 'with', 'that', 'this', 'from'
    };

    for (final rawWord in words) {
      final clean = rawWord.replaceAll(RegExp(r'[^\w]', unicode: true), '').toLowerCase();
      if (clean.length >= 4 && !stopWords.contains(clean)) {
        frequency[clean] = (frequency[clean] ?? 0) + 1;
      }
    }

    final sortedKeywords = frequency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topConcepts = sortedKeywords
        .take(4)
        .map((e) => e.key[0].toUpperCase() + e.key.substring(1))
        .toList();

    // Extract key sentences for bullet point summary
    final sentences = text
        .split(RegExp(r'(?<=[.!?])\s+'))
        .where((s) => s.trim().length > 20)
        .toList();

    final bullets = <String>[];
    if (sentences.isNotEmpty) {
      bullets.add(sentences.first.trim());
      if (sentences.length > 2) {
        bullets.add(sentences[sentences.length ~/ 2].trim());
      }
      if (sentences.length > 1) {
        bullets.add(sentences.last.trim());
      }
    } else {
      bullets.add(text.substring(0, text.length.clamp(0, 120)));
    }

    final avgWordLen = wordCount > 0
        ? words.fold<int>(0, (acc, w) => acc + w.length) / wordCount
        : 5.0;

    final complexity = avgWordLen > 7.0
        ? 'Akademik / Yoğun (Ağır Metin)'
        : (avgWordLen > 5.8 ? 'Edebi & Düşünsel' : 'Akıcı & Rahat');

    return PageAiInsights(
      summaryBulletPoints: bullets,
      keyConcepts: topConcepts.isNotEmpty ? topConcepts : ['Okuma', 'Metin', 'Tahrir'],
      complexityLevel: complexity,
      estimatedReadTimeSeconds: estimatedSeconds,
    );
  }
}
