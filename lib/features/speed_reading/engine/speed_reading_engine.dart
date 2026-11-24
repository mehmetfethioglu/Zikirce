import 'dart:math';
import '../domain/speed_reading_models.dart';

/// ORP (Optimal Recognition Point) kelime bölünmüş gösterim verisi
class OrpWordParts {
  final String leftPart;
  final String pivotChar;
  final String rightPart;
  final int pivotIndex;

  const OrpWordParts({
    required this.leftPart,
    required this.pivotChar,
    required this.rightPart,
    required this.pivotIndex,
  });
}

/// Takistoskop (Flaş Algı) tur verisi
class TachistoscopeRound {
  final String targetText;
  final List<String> options;
  final int correctOptionIndex;

  const TachistoscopeRound({
    required this.targetText,
    required this.options,
    required this.correctOptionIndex,
  });
}

/// Superead Pro tarzı hızlı okuma algoritmik motoru (Saf fonksiyonlar, 0ms gecikme)
class SpeedReadingEngine {
  const SpeedReadingEngine._();

  static final Random _random = Random.secure();

  /// Türkçe eklemeli kelimelere duyarlı Optimal Recognition Point (ORP) harf indeksi
  /// 1-3 harf -> 0, 4-5 harf -> 1, 6-9 harf -> 2, 10-13 harf -> 3, 14+ harf -> 4
  static int computeOrpIndex(String token) {
    final trimmed = token.trim();
    if (trimmed.isEmpty) return 0;

    // Baştaki noktalama işaretlerini atla
    int leadingPunct = 0;
    while (leadingPunct < trimmed.length &&
        _isPunctuation(trimmed.codeUnitAt(leadingPunct))) {
      leadingPunct++;
    }

    // Sondaki noktalama işaretlerini atla
    int trailingPunct = 0;
    while (trailingPunct < (trimmed.length - leadingPunct) &&
        _isPunctuation(
            trimmed.codeUnitAt(trimmed.length - 1 - trailingPunct))) {
      trailingPunct++;
    }

    final coreLength = trimmed.length - leadingPunct - trailingPunct;
    if (coreLength <= 1) return leadingPunct.clamp(0, trimmed.length - 1);

    final int coreOffset;
    if (coreLength <= 3) {
      coreOffset = 0;
    } else if (coreLength <= 5) {
      coreOffset = 1;
    } else if (coreLength <= 9) {
      coreOffset = 2;
    } else if (coreLength <= 13) {
      coreOffset = 3;
    } else {
      coreOffset = 4;
    }

    return (leadingPunct + coreOffset).clamp(0, trimmed.length - 1);
  }

  /// Kelime veya kelime grubunu Sol + Kırmızı ORP Harfi + Sağ olarak böler
  static OrpWordParts splitForOrp(String chunk) {
    final clean = chunk.trim();
    if (clean.isEmpty) {
      return const OrpWordParts(
        leftPart: '',
        pivotChar: '',
        rightPart: '',
        pivotIndex: 0,
      );
    }

    final int pivot;
    if (clean.contains(' ')) {
      final target = (clean.length * 0.36).floor().clamp(0, clean.length - 1);
      if (clean[target] == ' ' && target + 1 < clean.length) {
        pivot = target + 1;
      } else {
        pivot = target;
      }
    } else {
      pivot = computeOrpIndex(clean);
    }

    return OrpWordParts(
      leftPart: clean.substring(0, pivot),
      pivotChar: clean.substring(pivot, pivot + 1),
      rightPart: clean.substring(pivot + 1),
      pivotIndex: pivot,
    );
  }

