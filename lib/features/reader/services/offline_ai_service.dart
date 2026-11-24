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

  /// Türkçe çekim eklerini soyarak kavram araması için morfolojik kök/gövde döndürür.
  static String extractConceptStem(String word) {
    var clean = word
        .replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '')
        .toLowerCase()
        .trim();
    if (clean.length <= 4) return clean;

    const suffixes = [
      'larından', 'lerinden', 'larımız', 'lerimiz', 'larının', 'lerinin',
      'lardan', 'lerden', 'maları', 'meleri', 'dkları', 'dikleri',
      'ության', 'larını', 'lerini', 'larıyla', 'leriyle',
      'ından', 'inden', 'undan', 'ünden', '적인', 'larıyla',
      'ları', 'leri', 'ndan', 'nden', 'mız', 'miz', 'nız', 'niz',
      'dan', 'den', 'tan', 'ten', 'nin', 'nın', 'nun', 'nün',
      'da', 'de', 'ta', 'te', 'yi', 'yı', 'yu', 'yü', 'ya', 'ye',
      'in', 'ın', 'un', 'ün', 'le', 'la', 'ki', 'i', 'ı', 'u', 'ü', 'a', 'e',
    ];

    for (final s in suffixes) {
      if (clean.length - s.length >= 4 && clean.endsWith(s)) {
        clean = clean.substring(0, clean.length - s.length);
        break;
      }
    }

    // Ünsüz yumuşaması geri dönüşümü (örn. kitabı -> kitap, ahlakı -> ahlak, kalbi -> kalp)
    if (clean.length >= 4) {
      if (clean.endsWith('b')) {
        clean = '${clean.substring(0, clean.length - 1)}p';
      } else if (clean.endsWith('c')) {
        clean = '${clean.substring(0, clean.length - 1)}ç';
      } else if (clean.endsWith('d')) {
        clean = '${clean.substring(0, clean.length - 1)}t';
      } else if (clean.endsWith('ğ')) {
        clean = '${clean.substring(0, clean.length - 1)}k';
      }
    }
    return clean;
  }

  /// Kitabın taranmış/indekslenmiş sayfaları üzerinde gerçek Çapraz İndeks (Concordance)
  /// ve Kavram İlişki Ağı (Co-occurring Concepts) analizi yapar.
  ConceptRadarResult buildConcordance({
    required String concept,
    required Map<int, String> pageTexts,
  }) {
    final cleanQuery = concept.trim();
    if (cleanQuery.isEmpty || pageTexts.isEmpty) {
      return ConceptRadarResult(
        queryConcept: cleanQuery,
        stemUsed: cleanQuery.toLowerCase(),
        totalOccurrences: 0,
        firstSeenPage: 1,
        peakPage: 1,
        pageFrequencyMap: const {},
        relatedConcepts: const [],
        matches: const [],
      );
    }

    final targetStem = extractConceptStem(cleanQuery);
    final searchPrefix = targetStem.length >= 4 ? targetStem : cleanQuery.toLowerCase();

    final matches = <ConcordanceMatch>[];
    final pageCounts = <int, int>{};
    final coOccurringFreq = <String, int>{};
    int totalCount = 0;

    final sortedPages = pageTexts.keys.toList()..sort();

    for (final pageNum in sortedPages) {
      final rawPage = pageTexts[pageNum] ?? '';
      if (rawPage.trim().isEmpty) continue;

      final sentences = rawPage
          .split(RegExp(r'(?<=[.!?…])\s+|\n+'))
          .map((s) => s.trim())
          .where((s) => s.length >= 12)
          .toList();

      int pageMatchCount = 0;

      for (final sentence in sentences) {
        final words = sentence.split(RegExp(r'\s+'));
        String? matchedSurfaceWord;
        int sentenceHits = 0;

        for (final w in words) {
          final wClean = w
              .replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '')
              .toLowerCase();
          if (wClean.isEmpty) continue;
          final wStem = extractConceptStem(wClean);
          if (wClean.startsWith(searchPrefix) ||
              (searchPrefix.length >= 4 && wStem == searchPrefix)) {
            sentenceHits++;
            matchedSurfaceWord ??= w.replaceAll(
              RegExp(r'^[^\p{L}\p{N}]+|[^\p{L}\p{N}]+$', unicode: true),
              '',
            );
          }
        }

        if (sentenceHits > 0 && matchedSurfaceWord != null) {
          pageMatchCount += sentenceHits;
          totalCount += sentenceHits;

          if (matches.length < 30) {
            matches.add(
              ConcordanceMatch(
                pageNumber: pageNum,
                snippet: sentence,
                matchedTerm: matchedSurfaceWord,
              ),
            );
          }

          // Aynı cümlede geçen ilişkili kavramları topla
          for (final w in words) {
            final cleanCo = w
                .replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '')
                .toLowerCase();
            if (cleanCo.length >= 4 &&
                !_stopWords.contains(cleanCo) &&
                !cleanCo.startsWith(searchPrefix) &&
                extractConceptStem(cleanCo) != searchPrefix) {
              coOccurringFreq[cleanCo] = (coOccurringFreq[cleanCo] ?? 0) + 1;
            }
          }
        }
      }

      if (pageMatchCount > 0) {
        pageCounts[pageNum] = pageMatchCount;
      }
    }

    int firstSeen = sortedPages.isNotEmpty ? sortedPages.first : 1;
    int peakPage = firstSeen;
    int maxCount = 0;

    if (pageCounts.isNotEmpty) {
      final matchedPages = pageCounts.keys.toList()..sort();
      firstSeen = matchedPages.first;
      for (final entry in pageCounts.entries) {
        if (entry.value > maxCount) {
          maxCount = entry.value;
          peakPage = entry.key;
        }
      }
    }

    final sortedRelated = coOccurringFreq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final relatedConcepts = sortedRelated
        .take(6)
        .map((e) => e.key[0].toUpperCase() + e.key.substring(1))
        .toList();

    return ConceptRadarResult(
      queryConcept: cleanQuery,
      stemUsed: searchPrefix,
      totalOccurrences: totalCount,
      firstSeenPage: firstSeen,
      peakPage: peakPage,
      pageFrequencyMap: pageCounts,
      relatedConcepts: relatedConcepts,
      matches: matches,
    );
  }
}

class ConcordanceMatch {
  final int pageNumber;
  final String snippet;
  final String matchedTerm;

  const ConcordanceMatch({
    required this.pageNumber,
    required this.snippet,
    required this.matchedTerm,
  });
}

class ConceptRadarResult {
  final String queryConcept;
  final String stemUsed;
  final int totalOccurrences;
  final int firstSeenPage;
  final int peakPage;
  final Map<int, int> pageFrequencyMap;
  final List<String> relatedConcepts;
  final List<ConcordanceMatch> matches;

  const ConceptRadarResult({
    required this.queryConcept,
    required this.stemUsed,
    required this.totalOccurrences,
    required this.firstSeenPage,
    required this.peakPage,
    required this.pageFrequencyMap,
    required this.relatedConcepts,
    required this.matches,
  });
}

