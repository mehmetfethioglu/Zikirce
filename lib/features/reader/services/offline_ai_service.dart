import 'dart:math' as math;

class PageAiInsights {
  final List<String> summaryBulletPoints;
  final List<String> keyConcepts;
  final String complexityLevel;
  final int estimatedReadTimeSeconds;
  final List<String> studyQuestions;

  PageAiInsights({
    required this.summaryBulletPoints,
    required this.keyConcepts,
    required this.complexityLevel,
    required this.estimatedReadTimeSeconds,
    this.studyQuestions = const [],
  });
}

class OfflineAiService {
  const OfflineAiService();

  static const Set<String> _stopWords = {
    'bir', 'bu', 've', 'için', 'ile', 'de', 'da', 'gibi', 'olan', 'kadar',
    'daha', 'çok', 'en', 'ise', 'her', 'kendi', 'sonra', 'önce', 'olarak',
    'ama', 'fakat', 'lakin', 'ancak', 'çünkü', 'veya', 'yahut', 'hem', 'ne',
    'ki', 'mi', 'mı', 'mu', 'mü', 'شو', 'o', 'şu', 'bunu', 'şunu', 'onun',
    'böyle', 'şöyle', 'öyle', 'üzere', 'göre', 'karşı', 'doğru', 'rağmen',
    'the', 'and', 'for', 'with', 'that', 'this', 'from', 'are', 'was', 'were',
  };

  /// Analyzes text locally without internet using TF-IDF & TextRank lexical centrality
  PageAiInsights analyzeText(String text) {
    if (text.trim().isEmpty) {
      return PageAiInsights(
        summaryBulletPoints: ['Metin içeriği bulunamadı.'],
        keyConcepts: [],
        complexityLevel: 'Belirsiz',
        estimatedReadTimeSeconds: 0,
        studyQuestions: const [],
      );
    }

    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final wordCount = words.length;
    final estimatedSeconds = ((wordCount / 200) * 60).round().clamp(10, 3600);

    // 1. Term Frequency (TF) calculation over meaningful words
    final frequency = <String, int>{};
    for (final rawWord in words) {
      final clean = rawWord.replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '').toLowerCase();
      if (clean.length >= 4 && !_stopWords.contains(clean)) {
        frequency[clean] = (frequency[clean] ?? 0) + 1;
      }
    }

    final sortedKeywords = frequency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topConcepts = sortedKeywords
        .take(4)
        .map((e) => e.key[0].toUpperCase() + e.key.substring(1))
        .toList();

    // 2. Sentence segmentation & TextRank / TF-IDF Lexical Centrality scoring
    final sentences = text
        .split(RegExp(r'(?<=[.!?…])\s+|\n+'))
        .map((s) => s.trim())
        .where((s) => s.length > 20)
        .toList();

    final bullets = <String>[];
    if (sentences.isNotEmpty) {
      final sentenceTokens = <Set<String>>[];
      for (final s in sentences) {
        final tokens = s
            .split(RegExp(r'\s+'))
            .map((w) => w.replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '').toLowerCase())
            .where((w) => w.length >= 4 && !_stopWords.contains(w))
            .toSet();
        sentenceTokens.add(tokens);
      }

      final scores = List<double>.filled(sentences.length, 0.0);
      for (int i = 0; i < sentences.length; i++) {
        final tokensI = sentenceTokens[i];
        if (tokensI.isEmpty) continue;

        // TF weight of sentence i
        double tfSum = 0.0;
        for (final t in tokensI) {
          tfSum += (frequency[t] ?? 1).toDouble();
        }
        final tfScore = tfSum / math.sqrt(tokensI.length + 1.0);

        // TextRank lexical overlap with other sentences
        double centralitySum = 0.0;
        for (int j = 0; j < sentences.length; j++) {
          if (i == j) continue;
          final tokensJ = sentenceTokens[j];
          if (tokensJ.isEmpty) continue;

          int shared = 0;
          for (final t in tokensI) {
            if (tokensJ.contains(t)) shared++;
          }
          if (shared > 0) {
            final norm = math.log(tokensI.length + 2.0) + math.log(tokensJ.length + 2.0);
            centralitySum += shared / (norm > 0 ? norm : 1.0);
          }
        }

        final positionBoost = i == 0 ? 1.08 : 1.0;
        scores[i] = (tfScore * 0.55 + centralitySum * 4.5) * positionBoost;
      }

      final indexedScores = List<int>.generate(sentences.length, (i) => i);
      indexedScores.sort((a, b) => scores[b].compareTo(scores[a]));

      final selectedIndices = indexedScores.take(math.min(3, sentences.length)).toList()
        ..sort();

      for (final idx in selectedIndices) {
        bullets.add(sentences[idx]);
      }
    } else {
      bullets.add(text.substring(0, text.length.clamp(0, 120)).trim());
    }

    // 3. Generate Tefekkür & Çalışma Soruları (Study Questions)
    final studyQuestions = <String>[];
    if (topConcepts.isNotEmpty) {
      studyQuestions.add(
        "Metinde vurgulanan '${topConcepts[0]}' kavramının ana düşünceyle ilişkisi nedir?",
      );
      if (topConcepts.length >= 2) {
        studyQuestions.add(
          "Yazar '${topConcepts[0]}' ile '${topConcepts[1]}' kavramları arasında nasıl bir düşünsel bağ kurmaktadır?",
        );
      } else {
        studyQuestions.add(
          "Bu bölümde ele alınan ilke ve önermeler günlük hayata nasıl tatbik edilebilir?",
        );
      }
      studyQuestions.add(
        "Yazarın bu bölümde ortaya koyduğu temel argüman nasıl özetlenebilir?",
      );
    } else {
      studyQuestions.add(
        "Yazarın bu bölümde ortaya koyduğu temel argüman nasıl özetlenebilir?",
      );
      studyQuestions.add(
        "Metindeki ana fikri destekleyen temel örnek veya deliller nelerdir?",
      );
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
      studyQuestions: studyQuestions,
    );
  }
}