  /// RSVP ve Pacer için noktalama ve kelime uzunluğuna duyarlı dinamik milisaniye hesabı
  static int calculateChunkDelayMs({
    required String chunk,
    required int targetWpm,
    required int wordsInChunk,
  }) {
    final safeWpm = targetWpm.clamp(60, 1500);
    final baseMsPerWord = 60000.0 / safeWpm;
    double durationMs = baseMsPerWord * wordsInChunk.clamp(1, 6);

    final trimmed = chunk.trim();
    if (trimmed.isEmpty) return durationMs.round().clamp(35, 3000);

    final lastChar = trimmed[trimmed.length - 1];
    if (lastChar == '.' ||
        lastChar == '!' ||
        lastChar == '?' ||
        lastChar == '…') {
      durationMs *= 2.1;
    } else if (lastChar == ',' ||
        lastChar == ';' ||
        lastChar == ':' ||
        lastChar == '—') {
      durationMs *= 1.45;
    }

    if (trimmed.length >= 11 && !trimmed.contains(' ')) {
      durationMs *= 1.25;
    } else if (trimmed.length >= 22 && trimmed.contains(' ')) {
      durationMs *= 1.15;
    }

    return durationMs.round().clamp(35, 3500);
  }

  /// 2x Aşırı Hız Sprinti (Otoyol Adaptasyonu) için 4 fazlı dinamik WPM ve faz bilgisi
  static ({int activeWpm, int phaseNumber, String phaseTitle, double multiplier})
      calculateOverSpeedPhase({
    required int baseWpm,
    required double progressRatio,
  }) {
    final safeBase = baseWpm.clamp(120, 900);
    final p = progressRatio.clamp(0.0, 1.0);

    if (p < 0.25) {
      return (
        activeWpm: safeBase,
        phaseNumber: 1,
        phaseTitle: 'Faz 1/4 • Baz Hız Kalibrasyonu (1.0x)',
        multiplier: 1.0,
      );
    } else if (p < 0.55) {
      final wpm = (safeBase * 1.5).round().clamp(150, 1400);
      return (
        activeWpm: wpm,
        phaseNumber: 2,
        phaseTitle: 'Faz 2/4 • Turbo Sprint: İçses Kırıcı (1.5x)',
        multiplier: 1.5,
      );
    } else if (p < 0.78) {
      final wpm = (safeBase * 2.0).round().clamp(200, 1600);
      return (
        activeWpm: wpm,
        phaseNumber: 3,
        phaseTitle: 'Faz 3/4 • Hiper-Sprint: Görsel Korteks (2.0x)',
        multiplier: 2.0,
      );
    } else {
      final wpm = (safeBase * 1.35).round().clamp(140, 1200);
      return (
        activeWpm: wpm,
        phaseNumber: 4,
        phaseTitle: 'Faz 4/4 • Yeni Konfor Hızı Sabitleme (1.35x)',
        multiplier: 1.35,
      );
    }
  }

  /// Çevresel Görüş Piramidi (Peripheral Span Pyramid) için genişleyen kelime kanatları üretir
  static List<PyramidSpanRow> generatePyramidSpanRows(
    String text, {
    int maxRows = 24,
  }) {
    final safeMax = maxRows.clamp(6, 60);
    final words = text
        .replaceAll('\r\n', ' ')
        .replaceAll('\n', ' ')
        .split(RegExp(r'\s+'))
        .map((w) => w.trim())
        .where((w) => w.length >= 2)
        .take(240)
        .toList();

    if (words.length < 4) {
      return const [
        PyramidSpanRow(
          leftWord: 'Zihnî',
          centerAnchor: '•',
          rightWord: 'Berraklık',
          horizontalGap: 24,
        ),
        PyramidSpanRow(
          leftWord: 'Çevresel',
          centerAnchor: '•',
          rightWord: 'Görüş',
          horizontalGap: 52,
        ),
        PyramidSpanRow(
          leftWord: 'Süratli',
          centerAnchor: '•',
          rightWord: 'Mütalaa',
          horizontalGap: 84,
        ),
      ];
    }

    final rows = <PyramidSpanRow>[];
    int wordIdx = 0;
    for (int r = 0; r < safeMax; r++) {
      final left = words[wordIdx % words.length];
      final right = words[(wordIdx + 1) % words.length];
      wordIdx += 2;

      final stepInWave = r % 8;
      final gap = (18.0 + (stepInWave * 14.0)).clamp(18.0, 120.0);

      rows.add(
        PyramidSpanRow(
          leftWord: left,
          centerAnchor: '${r + 1}',
          rightWord: right,
          horizontalGap: gap,
        ),
      );
    }

    return rows;
  }

  /// Metni 1'li, 2'li, 3'lü veya 4'lü anlamlı kelime bloklarına (chunk) ayırır.
  static List<String> tokenizeIntoChunks(String text, {int chunkSize = 1}) {
    final size = chunkSize.clamp(1, 5);
    final rawWords = text
        .replaceAll('\r\n', ' ')
        .replaceAll('\n', ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.trim().isNotEmpty)
        .take(1200)
        .toList();

    if (rawWords.isEmpty) return const [];
    if (size == 1) return rawWords.take(600).toList();

    final chunks = <String>[];
    final buffer = <String>[];

    for (final word in rawWords) {
      buffer.add(word);
      final endsSentence = word.endsWith('.') ||
          word.endsWith('!') ||
          word.endsWith('?') ||
          word.endsWith(':') ||
          word.endsWith(';');

      if (buffer.length >= size || endsSentence) {
        chunks.add(buffer.join(' '));
        buffer.clear();
        if (chunks.length >= 600) break;
      }
    }

    if (buffer.isNotEmpty && chunks.length < 600) {
      chunks.add(buffer.join(' '));
    }

    return chunks;
  }

  /// Schulte Tablosu için sıralı hedef listesi ve karıştırılmış hücre listesi üretir
  static ({List<String> orderedTargets, List<String> shuffledGrid})
      generateSchulteGrid({
    required int dimension,
    required bool useLetters,
  }) {
    final d = dimension.clamp(3, 6);
    final count = d * d;

    const turkishAlphabet = [
      'A', 'B', 'C', 'Ç', 'D', 'E', 'F', 'G', 'Ğ', 'H',
      'I', 'İ', 'J', 'K', 'L', 'M', 'N', 'O', 'Ö', 'P',
      'R', 'S', 'Ş', 'T', 'U', 'Ü', 'V', 'Y', 'Z',
      '1', '2', '3', '4', '5', '6', '7',
    ];

    final List<String> ordered;
    if (useLetters) {
      ordered = List<String>.generate(
        count,
        (i) => turkishAlphabet[i % turkishAlphabet.length],
      );
    } else {
      ordered = List<String>.generate(count, (i) => '${i + 1}');
    }

    final shuffled = List<String>.from(ordered)..shuffle(_random);
    return (orderedTargets: ordered, shuffledGrid: shuffled);
  }

  /// Takistoskop egzersizi için aktif metinden canlı veya zengin havuzdan kelime/öbek ve 3 yakın görsel çeldirici üretir
  static TachistoscopeRound generateTachistoscopeRound({
    required int wordSpan,
    String? sourceText,
  }) {
    final span = wordSpan.clamp(1, 3);

    // Eğer aktif metin (kitap sayfası veya dinamik metin) varsa ondan canlı öbek üret
    if (sourceText != null && sourceText.trim().length > 40) {
      final boundedSource = sourceText.length > 3500
          ? sourceText.substring(0, 3500)
          : sourceText;
      final cleanWords = boundedSource
          .replaceAll(RegExp(r'[^\w\sçğıöşüÇĞİÖŞÜâîûÂÎÛ]'), ' ')
          .split(RegExp(r'\s+'))
          .map((w) => w.trim())
          .where((w) => w.length >= 4)
          .take(160)
          .toList();

      if (cleanWords.length >= span + 8) {
        final startIdx = _random.nextInt(cleanWords.length - span);
        final targetWords = cleanWords.sublist(startIdx, startIdx + span);
        final target = targetWords.join(' ');
        final distractors = <String>{};

        int attempts = 0;
        while (distractors.length < 3 && attempts < 18) {
          attempts++;
          final altStart = _random.nextInt(cleanWords.length - span);
          final altPhrase =
              cleanWords.sublist(altStart, altStart + span).join(' ');
          if (altPhrase != target) {
            distractors.add(altPhrase);
          }
        }

        if (distractors.length == 3) {
          final options = [target, ...distractors]..shuffle(_random);
          return TachistoscopeRound(
            targetText: target,
            options: options,
            correctOptionIndex: options.indexOf(target).clamp(0, 3),
          );
        }
      }
    }

    final pool = switch (span) {
      1 => _singleWordPool,
      2 => _twoWordPool,
      _ => _threeWordPool,
    };

    final group = pool[_random.nextInt(pool.length)];
    final target = group.first;
    final options = List<String>.from(group)..shuffle(_random);
    final correctIdx = options.indexOf(target);

    return TachistoscopeRound(
      targetText: target,
      options: options,
      correctOptionIndex: correctIdx >= 0 ? correctIdx : 0,
    );
  }

  /// Gerçek kitap paragraflarını karakter offsetleriyle anlam öbeklerine (2–4 kelime) böler
  static List<SemanticChunkSpan> buildParagraphSemanticChunks({
    required List<(int, String)> paragraphs,
    int preferredChunkWords = 3,
  }) {
    final safeChunkSize = preferredChunkWords.clamp(2, 4);
    final tokenRegex = RegExp(r'\S+');
    final spans = <SemanticChunkSpan>[];

    for (final (paragraphIndex, rawText) in paragraphs) {
      if (rawText.trim().isEmpty) continue;
      final matches = tokenRegex.allMatches(rawText).toList();
      if (matches.isEmpty) continue;

      int idx = 0;
      while (idx < matches.length) {
        final startMatch = matches[idx];
        int endIdx = idx;
        int wordsInSpan = 1;

        while (endIdx + 1 < matches.length && wordsInSpan < safeChunkSize) {
          final currentToken = matches[endIdx].group(0)!;
          if (_endsWithNaturalPause(currentToken) ||
              currentToken.length >= 13) {
            break;
          }
          endIdx++;
          wordsInSpan++;
        }

        final endMatch = matches[endIdx];
        final chunkText = rawText.substring(startMatch.start, endMatch.end);
        spans.add(
          SemanticChunkSpan(
            paragraphIndex: paragraphIndex,
            startOffset: startMatch.start,
            endOffset: endMatch.end,
            text: chunkText,
            wordCount: wordsInSpan,
          ),
        );
        idx = endIdx + 1;
      }
    }

    return spans;
  }

  /// Yaklaşan kitap sayfalarından 60 saniyelik kitaba özel ısınma paketi üretir
  static WarmupLexicalPack buildWarmupLexicalPack({
    required String title,
    required String author,
    required int targetPage,
    required String rawUpcomingText,
    required List<String> extractedConcepts,
    required String complexityLabel,
    required bool isFromUserBook,
    int suggestedWpm = 260,
  }) {
    final densityTier = TextDensityTier.fromComplexityLabel(complexityLabel);
    final trimmedRaw = rawUpcomingText.replaceAll(RegExp(r'\s+'), ' ').trim();
    final safeText = trimmedRaw.length >= 24
        ? (trimmedRaw.length > 3500
            ? trimmedRaw.substring(0, 3500)
            : trimmedRaw)
        : 'Okumak, zihnin sonsuz vadilerinde yapılan en zarif seyahattir; gözlerin satırlar üzerinde zahmetsizce akması berrak bir idrak sağlar.';

    final cleanConcepts = extractedConcepts
        .map((c) => c.trim())
        .where((c) => c.length >= 3)
        .take(4)
        .toList();

    if (cleanConcepts.isEmpty) {
      final words = safeText
          .replaceAll(RegExp(r'[^\w\sçğıöşüÇĞİÖŞÜâîûÂÎÛ]'), ' ')
          .split(RegExp(r'\s+'))
          .map((w) => w.trim())
          .where((w) => w.length >= 5)
          .toSet()
          .take(4)
          .toList();
      cleanConcepts.addAll(words.isNotEmpty ? words : const ['Mütalaa', 'Hikmet', 'Nazar']);
    }

    final pyramidRows = generatePyramidSpanRows(safeText, maxRows: 10);
    final overdriveChunks =
        tokenizeIntoChunks(safeText, chunkSize: 2).take(32).toList();

    return WarmupLexicalPack(
      sourceTitle: title,
      sourceAuthor: author,
      targetPage: targetPage < 1 ? 1 : targetPage,
      densityTier: densityTier,
      keyConcepts: List<String>.unmodifiable(cleanConcepts),
      pyramidRows: List<PyramidSpanRow>.unmodifiable(pyramidRows),
      overdriveChunks: List<String>.unmodifiable(overdriveChunks),
      isFromUserBook: isFromUserBook,
      rawExcerptText: safeText,
      suggestedWpm: suggestedWpm.clamp(120, 800),
    );
  }

  static bool _endsWithNaturalPause(String token) {
    final trimmed = token.trimRight();
    if (trimmed.isEmpty) return false;
    const pauseChars = ',.;:!?…—';
    final last = trimmed[trimmed.length - 1];
    if (pauseChars.contains(last)) return true;
    if (trimmed.length >= 2 &&
        (last == '"' || last == '”' || last == '\'' || last == ')')) {
      return pauseChars.contains(trimmed[trimmed.length - 2]);
    }
    return false;
  }

  /// Kullanıcının kendi kitabından alınan kesit için yalnızca metin içi gerçek cümle ve kavramlarla soru üretir
  static List<ComprehensionQuestion> generateQuestionsFromBookExcerpt({
    required String bookTitle,
    required String excerptText,
  }) {
    final boundedExcerpt = excerptText.length > 3500
        ? excerptText.substring(0, 3500)
        : excerptText;
    final sentences = boundedExcerpt
        .split(RegExp(r'(?<=[.!?…])\s+'))
        .map((s) => s.trim())
        .where((s) => s.length >= 18)
        .toList();

    final words = boundedExcerpt
        .replaceAll(RegExp(r'[^\w\sçğıöşüÇĞİÖŞÜâîûÂÎÛ]'), ' ')
        .split(RegExp(r'\s+'))
        .map((w) => w.trim())
        .where((w) => w.length >= 5)
        .toSet()
        .toList();

    final keyTerm = words.isNotEmpty ? words.first : 'Mütalaa';
    final midTerm = words.length > 2 ? words[words.length ~/ 2] : 'Kavrayış';

    String clipSentence(String raw) =>
        raw.length > 72 ? '${raw.substring(0, 70)}…' : raw;

    final firstSentenceSnippet = sentences.isNotEmpty
        ? clipSentence(sentences.first)
        : 'Metnin girişindeki temel önerme';

    final q1Distractors = <String>[];
    for (final s in sentences.skip(1)) {
      final clipped = clipSentence(s);
      if (clipped != firstSentenceSnippet && !q1Distractors.contains(clipped)) {
        q1Distractors.add(clipped);
      }
      if (q1Distractors.length == 3) break;
    }
    const literarySentenceFallbacks = [
      'Göz kaslarının satır sonunda gereksiz duraksamayı terk etmesi',
      'Klasik metinlerde kenar notlarının okuma düzenini desteklemesi',
      'Cümlelerin bütüncül anlam öbekleri halinde zihne aktarılması',
    ];
    for (final fb in literarySentenceFallbacks) {
      if (q1Distractors.length == 3) break;
      if (fb != firstSentenceSnippet && !q1Distractors.contains(fb)) {
        q1Distractors.add(fb);
      }
    }

    final excerptLower = boundedExcerpt.toLowerCase();
    final q2Distractors = <String>[];
    for (final group in _singleWordPool) {
      for (final candidate in group) {
        if (q2Distractors.length == 3) break;
        if (candidate.toLowerCase() != keyTerm.toLowerCase() &&
            !excerptLower.contains(candidate.toLowerCase()) &&
            !q2Distractors.contains(candidate)) {
          q2Distractors.add(candidate);
        }
      }
      if (q2Distractors.length == 3) break;
    }
    const wordFallbacks = ['Belağat', 'Nasihatname', 'Muvakkithane'];
    for (final fb in wordFallbacks) {
      if (q2Distractors.length == 3) break;
      if (!q2Distractors.contains(fb) &&
          fb.toLowerCase() != keyTerm.toLowerCase()) {
        q2Distractors.add(fb);
      }
    }

    final q3Distractors = <String>[
      'Yalnızca sayfa kenarındaki süsleme motiflerinin biçimsel tarifi içinde',
      'Bir sözlük dizinindeki alfabetik madde sıralaması bağlamında',
      'Teknik bir imla kılavuzunun noktalama kuralları cetveli içinde',
    ];

    return [
      ComprehensionQuestion(
        question:
            'Okuduğunuz "$bookTitle" kesitinin girişinde vurgulanan temel ifade hangisidir?',
        options: [
          firstSentenceSnippet,
          ...q1Distractors.take(3),
        ],
        correctIndex: 0,
      ),
      ComprehensionQuestion(
        question:
            'Metin akışında aşağıdaki kavram veya kelimelerden hangisi doğrudan yer almıştır?',
        options: [
          q2Distractors[0],
          keyTerm,
          q2Distractors[1],
          q2Distractors[2],
        ],
        correctIndex: 1,
      ),
      ComprehensionQuestion(
        question:
            'Metnin bütünlüğünde "$midTerm" kavramı hangi bağlamda işlenmiştir?',
        options: [
          '$bookTitle eserinin konu bütünlüğü ve ana fikri içinde',
          ...q3Distractors,
        ],
        correctIndex: 0,
      ),
    ];
  }

  /// Ham WPM ve Etkili WPM (E-WPM) hesaplayıcı
  static ({int rawWpm, int effectiveWpm}) calculateWpmMetrics({
    required int wordCount,
    required double elapsedSeconds,
    required int comprehensionPercent,
  }) {
    final safeSeconds = elapsedSeconds < 1.0 ? 1.0 : elapsedSeconds;
    final rawWpm = ((wordCount / safeSeconds) * 60.0).round().clamp(30, 2000);
    final comp = comprehensionPercent.clamp(0, 100);
    final effectiveWpm = ((rawWpm * comp) / 100.0).round();
    return (rawWpm: rawWpm, effectiveWpm: effectiveWpm);
  }

  static bool _isPunctuation(int codeUnit) {
    const punct = '.,!?;:"\'()[]{}«»“”—–-…';
    for (int i = 0; i < punct.length; i++) {
      if (punct.codeUnitAt(i) == codeUnit) return true;
    }
    return false;
  }

  static const List<List<String>> _singleWordPool = [
    ['Mütalaa', 'Mübalağa', 'Mukabele', 'Muhakeme'],
    ['Fesahat', 'Feraset', 'Ferahlık', 'Feragat'],
    ['Basiret', 'Belağat', 'Bidayet', 'Bereket'],
    ['Tefekkür', 'Tezekkür', 'Teşekkür', 'Tevekkül'],
    ['İstikamet', 'İstihbarat', 'İstikbal', 'İstikrar'],
    ['Mukaddime', 'Mukayese', 'Mukavemet', 'Muamele'],
    ['Kütüphane', 'Kıraathane', 'Rasathane', 'Dershane'],
    ['Hakikat', 'Hareket', 'Hararet', 'Maharet'],
    ['Medeniyet', 'Meziyet', 'Mesuliyet', 'Memleket'],
    ['Muvazene', 'Müzakere', 'Mücadele', 'Müşahede'],
    ['Rasathane', 'Kütüphane', 'Darüşşifa', 'Muvakkithane'],
    ['Mükemmeliyet', 'Mesuliyet', 'Mahremiyet', 'Meşruiyet'],
    ['Tezahür', 'Tahayyül', 'Tasavvur', 'Tasarruf'],
    ['Keşifname', 'Seyahatname', 'Siyasetname', 'Nasihatname'],
  ];

  static const List<List<String>> _twoWordPool = [
    ['Derin Tefekkür', 'Derin Tezekkür', 'Doğru Tefekkür', 'Derin Tasavvur'],
    ['Çevresel Görüş', 'Çevresel Algı', 'Merkezî Görüş', 'Bütüncül Görüş'],
    ['Sahife Düzeni', 'Satır Düzeni', 'Sahife Akışı', 'Metin Düzeni'],
    ['Zihnî Odaklanma', 'Zihnî Berraklık', 'Görsel Odaklanma', 'Anlık Odaklanma'],
    ['Kadim Hikmet', 'Kadim Miras', 'Kâmil Hikmet', 'Kadim Marifet'],
    ['Süratli Kıraat', 'Sürekli Kıraat', 'Süratli İdrak', 'Selis Kıraat'],
    ['Bilişsel Sentez', 'Bilişsel Hafıza', 'Bütüncül Sentez', 'Kavramsal Sentez'],
    ['Nazarî İlimler', 'Amelî İlimler', 'Nazarî Hikmet', 'Naklî İlimler'],
    ['Optik Kırılma', 'Optik Yansıma', 'Mercek Kırılması', 'Işık Kırılması'],
    ['Deniz Haritası', 'Yıldız Haritası', 'İklim Haritası', 'Rüzgâr Haritası'],
    ['Akustik Kubbe', 'Estetik Kubbe', 'Merkezî Kubbe', 'Kemerli Kubbe'],
    ['Zaman Ölçümü', 'Mekân Ölçümü', 'Yıldız Ölçümü', 'Uzaklık Ölçümü'],
  ];

  static const List<List<String>> _threeWordPool = [
    [
      'Göz Sıçramasını Azalt',
      'Göz Yorgunluğunu Azalt',
      'Göz Odaklanmasını Artır',
      'Söz Tekrarını Azalt',
    ],
    [
      'Kelime Öbeklerini Yakala',
      'Kelime Köklerini Yakala',
      'Cümle Öbeklerini Yakala',
      'Kelime Öbeklerini Hizala',
    ],
    [
      'İçsesi Sessizce Sustur',
      'İçsesi Hızlıca Sustur',
      'Zihni Sessizce Odakla',
      'İçsesi Tamamen Durdur',
    ],
    [
      'Merkez Noktaya Odaklan',
      'Merkez Satıra Odaklan',
      'Hedef Noktaya Odaklan',
      'Merkez Noktayı Takip Et',
    ],
    [
      'Anlamı Bütüncül Kavra',
      'Metni Bütüncül Kavra',
      'Anlamı Anında Kavra',
      'Kavramı Bütüncül Çözümle',
    ],
    [
      'Geriye Dönmeden Oku',
      'Duraksama Yapmadan Oku',
      'Geriye Bakmadan İlerle',
      'Satırı Atlamadan Oku',
    ],
    [
      'Kanatları Aynı Anda Gör',
      'Satırları Aynı Anda Gör',
      'Kelimeleri Aynı Anda Gör',
      'Kenarları Aynı Anda Gör',
    ],
    [
      'Ritmi Bozmamaya Dikkat Et',
      'Odağı Bozmamaya Dikkat Et',
      'Hızı Düşürmemeye Dikkat Et',
      'Seriyi Bozmamaya Dikkat Et',
    ],
  ];
}
