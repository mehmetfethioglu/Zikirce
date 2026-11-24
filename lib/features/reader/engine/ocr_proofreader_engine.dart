import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../marginalia/services/dictionary_service.dart';
import '../domain/content_block.dart';
import 'ocr_candidate_generator.dart';
import 'ocr_lexicon_database.dart';
import 'ocr_local_ai_language_model.dart';
import 'ocr_text_healer.dart';
import 'turkish_morphology.dart';

/// OCR sonrası otomatik düzeltilen bir kelimenin izleme kaydı (Word "Değişiklikleri İzle / Otomatik Düzelt" modeli)
@immutable
class OcrCorrectionItem {
  final String id;
  final String originalWord;
  final String correctedWord;
  final String contextSnippet;
  final int blockIndex;
  final String ruleCategory;
  final double confidence;

  const OcrCorrectionItem({
    required this.id,
    required this.originalWord,
    required this.correctedWord,
    required this.contextSnippet,
    required this.blockIndex,
    required this.ruleCategory,
    this.confidence = 0.95,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'originalWord': originalWord,
        'correctedWord': correctedWord,
        'contextSnippet': contextSnippet,
        'blockIndex': blockIndex,
        'ruleCategory': ruleCategory,
        'confidence': confidence,
      };

  factory OcrCorrectionItem.fromJson(Map<String, dynamic> map) {
    return OcrCorrectionItem(
      id: map['id'] as String? ?? '',
      originalWord: map['originalWord'] as String? ?? '',
      correctedWord: map['correctedWord'] as String? ?? '',
      contextSnippet: map['contextSnippet'] as String? ?? '',
      blockIndex: map['blockIndex'] as int? ?? 0,
      ruleCategory: map['ruleCategory'] as String? ?? 'Otomatik Tashih',
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.95,
    );
  }
}

/// OCR sonrası inceleme bekleyen şüpheli kelime ve önerilen düzeltmeler (Word "Gözden Geçir / Yazım Denetimi" modeli)
@immutable
class OcrSuggestionItem {
  final String id;
  final String suspiciousWord;
  final List<String> suggestions;
  final String contextSnippet;
  final int blockIndex;
  final String issueDescription;

  const OcrSuggestionItem({
    required this.id,
    required this.suspiciousWord,
    required this.suggestions,
    required this.contextSnippet,
    required this.blockIndex,
    required this.issueDescription,
  });
}

/// Sayfa bazlı OCR Gözden Geçirme ve Otomatik Tashih Raporu
@immutable
class OcrPageReviewReport {
  final List<OcrCorrectionItem> autoCorrections;
  final List<OcrSuggestionItem> suggestions;
  final int totalWordsScanned;

  const OcrPageReviewReport({
    this.autoCorrections = const [],
    this.suggestions = const [],
    this.totalWordsScanned = 0,
  });

  const OcrPageReviewReport.empty()
      : autoCorrections = const [],
        suggestions = const [],
        totalWordsScanned = 0;

  int get autoCorrectedCount => autoCorrections.length;
  int get suggestionCount => suggestions.length;
  bool get hasAnyActivity => autoCorrections.isNotEmpty || suggestions.isNotEmpty;

  /// Sayfanın tahmini metin berraklığı / doğruluk yüzdesi (0.0 - 100.0)
  double get pageAccuracyPercent {
    if (totalWordsScanned <= 0) return 100.0;
    final remainingIssues = suggestions.length;
    final ratio = ((totalWordsScanned - remainingIssues) / totalWordsScanned) * 100.0;
    return ratio.clamp(75.0, 100.0);
  }

  OcrPageReviewReport copyWith({
    List<OcrCorrectionItem>? autoCorrections,
    List<OcrSuggestionItem>? suggestions,
    int? totalWordsScanned,
  }) {
    return OcrPageReviewReport(
      autoCorrections: autoCorrections ?? this.autoCorrections,
      suggestions: suggestions ?? this.suggestions,
      totalWordsScanned: totalWordsScanned ?? this.totalWordsScanned,
    );
  }
}

/// Blok listesi üzerinde yapılan otomatik tashih sonucu
@immutable
class OcrProofreadBlockResult {
  final List<ContentBlock> blocks;
  final OcrPageReviewReport report;
  final bool didModifyBlocks;

  const OcrProofreadBlockResult({
    required this.blocks,
    required this.report,
    this.didModifyBlocks = false,
  });
}

/// Microsoft Word "Gözden Geçir & Otomatik Düzelt" (Proofing & AutoCorrect) Mimarisine Sahip
/// Çevrimdışı Türkçe/Osmanlıca OCR Tashih ve Kelime Onarım Motoru.
class OcrProofreaderEngine {
  const OcrProofreaderEngine._();

  static const String _prefsAutoCorrectKey = 'tahrir_ocr_autocorrect_rules_v1';
  static const String _prefsIgnoredWordsKey = 'tahrir_ocr_ignored_words_v1';

  /// Kullanıcı tarafından eklenen kalıcı "Hatalı -> Doğru" otomatik düzeltme kuralları
  static final Map<String, String> _userAutoCorrectRules = {};

  /// Kullanıcının "Yoksay / Sözlüğe Ekle" dediği kelimeler
  static final Set<String> _ignoredWords = {};

  static bool _isInitialized = false;

  /// Yerleşik yüksek frekanslı Türkçe + Klasik Eser kelime ve kök hazinesi
  static Set<String>? _cachedLexicon;

  /// Kullanıcı kurallarını ve sözlüğünü SharedPreferences'tan yükler
  static Future<void> ensureInitialized() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final rulesJson = prefs.getString(_prefsAutoCorrectKey);
      if (rulesJson != null && rulesJson.isNotEmpty) {
        final decoded = jsonDecode(rulesJson) as Map<String, dynamic>;
        _userAutoCorrectRules.clear();
        for (final entry in decoded.entries) {
          _userAutoCorrectRules[_toTurkishLower(entry.key)] = entry.value.toString();
        }
      }
      final ignoredList = prefs.getStringList(_prefsIgnoredWordsKey);
      if (ignoredList != null) {
        _ignoredWords
          ..clear()
          ..addAll(ignoredList.map(_toTurkishLower));
        TurkishMorphology.registerExtraWords(_ignoredWords);
      }
      _getLexicon();
      _isInitialized = true;
    } catch (e) {
      debugPrint('OcrProofreaderEngine init warning: $e');
      _isInitialized = true;
    }
  }

  /// Türkçe büyük/küçük harf dönüşümünün tek kaynağı (SSOT).
  static String toTurkishLower(String input) => _toTurkishLower(input);

  /// Mevcut kullanıcı otomatik düzeltme kurallarını döndürür
  static Map<String, String> get userAutoCorrectRules =>
      Map.unmodifiable(_userAutoCorrectRules);

  /// Mevcut yoksayılan kelimeleri döndürür
  static Set<String> get ignoredWords => Set.unmodifiable(_ignoredWords);

  /// Yeni bir otomatik düzeltme kuralı ekler ve kalıcı olarak kaydeder
  static Future<void> addAutoCorrectRule(String wrongWord, String correctWord) async {
    final cleanWrong = _stripOuterPunctuation(wrongWord.trim());
    final cleanCorrect = _stripOuterPunctuation(correctWord.trim());
    if (cleanWrong.isEmpty || cleanCorrect.isEmpty) return;

    _userAutoCorrectRules[_toTurkishLower(cleanWrong)] = cleanCorrect;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsAutoCorrectKey, jsonEncode(_userAutoCorrectRules));
    } catch (e) {
      debugPrint('OcrProofreaderEngine save rule warning: $e');
    }
  }

  /// Bir otomatik düzeltme kuralını siler
  static Future<void> removeAutoCorrectRule(String wrongWordKey) async {
    _userAutoCorrectRules.remove(_toTurkishLower(wrongWordKey));
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsAutoCorrectKey, jsonEncode(_userAutoCorrectRules));
    } catch (e) {
      debugPrint('OcrProofreaderEngine remove rule warning: $e');
    }
  }

  /// Kelimeyi yoksayılanlar / özel sözlük listesine ekler
  static Future<void> addIgnoredWord(String word) async {
    final clean = _toTurkishLower(_stripOuterPunctuation(word.trim()));
    if (clean.isEmpty) return;
    _ignoredWords.add(clean);
    TurkishMorphology.registerExtraWords([clean]);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefsIgnoredWordsKey, _ignoredWords.toList());
    } catch (e) {
      debugPrint('OcrProofreaderEngine save ignored warning: $e');
    }
  }

  /// Yoksayılan / özel sözlüğe eklenen bir kelimeyi geri çıkarır
  static Future<void> removeIgnoredWord(String word) async {
    final clean = _toTurkishLower(_stripOuterPunctuation(word.trim()));
    if (clean.isEmpty) return;
    _ignoredWords.remove(clean);
    TurkishMorphology.unregisterExtraWord(clean);
    OcrCandidateGenerator.clearCache();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefsIgnoredWordsKey, _ignoredWords.toList());
    } catch (e) {
      debugPrint('OcrProofreaderEngine remove ignored warning: $e');
    }
  }

  /// ML Kit mikro-boşluk (micro-gap) analizinde iki `TextElement` parçasının
  /// birleştirilip birleştirilmeyeceğini doğrular.
  static bool shouldFuseMicroGapElements(String left, String right) {
    return OcrLocalAiLanguageModel.shouldFuseMicroGapElements(
      left,
      right,
      _getLexicon(),
    );
  }

  /// Sayfa içerik bloklarını (`List<ContentBlock>`) otomatik olarak gözden geçirir,
  /// yüksek güvenilirlikli OCR kelime hatalarını anında ilgili sayfada düzeltir ve
  /// Word tarzı Gözden Geçir raporunu (`OcrPageReviewReport`) üretir.
  static OcrProofreadBlockResult proofreadBlocks(
    List<ContentBlock> blocks, {
    String? unhealedRawText,
    List<OcrCorrectionItem> cachedAutoCorrections = const [],
    Map<String, double>? mlKitLowConfidenceWords,
  }) {
    final updatedBlocks = <ContentBlock>[];
    final autoCorrections = <OcrCorrectionItem>[...cachedAutoCorrections];
    final seenCorrectionKeys = <String>{
      for (final c in cachedAutoCorrections)
        '${c.blockIndex}:${_toTurkishLower(c.originalWord)}->${_toTurkishLower(c.correctedWord)}',
    };
    final suggestions = <OcrSuggestionItem>[];
    final seenSuggestionWords = <String>{};

    int totalWords = 0;
    bool didModify = false;

    final lexicon = _getLexicon();
    final workingBlocks = List<ContentBlock>.from(blocks);

    // -1. Ardışık gövde blokları arasında kalmış kırık tireli kelimeleri onar
    for (int i = 0; i < workingBlocks.length - 1; i++) {
      final b1 = workingBlocks[i];
      final b2 = workingBlocks[i + 1];
      if (b1 is TextBlock &&
          b2 is TextBlock &&
          !b1.isHeading &&
          !b1.isArabic &&
          !b2.isHeading &&
          !b2.isArabic) {
        final endMatch = RegExp(
          r'([a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]{2,})[-¬=]\s*$',
        ).firstMatch(b1.text);
        final startMatch = RegExp(
          r'^\s*([a-zçğıöşüâîû]{2,})(?![\p{L}])',
          unicode: true,
        ).firstMatch(b2.text);
        if (endMatch != null && startMatch != null) {
          final part1 = endMatch.group(1)!;
          final part2 = startMatch.group(1)!;
          final combined = '$part1$part2';
          if (_isValidKnownTurkishWord(_toTurkishLower(combined), lexicon)) {
            var b2Rest = b2.text.substring(startMatch.end);
            final punctMatch = RegExp(r'^([,\.!?:;]+)').firstMatch(b2Rest);
            final punct = punctMatch?.group(1) ?? '';
            if (punct.isNotEmpty) {
              b2Rest = b2Rest.substring(punct.length);
            }
            b2Rest = b2Rest.replaceFirst(RegExp(r'^[ \t]+'), '');
            final b1NewText =
                '${b1.text.substring(0, endMatch.start)}$combined$punct';
            workingBlocks[i] = b1.copyWith(text: b1NewText);
            workingBlocks[i + 1] = b2.copyWith(text: b2Rest);
            didModify = true;
            final key =
                '$i:${_toTurkishLower('$part1-$part2')}->${_toTurkishLower(combined)}';
            if (seenCorrectionKeys.add(key)) {
              autoCorrections.add(OcrCorrectionItem(
                id: 'cross_${i}_0',
                originalWord: '$part1- $part2',
                correctedWord: combined,
                contextSnippet: _extractContextSnippet(
                  b1NewText,
                  (b1NewText.length - combined.length - punct.length)
                      .clamp(0, b1NewText.length),
                  b1NewText.length,
                ),
                blockIndex: i,
                ruleCategory: 'Bloklar Arası Kırık Tire Onarımı',
                confidence: 0.96,
              ));
            }
          }
        }
      }
    }

    // Sayfa sözlüğü: aynı sayfada doğru yazılmış kelimeler aday sıralamasında öne alınır
    final pageVocabulary = <String, int>{};
    final vocabRegex = RegExp(r'[a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]{3,}', unicode: true);
    for (final b in workingBlocks) {
      if (b is! TextBlock || b.isArabic) continue;
      for (final vm in vocabRegex.allMatches(b.text)) {
        final w = _toTurkishLower(vm.group(0)!);
        if (TurkishMorphology.isKnownWord(w)) {
          pageVocabulary[w] = (pageVocabulary[w] ?? 0) + 1;
        }
      }
    }

    for (int blockIdx = 0; blockIdx < workingBlocks.length; blockIdx++) {
      final block = workingBlocks[blockIdx];
      if (block is! TextBlock || block.isArabic) {
        updatedBlocks.add(block);
        continue;
      }

      // 0. Önce Çoklu Kelime Bölünmelerini ve Osmanlıca Terkipleri onar ve raporla
      final originalBlockText = block.text;
      final preMultiWordPass = _repairMultiWordSplitsAndTerkips(
        text: originalBlockText,
        blockIndex: blockIdx,
      );
      if (preMultiWordPass.$1 != originalBlockText) {
        didModify = true;
        for (final corr in preMultiWordPass.$2) {
          final key =
              '$blockIdx:${_toTurkishLower(corr.originalWord)}->${_toTurkishLower(corr.correctedWord)}';
          if (seenCorrectionKeys.add(key)) {
            autoCorrections.add(corr);
          }
        }
      }

      // 1. Sonra OcrTextHealer + Kelime Bazlı Otomatik Tashih çalıştır
      final healedByBase = OcrTextHealer.heal(preMultiWordPass.$1);

      // Eğer OcrTextHealer seviyesinde değişen kelimeler varsa farklarını yakala
      if (healedByBase != preMultiWordPass.$1) {
        didModify = true;
        final baseDiffs = _extractWordDiffs(
          beforeText: preMultiWordPass.$1,
          afterText: healedByBase,
          blockIndex: blockIdx,
          ruleCategory: 'Morfolojik & Fonotaktik Onarım',
        );
        for (final diff in baseDiffs) {
          final key =
              '$blockIdx:${_toTurkishLower(diff.originalWord)}->${_toTurkishLower(diff.correctedWord)}';
          if (seenCorrectionKeys.add(key)) {
            autoCorrections.add(diff);
          }
        }
      }

      // 2. Kelime bazlı derin OCR tashih (Kullanıcı kuralları, rn->m, cl->d, ünsüz içi c->a/e, sözlük eşleştirme, Yerel AI N-Gram)
      final tokenPass = _proofreadParagraphTokens(
        text: healedByBase,
        blockIndex: blockIdx,
        mlKitLowConfidenceWords: mlKitLowConfidenceWords,
        pageVocabulary: pageVocabulary,
      );

      totalWords += tokenPass.wordCount;

      if (tokenPass.correctedText != healedByBase) {
        didModify = true;
      }

      for (final corr in tokenPass.autoCorrections) {
        final key =
            '$blockIdx:${_toTurkishLower(corr.originalWord)}->${_toTurkishLower(corr.correctedWord)}';
        if (seenCorrectionKeys.add(key)) {
          autoCorrections.add(corr);
        }
      }

      for (final sugg in tokenPass.suggestions) {
        final lowerSugg = _toTurkishLower(sugg.suspiciousWord);
        if (seenSuggestionWords.add(lowerSugg)) {
          suggestions.add(sugg);
        }
      }

      // 2b. Bloğa bağlı dipnot içeriklerini de aynı tashih hattından geçir
      var updatedAnchors = block.footnoteAnchors;
      if (block.footnoteAnchors.isNotEmpty) {
        final repairedAnchors = <FootnoteAnchor>[];
        for (final anchor in block.footnoteAnchors) {
          final content = anchor.content;
          if (content == null || content.trim().isEmpty) {
            repairedAnchors.add(FootnoteAnchor(
              key: anchor.key,
              indexInText: anchor.indexInText
                  .clamp(0, tokenPass.correctedText.length),
              content: anchor.content,
            ));
            continue;
          }

          final fnPre = _repairMultiWordSplitsAndTerkips(
            text: content,
            blockIndex: blockIdx,
          );
          if (fnPre.$1 != content) {
            didModify = true;
            for (final corr in fnPre.$2) {
              final key =
                  '$blockIdx:${_toTurkishLower(corr.originalWord)}->${_toTurkishLower(corr.correctedWord)}';
              if (seenCorrectionKeys.add(key)) {
                autoCorrections.add(corr);
              }
            }
          }

          final fnHealed = OcrTextHealer.heal(fnPre.$1);
          if (fnHealed != fnPre.$1) {
            didModify = true;
            final fnDiffs = _extractWordDiffs(
              beforeText: fnPre.$1,
              afterText: fnHealed,
              blockIndex: blockIdx,
              ruleCategory: 'Dipnot Morfolojik Onarım',
            );
            for (final diff in fnDiffs) {
              final key =
                  '$blockIdx:${_toTurkishLower(diff.originalWord)}->${_toTurkishLower(diff.correctedWord)}';
              if (seenCorrectionKeys.add(key)) {
                autoCorrections.add(diff);
              }
            }
          }

          final fnTokenPass = _proofreadParagraphTokens(
            text: fnHealed,
            blockIndex: blockIdx,
            mlKitLowConfidenceWords: mlKitLowConfidenceWords,
            pageVocabulary: pageVocabulary,
          );
          totalWords += fnTokenPass.wordCount;
          if (fnTokenPass.correctedText != content) {
            didModify = true;
          }
          for (final corr in fnTokenPass.autoCorrections) {
            final key =
                '$blockIdx:${_toTurkishLower(corr.originalWord)}->${_toTurkishLower(corr.correctedWord)}';
            if (seenCorrectionKeys.add(key)) {
              autoCorrections.add(corr);
            }
          }
          for (final sugg in fnTokenPass.suggestions) {
            final lowerSugg = _toTurkishLower(sugg.suspiciousWord);
            if (seenSuggestionWords.add(lowerSugg)) {
              suggestions.add(sugg);
            }
          }

          repairedAnchors.add(FootnoteAnchor(
            key: anchor.key,
            indexInText: anchor.indexInText
                .clamp(0, tokenPass.correctedText.length),
            content: fnTokenPass.correctedText,
          ));
        }
        updatedAnchors = repairedAnchors;
      }

      updatedBlocks.add(TextBlock(
        text: tokenPass.correctedText,
        isHeading: block.isHeading,
        isArabic: block.isArabic,
        footnoteAnchors: updatedAnchors,
      ));
    }

    // 3. Eğer ham (henüz heal edilmemiş) metin verilmişse ve bloklar zaten heal edilmişse,
    // ham metin ile düzeltilmiş metin arasındaki kelime dönüşümlerini de rapora ekle
    if (unhealedRawText != null && unhealedRawText.trim().isNotEmpty) {
      final rawMultiWordPass = _repairMultiWordSplitsAndTerkips(
        text: unhealedRawText,
        blockIndex: 0,
      );
      for (final corr in rawMultiWordPass.$2) {
        final anySame = autoCorrections.any(
          (c) =>
              _toTurkishLower(c.originalWord) ==
                  _toTurkishLower(corr.originalWord) &&
              _toTurkishLower(c.correctedWord) ==
                  _toTurkishLower(corr.correctedWord),
        );
        if (!anySame && autoCorrections.length < 40) {
          autoCorrections.add(corr);
        }
      }

      final finalCombined = updatedBlocks
          .whereType<TextBlock>()
          .where((b) => !b.isArabic)
          .map((b) => b.text)
          .join('\n\n');
      final rawDiffs = _extractWordDiffs(
        beforeText: rawMultiWordPass.$1,
        afterText: finalCombined,
        blockIndex: 0,
        ruleCategory: 'OCR Otomatik Tashih',
      );
      for (final diff in rawDiffs) {
        final anySameWord = autoCorrections.any(
          (c) =>
              _toTurkishLower(c.originalWord) == _toTurkishLower(diff.originalWord) &&
              _toTurkishLower(c.correctedWord) == _toTurkishLower(diff.correctedWord),
        );
        if (!anySameWord && autoCorrections.length < 40) {
          autoCorrections.add(diff);
        }
      }
    }

    return OcrProofreadBlockResult(
      blocks: updatedBlocks,
      report: OcrPageReviewReport(
        autoCorrections: autoCorrections,
        suggestions: suggestions,
        totalWordsScanned: totalWords,
      ),
      didModifyBlocks: didModify,
    );
  }

  /// Seçilen tek bir kelime için Word tarzı düzeltme önerileri üretir
  static List<String> suggestForWord(String word) {
    final clean = _stripOuterPunctuation(word.trim());
    if (clean.isEmpty) return const [];

    final results = <String>[];
    void addUnique(String candidate) {
      final c = _matchCase(clean, candidate);
      if (_toTurkishLower(c) != _toTurkishLower(clean) && !results.contains(c)) {
        results.add(c);
      }
    }

    // 1. Kullanıcı kuralı varsa ilk sıraya koy
    final userRule = _userAutoCorrectRules[_toTurkishLower(clean)];
    if (userRule != null) {
      addUnique(userRule);
    }

    // 2. OcrTextHealer ile onarım dene
    final healed = OcrTextHealer.heal(clean);
    if (healed != clean) {
      addUnique(healed);
    }

    // 3. Fonotaktik ve OCR karışıklık matrisi onarımı dene
    final autoFixed = _tryAutomaticOcrWordRepair(clean);
    if (autoFixed != null) {
      addUnique(autoFixed.$1);
    }

    // 4. Sözlükten en yakın adayları bul
    final lexCandidates = _findClosestLexiconCandidates(clean, maxResults: 5);
    for (final cand in lexCandidates) {
      addUnique(cand);
    }

    return results.take(5).toList();
  }

  /// Sayfadaki belirli bir kelimeyi (veya tüm eşleşmelerini) hedef kelimeyle değiştirir
  static List<ContentBlock> replaceWordInBlocks({
    required List<ContentBlock> blocks,
    required String targetWord,
    required String replacementWord,
    int? onlyBlockIndex,
  }) {
    final cleanTarget = _stripOuterPunctuation(targetWord.trim());
    final cleanReplacement = _stripOuterPunctuation(replacementWord.trim());
    if (cleanTarget.isEmpty || cleanReplacement.isEmpty) return blocks;

    final escaped = RegExp.escape(cleanTarget);
    final wordRegex = RegExp(
      '(?<![\\p{L}])($escaped)(?![\\p{L}])',
      caseSensitive: false,
      unicode: true,
    );

    final updated = <ContentBlock>[];
    for (int i = 0; i < blocks.length; i++) {
      final b = blocks[i];
      if (b is TextBlock && !b.isArabic && (onlyBlockIndex == null || onlyBlockIndex == i)) {
        final newText = b.text.replaceAllMapped(wordRegex, (m) {
          final matched = m.group(1)!;
          return _matchCase(matched, cleanReplacement);
        });
        final updatedAnchors = b.footnoteAnchors.map((a) {
          final content = a.content;
          if (content == null || content.isEmpty) {
            return FootnoteAnchor(
              key: a.key,
              indexInText: a.indexInText.clamp(0, newText.length),
              content: a.content,
            );
          }
          final newContent = content.replaceAllMapped(wordRegex, (m) {
            return _matchCase(m.group(1)!, cleanReplacement);
          });
          return FootnoteAnchor(
            key: a.key,
            indexInText: a.indexInText.clamp(0, newText.length),
            content: newContent,
          );
        }).toList();
        updated.add(TextBlock(
          text: newText,
          isHeading: b.isHeading,
          isArabic: b.isArabic,
          footnoteAnchors: updatedAnchors,
        ));
      } else {
        updated.add(b);
      }
    }
    return updated;
  }

  /// Paragraf içindeki kelimeleri tek tek tarayarak:
  /// 1) Yüksek güvenilirlikli OCR bozulmalarını otomatik düzeltir,
  /// 2) Kalan şüpheli kelimeler için öneri listesi üretir.
  static _ParagraphProofreadPass _proofreadParagraphTokens({
    required String text,
    required int blockIndex,
    Map<String, double>? mlKitLowConfidenceWords,
    Map<String, int>? pageVocabulary,
  }) {
    if (text.trim().isEmpty) {
      return _ParagraphProofreadPass(
        correctedText: text,
        autoCorrections: const [],
        suggestions: const [],
        wordCount: 0,
      );
    }

    final preMultiPass = _repairMultiWordSplitsAndTerkips(
      text: text,
      blockIndex: blockIndex,
    );
    final workingText = preMultiPass.$1;

    final tokenRegex = RegExp(
      r"([a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ0-9’'\x27]{2,})",
      unicode: true,
    );

    final matches = tokenRegex.allMatches(workingText).toList();
    if (matches.isEmpty) {
      return _ParagraphProofreadPass(
        correctedText: workingText,
        autoCorrections: preMultiPass.$2,
        suggestions: const [],
        wordCount: 0,
      );
    }

    final autoCorrections = <OcrCorrectionItem>[...preMultiPass.$2];
    final suggestions = <OcrSuggestionItem>[];
    final seenSuggestionTokens = <String>{};
    final buffer = StringBuffer();
    int lastEnd = 0;
    int wordCount = 0;

    for (int idx = 0; idx < matches.length; idx++) {
      final m = matches[idx];
      final rawToken = m.group(0)!;
      buffer.write(workingText.substring(lastEnd, m.start));
      lastEnd = m.end;

      // Sadece rakamlardan veya Romen rakamlarından oluşan belirteçleri atla
      if (RegExp(r'^\d+$').hasMatch(rawToken) ||
          RegExp(r'^[IVXLCDM]+\.?$').hasMatch(rawToken)) {
        buffer.write(rawToken);
        continue;
      }

      wordCount++;
      final lowerToken = _toTurkishLower(rawToken);

      // 0. Kullanıcının yoksaydığı kelimelere dokunma
      if (_ignoredWords.contains(lowerToken)) {
        buffer.write(rawToken);
        continue;
      }

      // 1. Kullanıcının kaydettiği özel Otomatik Düzeltme kuralı var mı?
      final userRuleTarget = _userAutoCorrectRules[lowerToken];
      if (userRuleTarget != null) {
        final replacement = _matchCase(rawToken, userRuleTarget);
        buffer.write(replacement);
        if (replacement != rawToken) {
          autoCorrections.add(OcrCorrectionItem(
            id: 'usr_${blockIndex}_$idx',
            originalWord: rawToken,
            correctedWord: replacement,
            contextSnippet: _extractContextSnippet(workingText, m.start, m.end),
            blockIndex: blockIndex,
            ruleCategory: 'Kullanıcı Tashih Kuralı',
            confidence: 1.0,
          ));
        }
        continue;
      }

      // 2. Yüksek güvenilirlikli otomatik OCR kelime onarımı dene (Sol/Sağ bağlam ve ML Kit confidence ile)
      final prevToken = idx > 0 ? matches[idx - 1].group(0) : null;
      final nextToken =
          idx + 1 < matches.length ? matches[idx + 1].group(0) : null;
      final mlKitConf = mlKitLowConfidenceWords?[lowerToken];
      final isLikelyProperNoun = _isCapitalizedMidSentence(workingText, m.start, rawToken);
      var autoRepaired = _tryAutomaticOcrWordRepair(
        rawToken,
        prevWord: prevToken,
        nextWord: nextToken,
        mlKitConfidence: mlKitConf,
      );

      // 2b. Sözlük Doğrulaması: kural tabanlı düzeltme sözlükte yoksa veya hiç düzeltme
      // üretilmediyse "üret ve doğrula" adaylarından tartışmasız olanı veya bağlamla kazananı kullan.
      final hasApostrophe = rawToken.contains("'") || rawToken.contains('’');
      final hasDigit = RegExp(r'\d').hasMatch(rawToken);
      final lexicon = _getLexicon();
      OcrCorrectionDecision? decision;

      if (!hasApostrophe && !hasDigit) {
        final tokenIsKnown = _isValidKnownTurkishWord(lowerToken, lexicon);
        final ruleOutputKnown = autoRepaired != null &&
            _isValidKnownTurkishWord(_toTurkishLower(autoRepaired.$1), lexicon);
        if (!tokenIsKnown && !ruleOutputKnown) {
          decision = OcrCandidateGenerator.decide(
            rawToken,
            pageVocabulary: pageVocabulary,
          );
          final best = decision.best;
          final allowAuto = decision.isDecisive() &&
              best != null &&
              (!isLikelyProperNoun || best.cost <= 0.2);
          if (allowAuto) {
            autoRepaired = (
              _matchCase(rawToken, best.word),
              'Sözlük Doğrulamalı OCR Onarımı',
            );
          } else if (decision.candidates.length >= 2 &&
              best != null &&
              best.cost <= 0.45) {
            final cand0 = decision.candidates[0];
            final cand1 = decision.candidates[1];
            final score0 = OcrLocalAiLanguageModel.scoreCandidateInContext(
              candidate: cand0.word,
              lexicon: lexicon,
              prevWord: prevToken,
              nextWord: nextToken,
              editDistance: cand0.cost,
              mlKitConfidence: mlKitConf,
            );
            final score1 = OcrLocalAiLanguageModel.scoreCandidateInContext(
              candidate: cand1.word,
              lexicon: lexicon,
              prevWord: prevToken,
              nextWord: nextToken,
              editDistance: cand1.cost,
              mlKitConfidence: mlKitConf,
            );
            OcrVerifiedCandidate? tieWinner;
            if (score0 - score1 >= 0.12) {
              tieWinner = cand0;
            } else if (score1 - score0 >= 0.12) {
              tieWinner = cand1;
            }
            if (tieWinner != null &&
                (!isLikelyProperNoun || tieWinner.cost <= 0.2)) {
              autoRepaired = (
                _matchCase(rawToken, tieWinner.word),
                'Bağlamsal Sözlük Doğrulamalı OCR Onarımı',
              );
            }
          }
        }
      }

      if (autoRepaired != null && autoRepaired.$1 != rawToken) {
        final fixedWord = autoRepaired.$1;
        final category = autoRepaired.$2;
        buffer.write(fixedWord);
        autoCorrections.add(OcrCorrectionItem(
          id: 'auto_${blockIndex}_$idx',
          originalWord: rawToken,
          correctedWord: fixedWord,
          contextSnippet: _extractContextSnippet(workingText, m.start, m.end),
          blockIndex: blockIndex,
          ruleCategory: category,
          confidence: 0.94,
        ));
        continue;
      }

      // 3. Kelime otomatik düzeltilmediyse sıfır sızıntı ilkesiyle sözlük dışı / şüpheli kelimeleri önerilere ekle
      final isKnownToken = _isValidKnownTurkishWord(lowerToken, lexicon);
      if (lowerToken.length >= 3 &&
          !hasApostrophe &&
          !isLikelyProperNoun &&
          !isKnownToken) {
        final anomalyReason = _detectOcrSuspicionReason(rawToken);
        final mergedCandidates = <String>[];
        void addSuggestionCand(String cand) {
          final cased = _matchCase(rawToken, cand);
          final casedLower = _toTurkishLower(cased);
          if (casedLower != lowerToken &&
              !mergedCandidates
                  .any((existing) => _toTurkishLower(existing) == casedLower)) {
            mergedCandidates.add(cased);
          }
        }

        if (decision != null) {
          for (final c in decision.candidates) {
            addSuggestionCand(c.word);
          }
        } else if (!hasDigit) {
          final fallbackDecision = OcrCandidateGenerator.decide(
            rawToken,
            pageVocabulary: pageVocabulary,
          );
          for (final c in fallbackDecision.candidates) {
            addSuggestionCand(c.word);
          }
        }

        for (final s in OcrLocalAiLanguageModel.lookupSymSpellCandidates(
          lowerToken,
          lexicon: lexicon,
          maxEditDistance: 2,
          maxResults: 4,
        )) {
          addSuggestionCand(s);
        }

        for (final lexCand in _findClosestLexiconCandidates(rawToken, maxResults: 4)) {
          addSuggestionCand(lexCand);
        }

        if ((mergedCandidates.isNotEmpty || anomalyReason != null) &&
            seenSuggestionTokens.add(lowerToken)) {
          suggestions.add(OcrSuggestionItem(
            id: 'sugg_${blockIndex}_$idx',
            suspiciousWord: rawToken,
            suggestions: mergedCandidates.take(4).toList(),
            contextSnippet: _extractContextSnippet(workingText, m.start, m.end),
            blockIndex: blockIndex,
            issueDescription:
                anomalyReason ?? 'Sözlükte bulunamadı — olası OCR hatası',
          ));
        }
      }

      buffer.write(rawToken);
    }

    buffer.write(workingText.substring(lastEnd));

    return _ParagraphProofreadPass(
      correctedText: buffer.toString(),
      autoCorrections: autoCorrections,
      suggestions: suggestions,
      wordCount: wordCount,
    );
  }

  /// Çoklu kelime bölünmelerini ("yurt taşlar", "bi çimini", "gö receğiz") ve
  /// Osmanlıca izafet terkiplerini ("adab ı muaşeret" -> "âdâb-ı muaşeret") onarır.
  static (String, List<OcrCorrectionItem>) _repairMultiWordSplitsAndTerkips({
    required String text,
    required int blockIndex,
  }) {
    if (text.trim().isEmpty) return (text, const []);

    var working = text;
    final corrections = <OcrCorrectionItem>[];
    final lexicon = _getLexicon();
    int seq = 0;

    // 0a. Kelime içine sıkışmış görünmez tire (\u00AD) ve sıfır genişlikli karakterleri birleştir
    final invisibleWordRegex = RegExp(
      r'([a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]+(?:[\u00AD\u200B\u200C\uFEFF]+[a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]+)+)',
      unicode: true,
    );
    working = working.replaceAllMapped(invisibleWordRegex, (m) {
      final raw = m.group(0)!;
      final cleaned = raw.replaceAll(RegExp(r'[\u00AD\u200B\u200C\uFEFF]'), '');
      if (cleaned != raw) {
        corrections.add(OcrCorrectionItem(
          id: 'invis_${blockIndex}_${seq++}',
          originalWord: raw,
          correctedWord: cleaned,
          contextSnippet: _extractContextSnippet(working, m.start, m.end),
          blockIndex: blockIndex,
          ruleCategory: 'Görünmez Tire Birleştirme',
          confidence: 0.99,
        ));
      }
      return cleaned;
    });
    working = working.replaceAll(RegExp(r'[\u00AD\u200B\u200C\uFEFF]'), '');

    // 0b. Paragraf içi kırık tireleri ("me- deniyet" -> "medeniyet") sözlükle doğrula ve birleştir
    final inlineBrokenHyphenRegex = RegExp(
      r'(?<![\p{L}])([a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]{2,})[-¬]\s+([a-zçğıöşüâîû]{2,})(?![\p{L}])',
      unicode: true,
    );
    working = working.replaceAllMapped(inlineBrokenHyphenRegex, (m) {
      final w1 = m.group(1)!;
      final w2 = m.group(2)!;
      final l1 = _toTurkishLower(w1);
      final l2 = _toTurkishLower(w2);
      if (l1 != l2 && _isValidKnownTurkishWord('$l1$l2', lexicon)) {
        final combined = '$w1$w2';
        corrections.add(OcrCorrectionItem(
          id: 'inhy_${blockIndex}_${seq++}',
          originalWord: m.group(0)!,
          correctedWord: combined,
          contextSnippet: _extractContextSnippet(working, m.start, m.end),
          blockIndex: blockIndex,
          ruleCategory: 'Satır İçi Kırık Tire Onarımı',
          confidence: 0.97,
        ));
        return combined;
      }
      return m.group(0)!;
    });

    // 1. 3 kelimeli Osmanlıca izafet terkipleri ("adab ı muaşeret" -> "âdâb-ı muaşeret")
    working = working.replaceAllMapped(
      RegExp(
        r'(?<![\p{L}])([a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]{2,})[ \t\r\n]+([ıiüuûî])[ \t\r\n]+([a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]{2,})(?![\p{L}])',
        unicode: true,
      ),
      (m) {
        final w1 = m.group(1)!;
        final izafet = m.group(2)!;
        final w3 = m.group(3)!;
        final key =
            '${_toTurkishLower(w1)} ${_toTurkishLower(izafet)} ${_toTurkishLower(w3)}';
        final repaired = OcrLexiconDatabase.ottomanTerkipRepairs[key];
        if (repaired != null) {
          final matchedCase = _matchCase(w1, repaired);
          final originalPhrase = '$w1 $izafet $w3';
          if (matchedCase != originalPhrase) {
            corrections.add(OcrCorrectionItem(
              id: 'terkip3_${blockIndex}_${seq++}',
              originalWord: originalPhrase,
              correctedWord: matchedCase,
              contextSnippet: _extractContextSnippet(working, m.start, m.end),
              blockIndex: blockIndex,
              ruleCategory: 'Osmanlıca Terkip Tashihi',
              confidence: 0.99,
            ));
          }
          return matchedCase;
        }
        return m.group(0)!;
      },
    );

    // 2. 2 kelimeli Osmanlıca terkipler, bilinen hece bölünmeleri ve algoritmik sözlük tabanlı birleştirici
    final wordTokenMatches = RegExp(
      r"[a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]+(?:['’][a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]+)?",
      unicode: true,
    ).allMatches(working).toList();

    if (wordTokenMatches.length >= 2) {
      final sb = StringBuffer();
      int lastEnd = 0;

      for (int i = 0; i < wordTokenMatches.length; i++) {
        final m1 = wordTokenMatches[i];
        sb.write(working.substring(lastEnd, m1.start));
        final w1 = m1.group(0)!;

        if (i + 1 < wordTokenMatches.length) {
          final m2 = wordTokenMatches[i + 1];
          final gap = working.substring(m1.end, m2.start);
          if (RegExp(r'^[ \t\r\n]+$').hasMatch(gap)) {
            final w2 = m2.group(0)!;
            final l1 = _toTurkishLower(w1);
            final l2 = _toTurkishLower(w2);
            final pairKey = '$l1 $l2';

            // 2a. 2 kelimeli Osmanlıca izafet terkibi ("adabı muaşeret" -> "âdâb-ı muaşeret")
            final terkip = OcrLexiconDatabase.ottomanTerkipRepairs[pairKey];
            if (terkip != null) {
              final matchedCase = _matchCase(w1, terkip);
              final originalPhrase = '$w1 $w2';
              if (matchedCase != originalPhrase) {
                corrections.add(OcrCorrectionItem(
                  id: 'terkip2_${blockIndex}_${seq++}',
                  originalWord: originalPhrase,
                  correctedWord: matchedCase,
                  contextSnippet:
                      _extractContextSnippet(working, m1.start, m2.end),
                  blockIndex: blockIndex,
                  ruleCategory: 'Osmanlıca Terkip Tashihi',
                  confidence: 0.99,
                ));
              }
              sb.write(matchedCase);
              lastEnd = m2.end;
              i++;
              continue;
            }

            // 2b. Bilinen satır sonu / hece bölünmesi çifti ("yurt taşlar" -> "yurttaşlar", "bi çimini" -> "biçimini", "sık ilkle" -> "sıklıkla")
            final splitFixed =
                OcrLexiconDatabase.spaceSplitBigramRepairs[pairKey];
            if (splitFixed != null) {
              final matchedCase = _matchCase(w1, splitFixed);
              final originalPhrase = '$w1 $w2';
              if (matchedCase != originalPhrase) {
                corrections.add(OcrCorrectionItem(
                  id: 'split_${blockIndex}_${seq++}',
                  originalWord: originalPhrase,
                  correctedWord: matchedCase,
                  contextSnippet:
                      _extractContextSnippet(working, m1.start, m2.end),
                  blockIndex: blockIndex,
                  ruleCategory: 'Bölünmüş Kelime Birleştirme',
                  confidence: 0.98,
                ));
              }
              sb.write(matchedCase);
              lastEnd = m2.end;
              i++;
              continue;
            }

            // 2c. Algoritmik Sözlük Tabanlı Birleştirici
            bool w2PairsWithNext = false;
            if (i + 2 < wordTokenMatches.length) {
              final m3 = wordTokenMatches[i + 2];
              final gap2 = working.substring(m2.end, m3.start);
              if (RegExp(r'^[ \t\r\n]+$').hasMatch(gap2)) {
                final l3 = _toTurkishLower(m3.group(0)!);
                final nextKey = '$l2 $l3';
                if (OcrLexiconDatabase.spaceSplitBigramRepairs
                        .containsKey(nextKey) ||
                    OcrLexiconDatabase.ottomanTerkipRepairs
                        .containsKey(nextKey)) {
                  w2PairsWithNext = true;
                }
              }
            }

            final hasAdjacentHyphen =
                (m1.start > 0 && working[m1.start - 1] == '-') ||
                (m2.end < working.length && working[m2.end] == '-');

            if (!w2PairsWithNext &&
                !hasAdjacentHyphen &&
                l2.length >= 3 &&
                !OcrLexiconDatabase.neverMergeWordPairs.contains(pairKey) &&
                w2 == l2 &&
                !w1.contains("'") &&
                !w1.contains('’')) {
              final combinedLower = '$l1$l2';
              if (_isValidKnownTurkishWord(combinedLower, lexicon)) {
                final isW1Valid = _isValidKnownTurkishWord(l1, lexicon);
                final isW2Valid = _isValidKnownTurkishWord(l2, lexicon);
                if (!isW2Valid ||
                    (!isW1Valid &&
                        OcrLexiconDatabase.breakableSyllablePrefixes
                            .contains(l1))) {
                  final matchedCase = _matchCase(w1, combinedLower);
                  final originalPhrase = '$w1 $w2';
                  corrections.add(OcrCorrectionItem(
                    id: 'algmerge_${blockIndex}_${seq++}',
                    originalWord: originalPhrase,
                    correctedWord: matchedCase,
                    contextSnippet:
                        _extractContextSnippet(working, m1.start, m2.end),
                    blockIndex: blockIndex,
                    ruleCategory: 'Bölünmüş Kelime Birleştirme',
                    confidence: 0.95,
                  ));
                  sb.write(matchedCase);
                  lastEnd = m2.end;
                  i++;
                  continue;
                }
              }

              // 2d. Katman 2 & 3: Yerel AI (SymSpell + Char-Beam + Bağlamsal N-Gram) Bozuk İkili Birleştirici
              // Ör: "gö recegiz" -> "göreceğiz", "deger lendirebilmek" -> "değerlendirebilmek",
              // "gercek lestiğini" -> "gerçekleştiğini", "basarısız ilkle" -> "başarısızlıkla"
              final prevWord =
                  i > 0 ? wordTokenMatches[i - 1].group(0) : null;
              final nextWord = i + 2 < wordTokenMatches.length
                  ? wordTokenMatches[i + 2].group(0)
                  : null;
              final aiBigramFixed =
                  OcrLocalAiLanguageModel.repairBrokenBigramInContext(
                firstWord: l1,
                secondWord: l2,
                lexicon: lexicon,
                prevWord: prevWord,
                nextWord: nextWord,
              );
              if (aiBigramFixed != null) {
                final matchedCase =
                    _matchCase(w1, aiBigramFixed.correctedWord);
                final originalPhrase = '$w1 $w2';
                corrections.add(OcrCorrectionItem(
                  id: 'aibigram_${blockIndex}_${seq++}',
                  originalWord: originalPhrase,
                  correctedWord: matchedCase,
                  contextSnippet:
                      _extractContextSnippet(working, m1.start, m2.end),
                  blockIndex: blockIndex,
                  ruleCategory:
                      'Yerel AI Bağlamsal N-Gram & SymSpell Onarımı',
                  confidence: aiBigramFixed.confidence,
                ));
                sb.write(matchedCase);
                lastEnd = m2.end;
                i++;
                continue;
              }
            }
          }
        }

        sb.write(w1);
        lastEnd = m1.end;
      }

      sb.write(working.substring(lastEnd));
      working = sb.toString();
    }

    return (working, corrections);
  }

  /// Bir kelimenin OCR sonrası hatalı olduğunu kesin olarak tespit edip
  /// (düzeltilmişKelime, kuralKategorisi) ikilisini döndürür.
  static (String, String)? _tryAutomaticOcrWordRepair(
    String token, {
    String? prevWord,
    String? nextWord,
    double? mlKitConfidence,
  }) {
    if (token.length < 2 || token.length > 48) return null;

    // Özel isim veya kesme işaretli kelime ise gövde ve eki ayrı ayrı denetle
    // (Ör: "Artzona'yı" -> "Arizona'yı", "Osmanlı'nm" -> "Osmanlı'nın", "1923'de" -> "1923'te")
    final aposIdx = token.lastIndexOf(RegExp(r"['’]"));
    if (aposIdx > 0 && aposIdx < token.length - 1) {
      return _repairApostropheInflectedToken(
        token: token,
        aposIdx: aposIdx,
        prevWord: prevWord,
        nextWord: nextWord,
        mlKitConfidence: mlKitConfidence,
      );
    }

    final lower = _toTurkishLower(token);
    final lexicon = _getLexicon();
    final isLowMlKitConf =
        mlKitConfidence != null && mlKitConfidence < 0.78;

    // KURAL 0: Bağlamsal Gerçek-Kelime OCR Karışıklık Çözücüsü (Real-Word Contextual Disambiguation)
    // Sözlükte var olsa bile cümlede anlamsızlaşan kelimeleri ("120 dini"->"120 bini", "yalnızca diridir"->"yalnızca biridir",
    // "ortalama getir"->"ortalama gelir", "yaklaşım 30"->"yaklaşık 30", "büyük yoğunluğu"->"büyük çoğunluğu",
    // "ikiye ayrılık"->"ikiye ayrılır", "savaşa iştikak"->"savaşa iştirak", "mütenasip okur"->"mütenasip olur",
    // "60 bin oluş"->"60 bin olup", "Fark Devleti"->"Fars Devleti", "sınıf, yurt"->"sınır, yurt") bağlamla onar
    final contextualRealWord =
        OcrLocalAiLanguageModel.repairContextualRealWordInContext(
      word: lower,
      prevWord: prevWord,
      nextWord: nextWord,
    );
    if (contextualRealWord != null &&
        contextualRealWord.correctedWord != lower) {
      return (
        _matchCase(token, contextualRealWord.correctedWord),
        contextualRealWord.explanation,
      );
    }

    // Eğer kelime (veya bilinen kurallı gövdesi) zaten sözlükte geçerliyse,
    // OCR anomalisi taşımıyorsa ve ML Kit düşük güven işaretlememişse dokunma
    if (_isValidKnownTurkishWord(lower, lexicon) &&
        !_hasHardOcrAnomaly(token) &&
        !isLowMlKitConf) {
      return null;
    }

    // KURAL A: Kelime içine sıkışmış rakamların ('0'->'o', '1'->'i'/'ı', '5'->'s') onarımı
    // Ör: "b1r" -> "bir", "k1tap" -> "kitap", "0lduğu" -> "olduğu", "i5e" -> "ise"
    if (RegExp(r'[a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]').hasMatch(token) &&
        RegExp(r'[0158]').hasMatch(token)) {
      var digitHealed = token
          .replaceAll('0', 'o')
          .replaceAll('5', 's')
          .replaceAll('8', 'b');
      if (digitHealed.contains('1')) {
        final withI = _toTurkishLower(digitHealed.replaceAll('1', 'i'));
        final withDotlessI = _toTurkishLower(digitHealed.replaceAll('1', 'ı'));
        if (_isValidKnownTurkishWord(withI, lexicon)) {
          digitHealed = digitHealed.replaceAll('1', 'i');
        } else if (_isValidKnownTurkishWord(withDotlessI, lexicon)) {
          digitHealed = digitHealed.replaceAll('1', 'ı');
        } else {
          final vowel = _hasBackVowel(digitHealed) ? 'ı' : 'i';
          digitHealed = digitHealed.replaceAll('1', vowel);
        }
      }
      digitHealed = _normalizeMixedCase(digitHealed);
      final lowerDigitHealed = _toTurkishLower(digitHealed);
      if (!_isValidKnownTurkishWord(lowerDigitHealed, lexicon)) {
        final exactMatch = _findExactConfusionMatch(lowerDigitHealed, lexicon);
        if (exactMatch != null) {
          digitHealed = _matchCase(token, exactMatch);
        }
      }
      if (digitHealed != token) {
        return (digitHealed, 'Rakam-Harf OCR Onarımı');
      }
    }

    // KURAL B: Kelime ortasında veya sonunda büyük harf kayması (Ör: "kİtap" -> "kitap", "mÜslüman" -> "müslüman")
    if (token.length >= 3 &&
        token != token.toUpperCase() &&
        RegExp(r'^[A-ZÇĞİÖŞÜÂÎÛ]?[a-zçğıöşüâîû]+[A-ZÇĞİÖŞÜÂÎÛ][a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]*$')
            .hasMatch(token)) {
      final caseFixed = _normalizeMixedCase(token);
      if (caseFixed != token) {
        final further = _tryAutomaticOcrWordRepair(caseFixed);
        return (further?.$1 ?? caseFixed, 'Büyük/Küçük Harf Onarımı');
      }
    }

    // KURAL C: 'cl' -> 'd' OCR kaynaşması
    // Türkçede 'meclis' kökü dışında hiçbir kelime 'cl' içermez veya 'cl' ile başlamaz
    // ("clünya" -> "dünya", "claha" -> "daha", "cle" -> "de", "clevlet" -> "devlet", "kaclar" -> "kadar", "aclalet" -> "adalet")
    if (lower.contains('cl') && !lower.startsWith('meclis')) {
      final clReplaced = lower.replaceAll('cl', 'd');
      if (_isValidKnownTurkishWord(clReplaced, lexicon) || lower.startsWith('cl')) {
        return (_matchCase(token, clReplaced), 'OCR Harf Kaynaşması (cl→d)');
      }
    }

    // KURAL D: 'rn' -> 'm' OCR kaynaşması
    // Ör: "zarnan" -> "zaman", "hakirn" -> "hakim", "hükürn" -> "hüküm", "toplurn" -> "toplum", "dururn" -> "durum",
    // "rnüslüman" -> "müslüman", "rnedrese" -> "medrese", "rnesele" -> "mesele", "rnevzu" -> "mevzu", "insanlarn" -> "insanların"
    if (lower.contains('rn') &&
        !_legitimateRnWords.any((w) => lower.startsWith(w))) {
      // 1. Çoğul tamlayan '-larn' / '-lern' -> '-ların' / '-lerin'
      if (lower.endsWith('larn')) {
        final fixed = '${lower.substring(0, lower.length - 4)}ların';
        return (_matchCase(token, fixed), 'Ek Ünlü Düşmesi (-larn→-ların)');
      }
      if (lower.endsWith('lern')) {
        final fixed = '${lower.substring(0, lower.length - 4)}lerin';
        return (_matchCase(token, fixed), 'Ek Ünlü Düşmesi (-lern→-lerin)');
      }

      // 2. 'rn' -> 'm' dönüşümü
      final rnToM = lower.replaceAll('rn', 'm');
      if (lower.startsWith('rn') ||
          lower.endsWith('rn') ||
          _isValidKnownTurkishWord(rnToM, lexicon)) {
        return (_matchCase(token, rnToM), 'OCR Harf Kaynaşması (rn→m)');
      }
    }

    // KURAL D2: Türkçe OCR 'rı'/'ri' -> 'n' kaynaşması, '[ünlü]hk' -> '[ünlü]lık/lik' ve '[ünlü]yn' -> '[ünlü]yı/yi' onarımı
    // Ör: "kaplmalan" -> "kapılmaları", "hükümdarlanın" -> "hükümdarlarının", "kurtanr" -> "kurtarır", "kıhk" -> "kılık", "politikayn" -> "politikayı"
    if (RegExp(r'[aıoueiöüâîû]hk(?:la|le|tan|ten|ta|te|lar|ler|ları|leri|ın|in|un|ün|a|e|ı|i|u|ü)?$', unicode: true)
        .hasMatch(lower)) {
      final hkFixed = lower.replaceAllMapped(
        RegExp(r'([aıoueiöüâîû])hk(la|le|tan|ten|ta|te|lar|ler|ları|leri|ın|in|un|ün|a|e|ı|i|u|ü)?$', unicode: true),
        (m) {
          final vStem = m.group(1)!;
          final v = _hasBackVowel(vStem) ? 'ı' : 'i';
          return '${vStem}l${v}k${m.group(2) ?? ''}';
        },
      );
      if (hkFixed != lower) {
        return (_matchCase(token, hkFixed), 'OCR Harf Kaynaşması (hk→lık/lik)');
      }
    }

    if (lower.endsWith('yn') &&
        lower.length >= 4 &&
        RegExp(r'[aıoueiöü]yn$', unicode: true).hasMatch(lower) &&
        !const {'ebeveyn', 'harameyn', 'tarafeyn', 'bahreyn', 'kevneyn', 'sakaleyn', 'hüseyn', 'kamerayn'}
            .contains(lower)) {
      final stem = lower.substring(0, lower.length - 2);
      final v = _hasBackVowel(stem) ? 'ı' : 'i';
      return (_matchCase(token, '${stem}y$v'), 'Ek Harf Onarımı (-yn→-y$v)');
    }

    // Edilgen/dönüşlü çatı dar ünlü düşmesi ('kaplmalan' -> 'kapılmaları', 'yaplması' -> 'yapılması')
    if (RegExp(r'[aıoueiöü][bcçdfgğhjkmnpstvyz]lm[ae]', unicode: true).hasMatch(lower) &&
        !lower.startsWith('ilm') &&
        !lower.startsWith('film') &&
        !lower.startsWith('türkmen')) {
      var voiceHealed = lower.replaceAllMapped(
        RegExp(r'([aıoueiöü][bcçdfgğhjkmnpstvyz])l(m[ae])', unicode: true),
        (m) {
          final pre = m.group(1)!;
          final v = _hasBackVowel(pre) ? 'ı' : 'i';
          return '$pre${v}l${m.group(2)}';
        },
      );
      if (voiceHealed.endsWith('malan')) {
        voiceHealed = '${voiceHealed.substring(0, voiceHealed.length - 5)}maları';
      } else if (voiceHealed.endsWith('melen')) {
        voiceHealed = '${voiceHealed.substring(0, voiceHealed.length - 5)}meleri';
      }
      return (_matchCase(token, voiceHealed), 'OCR Ünlü & Ek Onarımı');
    }

    if (lower.endsWith('malan') && lower != 'yağmalan') {
      final fixed = '${lower.substring(0, lower.length - 5)}maları';
      return (_matchCase(token, fixed), 'OCR Harf Kaynaşması (-malan→-maları)');
    }
    if (lower.endsWith('melen')) {
      final fixed = '${lower.substring(0, lower.length - 5)}meleri';
      return (_matchCase(token, fixed), 'OCR Harf Kaynaşması (-melen→-meleri)');
    }
    if (lower.endsWith('lanın') &&
        !const {
          'olanın', 'kalanın', 'alanın', 'çalanın', 'dalanın', 'salanın', 'bulanın',
          'yalanın', 'falanın', 'filanın', 'planın', 'ilanın', 'yılanın', 'aslanın',
          'kaplanın', 'sırtlanın', 'ceylanın', 'oğlanın', 'dolanın',
        }.contains(lower)) {
      final fixed = '${lower.substring(0, lower.length - 5)}larının';
      return (_matchCase(token, fixed), 'OCR Harf Kaynaşması (-lanın→-larının)');
    }
    if (lower.endsWith('lenin') &&
        !const {
          'gelenin', 'bilenin', 'ölenin', 'gülenin', 'bölenin', 'silenin', 'delenin',
          'şölenin', 'polenin', 'çekilenin', 'verilenin', 'edilenin', 'denilenin',
          'bilinenin', 'görülenin', 'düşünülenin', 'istenilenin',
        }.contains(lower)) {
      final fixed = '${lower.substring(0, lower.length - 5)}lerinin';
      return (_matchCase(token, fixed), 'OCR Harf Kaynaşması (-lenin→-lerinin)');
    }
    if (lower.length >= 6 &&
        (lower.endsWith('lannın') ||
            lower.endsWith('lannı') ||
            lower.endsWith('lanna') ||
            lower.endsWith('lannda') ||
            lower.endsWith('lanndan') ||
            lower.endsWith('lann'))) {
      final fixed = lower.replaceFirst(RegExp(r'lann(?=(?:ın|ı|a|da|dan)?$)'), 'ların');
      return (_matchCase(token, fixed), 'OCR Harf Kaynaşması (-lann→-ların)');
    }
    if (lower.length >= 6 &&
        (lower.endsWith('lennin') ||
            lower.endsWith('lenni') ||
            lower.endsWith('lenne') ||
            lower.endsWith('lennde') ||
            lower.endsWith('lennden') ||
            lower.endsWith('lenn'))) {
      final fixed = lower.replaceFirst(RegExp(r'lenn(?=(?:in|i|e|de|den)?$)'), 'lerin');
      return (_matchCase(token, fixed), 'OCR Harf Kaynaşması (-lenn→-lerin)');
    }
    // Genel çoğul iyelik/belirtme '-lan' -> '-ları' ve '-len' -> '-leri' onarımı
    // (Ör: "insanlan" -> "insanları", "devletlen" -> "devletleri", "parçalan" -> "parçaları", "kendilen" -> "kendileri", "bazılan" -> "bazıları")
    if ((lower.endsWith('lan') || lower.endsWith('len')) &&
        OcrLocalAiLanguageModel.isCorruptedPluralLanLen(lower, lexicon)) {
      final isBack = lower.endsWith('lan');
      final fixed =
          '${lower.substring(0, lower.length - 3)}${isBack ? 'ları' : 'leri'}';
      return (
        _matchCase(token, fixed),
        'OCR Harf Kaynaşması (-${isBack ? 'lan→-ları' : 'len→-leri'})',
      );
    }
    if (lower.endsWith('nr') && lower.length >= 4) {
      final stemBeforeNr = lower.substring(0, lower.length - 2);
      final v = _hasBackVowel(stemBeforeNr) ? 'ı' : 'i';
      final candidateRir = '${stemBeforeNr}r${v}r';
      if (_isValidKnownTurkishWord(candidateRir, lexicon)) {
        return (_matchCase(token, candidateRir), 'OCR Harf Kaynaşması (n→r$v)');
      }
      final candidateNir = '${stemBeforeNr}n${v}r';
      if (_isValidKnownTurkishWord(candidateNir, lexicon)) {
        return (_matchCase(token, candidateNir), 'OCR Ünlü Düşmesi (-nr→-n${v}r)');
      }
    }
    // Kelime içindeki veya sonundaki 'n' harfinin 'rı'/'ri' kaynaşması olup olmadığını sözlükten doğrula
    // (Ör: "kanşık" -> "karışık", "banş" -> "barış", "tanm" -> "tarım", "kurtanr" -> "kurtarır", "onlan" -> "onları",
    // "aynca" -> "ayrıca", "aynntı" -> "ayrıntı", "çağn" -> "çağrı", "tanh" -> "tarih", "manfet" -> "marifet",
    // "hanta" -> "harita", "cumhunyet" -> "cumhuriyet", "yatınmlan" -> "yatırımları", "üzennde" -> "üzerinde")
    if (lower.contains('n') && lower.length >= 4 && !_isValidKnownTurkishWord(lower, lexicon)) {
      final nIndices = <int>[];
      for (int i = 1; i < lower.length; i++) {
        if (lower[i] == 'n') {
          nIndices.add(i);
          final prefix = lower.substring(0, i);
          final suffix = lower.substring(i + 1);
          final primaryRVowel = _hasBackVowel(prefix) ? 'rı' : 'ri';
          final secondaryRVowel = primaryRVowel == 'rı' ? 'ri' : 'rı';
          for (final rVowel in [primaryRVowel, secondaryRVowel]) {
            final candidate = '$prefix$rVowel$suffix';
            final isPluralAccusativeEnd = suffix.isEmpty &&
                OcrLocalAiLanguageModel.isCorruptedPluralLanLen(lower, lexicon);
            if (lexicon.contains(candidate) ||
                ((suffix.isNotEmpty || isPluralAccusativeEnd) &&
                    _isValidKnownTurkishWord(candidate, lexicon))) {
              return (_matchCase(token, candidate), 'OCR Harf Kaynaşması (n→$rVowel)');
            }
          }
        }
      }
      // Aynı kelimede 2 ayrı 'n' -> 'rı'/'ri' kaynaşması kontrolü (Ör: "yatınmlan" -> "yatırımları", "saldınlan" -> "saldırıları", "üzennde" -> "üzerinde")
      if (nIndices.length >= 2 && nIndices.length <= 5) {
        for (int a = 0; a < nIndices.length - 1; a++) {
          for (int b = a + 1; b < nIndices.length; b++) {
            final i1 = nIndices[a];
            final i2 = nIndices[b];
            final p1 = lower.substring(0, i1);
            final mid = lower.substring(i1 + 1, i2);
            final p2 = lower.substring(i2 + 1);
            final r1 = _hasBackVowel(p1) ? 'rı' : 'ri';
            final r2 = _hasBackVowel('$p1$r1$mid') ? 'rı' : 'ri';
            final cand2 = '$p1$r1$mid$r2$p2';
            if (lexicon.contains(cand2) || _isValidKnownTurkishWord(cand2, lexicon)) {
              return (_matchCase(token, cand2), 'OCR Çift Harf Kaynaşması (n→$r1/$r2)');
            }
          }
        }
      }
    }

    // İsim köküne bitişmiş 'idi' ek-fiili onarımı (Ör: "askeridi" -> "asker idi")
    if (lower.endsWith('idi') && lower.length >= 6 && !_isValidKnownTurkishWord(lower, lexicon)) {
      final stemBeforeIdi = lower.substring(0, lower.length - 3);
      if (lexicon.contains(stemBeforeIdi)) {
        final casedStem = _matchCase(token.substring(0, token.length - 3), stemBeforeIdi);
        return ('$casedStem idi', 'Bitişik Ek-Fiil Ayrımı (-idi)');
      }
    }

    // KURAL E: Silik baskıda 'a' veya 'e' ünlüsünün ünsüzler arasında 'c' olarak okunması
    // 1. Kelime başında 'c' + ünsüz (Türkçede imkansızdır: "ctmak" -> "atmak", "czamet" -> "azamet", "cyak" -> "ayak")
    if (RegExp(r'^c[bcçdfgğhjklmnprsştvyz]', unicode: true).hasMatch(lower)) {
      final tail = lower.substring(1);
      final vowel = _hasBackVowel(tail) ? 'a' : 'e';
      final candidate = '$vowel$tail';
      if (_isValidKnownTurkishWord(candidate, lexicon) || tail.length >= 3) {
        return (_matchCase(token, candidate), 'Fonotaktik Ünlü Onarımı (c→$vowel)');
      }
    }

    // 2. İki ünsüz arasına sıkışmış 'c' ([ünsüz] + c + [ünsüz]):
    // Ör: "bercber" -> "beraber", "kcrşı" -> "karşı", "tarcfından" -> "tarafından", "ycpmak" -> "yapmak", "zcmcn" -> "zaman", "inscn" -> "insan", "kitcp" -> "kitap"
    final consonantSandwichedC = RegExp(
      r'([bcçdfgğhjklmnprsştvyz])c([bcçdfgğhjklmnprsştvyz])',
      unicode: true,
    );
    if (consonantSandwichedC.hasMatch(lower)) {
      // Önce 'c' -> 'ç' kontrolü (Ör: "genclik" -> "gençlik", "borclu" -> "borçlu", "suclu" -> "suçlu")
      final cToCh = lower.replaceAllMapped(
        consonantSandwichedC,
        (m) => '${m.group(1)}ç${m.group(2)}',
      );
      if (_isValidKnownTurkishWord(cToCh, lexicon)) {
        return (_matchCase(token, cToCh), 'OCR Noktalama Onarımı (c→ç)');
      }

      final vowel = _hasBackVowel(lower) ? 'a' : 'e';
      final candidate = lower.replaceAllMapped(
        consonantSandwichedC,
        (m) => '${m.group(1)}$vowel${m.group(2)}',
      );
      if (_isValidKnownTurkishWord(candidate, lexicon) ||
          consonantSandwichedC.allMatches(lower).isNotEmpty) {
        return (_matchCase(token, candidate), 'Fonotaktik Ünlü Onarımı (c→$vowel)');
      }
    }

    // KURAL F: Sıfat-fiil, iyelik ve isimlerde yumuşak 'ğ' çengelinin düşmesi ('g' -> 'ğ')
    // Ör: "oldugu" -> "olduğu", "yaptıgı" -> "yaptığı", "geldigi" -> "geldiği", "gördügü" -> "gördüğü",
    // "dogru" -> "doğru", "deger" -> "değer", "ögren" -> "öğren"
    if (RegExp(r'[aıoueiöü]g[aıoueiöü]', unicode: true).hasMatch(lower)) {
      final gToSoftG = lower.replaceAllMapped(
        RegExp(r'([aıoueiöü])g([aıoueiöü])', unicode: true),
        (m) => '${m.group(1)}ğ${m.group(2)}',
      );
      if ((!_isValidKnownTurkishWord(lower, lexicon) &&
              _isValidKnownTurkishWord(gToSoftG, lexicon)) ||
          RegExp(r'(?:d[ıiuü]g[ıiuü]|t[ıiuü]g[ıiuü]|l[ıiuü]g[ıiuü]|acag[ıi]|eceg[iı])')
              .hasMatch(lower)) {
        return (_matchCase(token, gToSoftG), 'OCR Diyakritik Onarımı (g→ğ)');
      }
    }

    // KURAL G: Kelime başı ünlü düşmesi (Türkçede imkansız çift/üçlü ünsüzle başlayan kelimeler: "frsat"->"fırsat", "ktap"->"kitap", "blgi"->"bilgi", "dvlet"->"devlet")
    final startsWithThreeConsonants =
        RegExp(r'^[bcçdfgğhjklmnprsştvyz]{3}', unicode: true).hasMatch(lower);
    final startsWithInvalidTwoConsonants =
        RegExp(r'^[bcçdfgğhjklmnprsştvyz]{2}', unicode: true).hasMatch(lower) &&
            !_loanwordInitialClusters.any((c) => lower.startsWith(c));
    if (lower.length >= 4 &&
        (startsWithThreeConsonants || startsWithInvalidTwoConsonants)) {
      for (final v in const ['ı', 'i', 'a', 'e', 'u', 'ü', 'o', 'ö']) {
        final inserted = '${lower[0]}$v${lower.substring(1)}';
        if (_isValidKnownTurkishWord(inserted, lexicon)) {
          return (_matchCase(token, inserted), 'OCR Ünlü Düşmesi Onarımı (+$v)');
        }
      }
    }

    // KURAL H: Sözlük Tabanlı Diyakritik ve Ünlü Uyumu Tashihi
    // Yalnızca ünlü uyumu bozuk olan veya 'ı<->i', 'l<->i', 'c->ç', 's->ş', 'g->ğ', 'o->ö', 'u->ü' OCR nokta düşmesi yaşayan kelimelerde devreye girer
    if (lower.length >= 3 &&
        !_isValidKnownTurkishWord(lower, lexicon) &&
        _hasDiacriticOrHarmonySuspect(lower)) {
      final directConfusionMatch = _findExactConfusionMatch(lower, lexicon);
      if (directConfusionMatch != null && directConfusionMatch != lower) {
        return (_matchCase(token, directConfusionMatch), 'Sözlük & Diyakritik Tashihi');
      }
    }

    // KURAL H2: Ünsüz benzeşmesi (fıstıkçı şahap) ihlali onarımı ("kitapda" -> "kitapta", "gitdi" -> "gitti")
    if (lower.length >= 4 && !_isValidKnownTurkishWord(lower, lexicon)) {
      for (final suffix in _commonTurkishSuffixes) {
        if ((suffix.startsWith('d') || suffix.startsWith('c')) &&
            lower.length >= suffix.length + 2 &&
            lower.endsWith(suffix)) {
          final stem = lower.substring(0, lower.length - suffix.length);
          if (stem.isNotEmpty && 'çfhkpsşt'.contains(stem[stem.length - 1])) {
            final assimilatedSuffix = suffix.startsWith('d')
                ? 't${suffix.substring(1)}'
                : 'ç${suffix.substring(1)}';
            final assimilated = '$stem$assimilatedSuffix';
            if (TurkishMorphology.isKnownWord(assimilated)) {
              return (
                _matchCase(token, assimilated),
                'Ünsüz Benzeşmesi Tashihi',
              );
            }
          }
        }
      }
    }

    // KURAL I: Katman 2 & 3 Yerel AI (SymSpell + Char-Beam + Bağlamsal N-Gram) Tekil Kelime Tashihi
    if (lower.length >= 3 &&
        (!_isValidKnownTurkishWord(lower, lexicon) || isLowMlKitConf)) {
      final aiSingleFixed = OcrLocalAiLanguageModel.repairSingleWordInContext(
        word: lower,
        lexicon: lexicon,
        prevWord: prevWord,
        nextWord: nextWord,
        mlKitConfidence: mlKitConfidence,
      );
      if (aiSingleFixed != null && aiSingleFixed.correctedWord != lower) {
        return (
          _matchCase(token, aiSingleFixed.correctedWord),
          aiSingleFixed.explanation,
        );
      }
    }

    return null;
  }

  /// Kelimede kalın/ince ünlü uyumu çatışması (ör. kalın kökte 'i' veya ince kökte 'ı')
  /// yahut noktasız/çengelsiz harf ('c','s','g','o','u','i','ı') bulunduğunu denetler
  static bool _hasDiacriticOrHarmonySuspect(String lower) {
    final hasBack = RegExp(r'[aıou]').hasMatch(lower);
    final hasFront = RegExp(r'[eiöü]').hasMatch(lower);
    if (hasBack && hasFront) return true;
    if (RegExp(r'[csgoiuı]').hasMatch(lower)) return true;
    return false;
  }

  /// İki eşit uzunluktaki kelimenin yalnızca OCR nokta/çengel düşmesi veya 'l<->i<->ı' karışıklığı ile
  /// birbirinden ayrılıp ayrılmadığını denetler.
  static bool _isStrictOcrRestoration(String corrupted, String dictionaryTarget) {
    if (corrupted.length != dictionaryTarget.length) return false;
    int diffs = 0;
    for (int i = 0; i < corrupted.length; i++) {
      final a = corrupted[i];
      final b = dictionaryTarget[i];
      if (a == b) continue;
      diffs++;
      final allowed = (a == 'i' && (b == 'ı' || b == 'l' || b == 'î')) ||
          (a == 'ı' && (b == 'i' || b == 'l')) ||
          (a == 'l' && (b == 'i' || b == 'ı')) ||
          (a == 'c' && b == 'ç') ||
          (a == 's' && b == 'ş') ||
          (a == 'g' && b == 'ğ') ||
          (a == 'o' && b == 'ö') ||
          (a == 'u' && (b == 'ü' || b == 'û')) ||
          (a == 'a' && b == 'â');
      if (!allowed) return false;
    }
    return diffs >= 1 && diffs <= 3;
  }

  /// Kelimenin sadece OCR diyakritik/benzer harf dönüşümüyle (ı/i/l, c/ç, s/ş, g/ğ, o/ö, u/ü)
  /// sözlükteki geçerli bir kelimeye birebir eşleşip eşleşmediğini kontrol eder.
  static String? _findExactConfusionMatch(String lowerWord, Set<String> lexicon) {
    final skeleton = _ocrSkeleton(lowerWord);
    for (final dictWord in lexicon) {
      if (dictWord.length == lowerWord.length &&
          _ocrSkeleton(dictWord) == skeleton &&
          _isStrictOcrRestoration(lowerWord, dictWord)) {
        return dictWord;
      }
    }

    // Gövde + Türkçe çekim eki kontrolü (Ör: "hakıkatini" -> "hakikat" + "ini" -> "hakikatini", "dusunceler" -> "düşünceler", "bölümu" -> "bölümü", "mukaddimesı" -> "mukaddimesi")
    for (final suffix in _commonTurkishSuffixes) {
      if (lowerWord.length >= suffix.length + 3 && lowerWord.endsWith(suffix)) {
        final stem = lowerWord.substring(0, lowerWord.length - suffix.length);
        // 1. Kök zaten sözlükte var ama ek ünlü uyumuna aykırı nokta düşmesi yaşamışsa ("bölümu" -> "bölümü", "mukaddimesı" -> "mukaddimesi")
        if ((lexicon.contains(stem) || lexicon.contains(_stripCircumflex(stem))) &&
            _isFrontStemWithBackSuffix(stem, suffix)) {
          final harmonizedSuffix = _harmonizeSuffixToFront(suffix);
          if (harmonizedSuffix != suffix) {
            return '$stem$harmonizedSuffix';
          }
        }
        // 2. Kök OCR diyakritik kaybına uğramışsa ("hakıkatini" -> "hakikatini")
        final stemSkeleton = _ocrSkeleton(stem);
        for (final dictStem in lexicon) {
          if (dictStem.length == stem.length &&
              _ocrSkeleton(dictStem) == stemSkeleton &&
              _isStrictOcrRestoration(stem, dictStem)) {
            final cleanSuffix = _isFrontStemWithBackSuffix(dictStem, suffix)
                ? _harmonizeSuffixToFront(suffix)
                : suffix;
            return '$dictStem$cleanSuffix';
          }
        }
      }
    }

    return null;
  }

  /// Otomatik düzeltilemeyen ancak okuyucunun "Gözden Geçir" panelinde incelemesi gereken
  /// gerçek yapısal OCR anomalilerini tespit eder (geçerli Türkçe kelimelerde yanlış alarm üretmez).
  static String? _detectOcrSuspicionReason(String token) {
    if (token.length < 3) return null;
    if (token.contains("'") || token.contains('’')) return null;

    final lower = _toTurkishLower(token);
    if (_ignoredWords.contains(lower)) return null;

    final lexicon = _getLexicon();
    if (_isValidKnownTurkishWord(lower, lexicon)) return null;

    // 1. Hiç ünlü harf içermeyen 3+ harfli kelime
    if (!RegExp(r'[aeıioöuüâîû]', unicode: true).hasMatch(lower)) {
      return 'Ünlü harf düşmesi (vokalsiz dizilim)';
    }

    // 2. Yan yana 4+ ünsüz harf (Türkçede "türk", "sürç", "kürk", "şark", "garb" dışındaki anormal kümeler)
    if (RegExp(r'[bcçdfgğhjklmnprsştvyz]{4,}', unicode: true).hasMatch(lower) &&
        !lower.contains('türk') &&
        !lower.contains('garb') &&
        !lower.contains('şark')) {
      return 'Olağandışı ünsüz kümesi (olası OCR harf birleşmesi)';
    }

    // 3. Kelime başında Türkçede imkansız çift ünsüz (Ör: "tl...", "dl...", "bm...", "sr...", "ml...", "nl...")
    if (RegExp(r'^(?:tl|dl|bm|bn|dn|gn|kn|mn|nl|nr|rl|rm|rn|sb|sd|sg|sh|sl|sm|sn|sr|sv|sz|tb|td|tg|tk|tm|tn|tp|ts|tv|tz|vb|vd|vg|vk|vl|vm|vn|vr|vs|vt|vz)', unicode: true)
        .hasMatch(lower)) {
      return 'Kelime başı OCR harf kayması';
    }

    // 4. Aynı harfin 3+ kez yan yana tekrarı (Ör: "aaal", "iiin")
    if (RegExp(r'(.)\1{2,}', unicode: true).hasMatch(lower)) {
      return 'Tekrarlı OCR karakter gürültüsü';
    }

    // 5. Kelime içine sıkışmış rakam-harf karışımı
    if (RegExp(r'[a-zA-ZçğıöşüÇĞİÖŞÜâîûÂÎÛ]').hasMatch(token) &&
        RegExp(r'\d').hasMatch(token)) {
      return 'Kelime içi rakam-harf OCR karışıklığı';
    }

    // 6. Kelime ortasında karışık büyük harf kayması
    if (_hasHardOcrAnomaly(token)) {
      return 'Kelime içi büyük/küçük harf kayması';
    }

    // 7. Türkçede imkansız kelime sonu harf kaynaşmaları
    if (RegExp(r'(?:nm|nn|ln|lm|lr|rl|sl|tl|dl|ii|ıi|iı|uü|üu)$', unicode: true)
        .hasMatch(lower)) {
      return 'Kelime sonu OCR harf kaynaşması';
    }

    return null;
  }

  /// Kesme işaretli özel isim veya sayı eklerini ("Osmanlı'nm", "İslam'm",
  /// "Türkiye'dekı", "1923'de", "Avrupa'lan", "İstanbui'da") bağlamsal uyumla onarır.
  static (String, String)? _repairApostropheInflectedToken({
    required String token,
    required int aposIdx,
    String? prevWord,
    String? nextWord,
    double? mlKitConfidence,
  }) {
    final stemPart = token.substring(0, aposIdx);
    final aposChar = token[aposIdx];
    final suffixPart = token.substring(aposIdx + 1);
    if (stemPart.isEmpty || suffixPart.isEmpty) return null;

    final lowerSuf = _toTurkishLower(suffixPart);

    // 1. Sayı + kesme işareti ünsüz benzeşmesi ("1923'de" -> "1923'te", "1960'da" -> "1960'ta")
    if (RegExp(r'\d+$').hasMatch(stemPart)) {
      final lastDigit = stemPart[stemPart.length - 1];
      final lastTwo =
          stemPart.length >= 2 ? stemPart.substring(stemPart.length - 2) : '';
      final endsWithVoicelessNumber = lastDigit == '3' ||
          lastDigit == '4' ||
          lastDigit == '5' ||
          lastTwo == '40' ||
          lastTwo == '60' ||
          lastTwo == '70';
      var fixedSuf = switch (lowerSuf) {
        'dakı' => 'daki',
        'dekı' => 'deki',
        'takı' => 'taki',
        'tekı' => 'teki',
        _ => lowerSuf,
      };
      if (endsWithVoicelessNumber) {
        fixedSuf = switch (fixedSuf) {
          'da' => 'ta',
          'de' => 'te',
          'dan' => 'tan',
          'den' => 'ten',
          'daki' => 'taki',
          'deki' => 'teki',
          _ => fixedSuf,
        };
      }
      if (fixedSuf != lowerSuf) {
        return (
          '$stemPart$aposChar${_matchCase(suffixPart, fixedSuf)}',
          'Sayı Eki Benzeşme Tashihi',
        );
      }
      return null;
    }

    // 2. Gövde onarımı
    final lexicon = _getLexicon();
    var repairedStem = stemPart;
    String? stemRuleCategory;

    if (!stemPart.contains(RegExp(r"['’]"))) {
      final stemRepair = _tryAutomaticOcrWordRepair(
        stemPart,
        prevWord: prevWord,
        nextWord: nextWord,
        mlKitConfidence: mlKitConfidence,
      );
      if (stemRepair != null && stemRepair.$1 != stemPart) {
        repairedStem = stemRepair.$1;
        stemRuleCategory = stemRepair.$2;
      } else {
        final lowerStemRaw = _toTurkishLower(stemPart);
        if (!_isValidKnownTurkishWord(lowerStemRaw, lexicon) &&
            !_ignoredWords.contains(lowerStemRaw)) {
          final stemDecision = OcrCandidateGenerator.decide(stemPart);
          final best = stemDecision.best;
          if (stemDecision.isDecisive() &&
              best != null &&
              best.cost <= 0.38) {
            repairedStem = _matchCase(stemPart, best.word);
            stemRuleCategory = 'Kesme İşaretli Özel İsim Tashihi';
          }
        }
      }
    }

    // 3. Kesme sonrası ek onarımı
    final lowerStem = _toTurkishLower(repairedStem);
    final highVowel = _harmonizedHighVowelForStem(lowerStem);
    final stemEndsVowel = lowerStem.isNotEmpty &&
        'aeıioöuüâîû'.contains(lowerStem[lowerStem.length - 1]);

    String fixedSuf = lowerSuf;
    if (lowerSuf == 'nm' || lowerSuf == 'nn') {
      fixedSuf = '${stemEndsVowel ? 'n' : ''}${highVowel}n';
    } else if (lowerSuf == 'm' && !stemEndsVowel) {
      fixedSuf = '${highVowel}n';
    } else {
      fixedSuf = switch (lowerSuf) {
        'dekı' => 'deki',
        'dakı' => 'daki',
        'ndekı' => 'ndeki',
        'ndakı' => 'ndaki',
        'tekı' => 'teki',
        'takı' => 'taki',
        'lan' => 'ları',
        'len' => 'leri',
        'larm' => 'ların',
        'lerm' => 'lerin',
        'larn' => 'ların',
        'lern' => 'lerin',
        _ => lowerSuf,
      };
    }

    final suffixModified = fixedSuf != lowerSuf;
    final stemModified = repairedStem != stemPart;
    if (!suffixModified && !stemModified) return null;

    final finalSuffix =
        suffixModified ? _matchCase(suffixPart, fixedSuf) : suffixPart;
    final category = suffixModified
        ? 'Kesme İşaretli Ek Tashihi'
        : (stemRuleCategory ?? 'Kesme İşaretli Özel İsim Tashihi');
    return ('$repairedStem$aposChar$finalSuffix', category);
  }

  static String _harmonizedHighVowelForStem(String lowerStem) {
    const palatalExceptions = <String>{
      'kemal', 'hilal', 'cemal', 'hayal', 'hal', 'istiklal', 'istihlal',
      'saat', 'dikkat', 'hakikat', 'şefkat', 'alkol', 'rol', 'gol',
      'sembol', 'mahsul', 'usul', 'kabul', 'kalp', 'harf', 'tarik',
    };
    final plain = _stripCircumflex(lowerStem);
    final isPalatalException = palatalExceptions.contains(plain);

    for (int i = lowerStem.length - 1; i >= 0; i--) {
      final ch = lowerStem[i];
      switch (ch) {
        case 'a':
        case 'ı':
        case 'â':
          return isPalatalException ? 'i' : 'ı';
        case 'o':
        case 'u':
        case 'û':
          return isPalatalException ? 'ü' : 'u';
        case 'e':
        case 'i':
        case 'î':
          return 'i';
        case 'ö':
        case 'ü':
          return 'ü';
      }
    }
    return 'ı';
  }

  static bool _hasHardOcrAnomaly(String token) {
    return RegExp(r'[0-9]').hasMatch(token) ||
        (token.length >= 3 &&
            token != token.toUpperCase() &&
            RegExp(r'^[A-ZÇĞİÖŞÜÂÎÛ]?[a-zçğıöşüâîû]+[A-ZÇĞİÖŞÜÂÎÛ]').hasMatch(token));
  }

  /// Sözlükten OCR ağırlıklı Damerau-Levenshtein mesafesine göre en yakın kelime adaylarını döndürür
  static List<String> _findClosestLexiconCandidates(
    String word, {
    int maxResults = 4,
    double maxDistance = 1.65,
  }) {
    final lower = _toTurkishLower(_stripOuterPunctuation(word));
    if (lower.length < 3 || lower.length > 48) return const [];

    final lexicon = _getLexicon();
    final scored = <(String, double)>[];

    // 1. Tam kelime adayları
    for (final dictWord in lexicon) {
      if ((dictWord.length - lower.length).abs() > 2) continue;
      final d = _ocrWeightedDistance(lower, dictWord);
      if (d > 0.0 && d <= maxDistance) {
        scored.add((_matchCase(word, dictWord), d));
      }
    }

    // 2. Kök + Türkçe çekim eki adayları
    for (final suffix in _commonTurkishSuffixes) {
      if (lower.length >= suffix.length + 3 && lower.endsWith(suffix)) {
        final stem = lower.substring(0, lower.length - suffix.length);
        for (final dictStem in lexicon) {
          if ((dictStem.length - stem.length).abs() > 1) continue;
          final d = _ocrWeightedDistance(stem, dictStem);
          if (d > 0.0 && d <= 1.15) {
            final candidateFull = _matchCase(word, '$dictStem$suffix');
            scored.add((candidateFull, d + 0.05));
          }
        }
      }
    }

    scored.sort((a, b) => a.$2.compareTo(b.$2));

    final unique = <String>[];
    for (final item in scored) {
      if (!unique.any((u) => _toTurkishLower(u) == _toTurkishLower(item.$1))) {
        unique.add(item.$1);
        if (unique.length >= maxResults) break;
      }
    }
    return unique;
  }

  /// OCR görsel benzerlik ağırlıklı düzenleme mesafesi (Weighted Levenshtein)
  static double _ocrWeightedDistance(String s1, String s2) {
    if (s1 == s2) return 0.0;
    final len1 = s1.length;
    final len2 = s2.length;
    if ((len1 - len2).abs() > 2) return 99.0;

    final dp = List.generate(len1 + 1, (_) => List<double>.filled(len2 + 1, 0.0));
    for (int i = 0; i <= len1; i++) {
      dp[i][0] = i.toDouble();
    }
    for (int j = 0; j <= len2; j++) {
      dp[0][j] = j.toDouble();
    }

    for (int i = 1; i <= len1; i++) {
      for (int j = 1; j <= len2; j++) {
        final c1 = s1[i - 1];
        final c2 = s2[j - 1];
        final subCost = c1 == c2 ? 0.0 : _ocrCharSubstitutionCost(c1, c2);

        var best = dp[i - 1][j - 1] + subCost;
        final del = dp[i - 1][j] + 0.90;
        final ins = dp[i][j - 1] + 0.90;
        if (del < best) best = del;
        if (ins < best) best = ins;

        dp[i][j] = best;
      }
    }

    return dp[len1][len2];
  }

  /// OCR'da birbirine çok sık karışan harf çiftleri için düşük ceza puanı (0.35 - 0.55)
  static double _ocrCharSubstitutionCost(String a, String b) {
    if (a == b) return 0.0;
    const lowCostGroups = <String>[
      'ıil1!|',
      'cçae',
      'sş5',
      'gğ',
      'oö0',
      'uüû',
      'aâe',
      'iîı',
      'mn',
      'bd',
      'vy',
      'hk',
      'tl',
    ];
    for (final group in lowCostGroups) {
      if (group.contains(a) && group.contains(b)) {
        return 0.42;
      }
    }
    return 1.10;
  }

  static String _ocrSkeleton(String word) {
    return word
        .replaceAll(RegExp(r'[ıiîl1]'), 'i')
        .replaceAll(RegExp(r'[cç]'), 'c')
        .replaceAll(RegExp(r'[sş]'), 's')
        .replaceAll(RegExp(r'[gğ]'), 'g')
        .replaceAll(RegExp(r'[oö0]'), 'o')
        .replaceAll(RegExp(r'[uüû]'), 'u')
        .replaceAll(RegExp(r'[aâ]'), 'a');
  }

  /// İki metin arasındaki kelime bazlı OCR düzeltme farklarını çıkarır
  static List<OcrCorrectionItem> _extractWordDiffs({
    required String beforeText,
    required String afterText,
    required int blockIndex,
    required String ruleCategory,
  }) {
    final wordRegex = RegExp(r"[^\s,.;:!?“”«»()\[\]]+", unicode: true);
    final beforeWords = wordRegex
        .allMatches(beforeText)
        .map((m) => _stripOuterPunctuation(m.group(0)!))
        .where((w) => w.length >= 2)
        .toList();
    final afterWords = wordRegex
        .allMatches(afterText)
        .map((m) => _stripOuterPunctuation(m.group(0)!))
        .where((w) => w.length >= 2)
        .toList();

    final afterSet = afterWords.toSet();
    final beforeSet = beforeWords.toSet();
    final items = <OcrCorrectionItem>[];

    int searchStart = 0;
    for (int i = 0; i < beforeWords.length; i++) {
      final bw = beforeWords[i];
      if (afterSet.contains(bw)) continue;

      // afterWords içinde yakın indekste benzer kelimenin düzeltilmiş halini bul
      final minJ = (searchStart - 4).clamp(0, afterWords.length);
      final maxJ = (i + 8).clamp(0, afterWords.length);

      String? matchedAfter;
      for (int j = minJ; j < maxJ; j++) {
        final aw = afterWords[j];
        if (beforeSet.contains(aw)) continue;
        final dist = _ocrWeightedDistance(_toTurkishLower(bw), _toTurkishLower(aw));
        if (dist > 0.0 && dist <= 2.4) {
          matchedAfter = aw;
          searchStart = j + 1;
          break;
        }
      }

      if (matchedAfter != null && matchedAfter != bw) {
        final pos = afterText.indexOf(matchedAfter);
        final snippet = pos >= 0
            ? _extractContextSnippet(afterText, pos, pos + matchedAfter.length)
            : matchedAfter;
        items.add(OcrCorrectionItem(
          id: 'diff_${blockIndex}_$i',
          originalWord: bw,
          correctedWord: matchedAfter,
          contextSnippet: snippet,
          blockIndex: blockIndex,
          ruleCategory: ruleCategory,
          confidence: 0.96,
        ));
      }
    }

    return items;
  }

  static String _extractContextSnippet(String fullText, int start, int end) {
    final left = (start - 32).clamp(0, fullText.length);
    final right = (end + 32).clamp(0, fullText.length);
    final prefix = left > 0 ? '...' : '';
    final suffix = right < fullText.length ? '...' : '';
    final rawSnippet = fullText.substring(left, right).replaceAll('\n', ' ').trim();
    return '$prefix$rawSnippet$suffix';
  }

  static const Set<String> _invalidMorphologicalWords = {
    'bilimdiği',
    'bilimdiğini',
    'bilimdikleri',
    'edinlerin',
    'edinleri',
    'edinler',
    'gelence',
    'askeridi',
    'ibnden',
    'halaun',
    'artzona',
    'göıiirsünüz',
    'göriirsünüz',
    'onlan',
    'bunlan',
    'şunlan',
    'yansını',
    'yansına',
    'yansında',
    'yansından',
    'üzennde',
    'üzenne',
    'üzennden',
    'birbinne',
    'birbinni',
    'birbinnden',
    'kendilenni',
    'kendilenne',
    'kendilennin',
    'kendilen',
    'bazılan',
    'başkalan',
    'aynca',
    'aynntı',
    'başan',
    'başanlı',
    'başansız',
    'cumhunyet',
    'hürnyet',
    'hınstiyan',
  };

  static bool _isValidKnownTurkishWord(String lowerWord, Set<String> lexicon) {
    if (_invalidMorphologicalWords.contains(lowerWord)) return false;
    if (OcrLocalAiLanguageModel.isValidSingularLanLenWord(lowerWord)) {
      return true;
    }
    if (OcrLocalAiLanguageModel.isCorruptedPluralLanLen(lowerWord, lexicon)) {
      return false;
    }

    // Zemberek tabanlı tam biçimbilim doğrulaması (31.000+ lemma, ek dizilimi ve ses uyumu denetimi)
    if (TurkishMorphology.isKnownWord(lowerWord)) return true;

    final plain = _stripCircumflex(lowerWord);
    if (lexicon.contains(lowerWord) || lexicon.contains(plain)) return true;

    const verbOnlyParticipleSuffixes = <String>{
      'dığı', 'diği', 'duğu', 'düğü', 'tığı', 'tiği', 'tuğu', 'tüğü',
      'dığını', 'diğini', 'duğunu', 'düğünü', 'tığını', 'tiğini', 'tuğunu', 'tüğünü',
      'dığına', 'diğine', 'duğuna', 'düğüne',
      'dıkları', 'dikleri', 'dukları', 'dükleri', 'tıkları', 'tikleri', 'tukları', 'tükleri',
    };
    const nominalImStems = <String>{
      'bilim', 'bölüm', 'çözüm', 'durum', 'kurum', 'ölüm', 'yönetim',
      'üretim', 'eğitim', 'seçim', 'biçim', 'kısım', 'takım', 'adım',
      'yardım', 'bakım', 'tarım', 'yatırım', 'kavram', 'anlam', 'toplam',
      'sistem', 'dönem', 'yöntem',
    };

    for (final suffix in _commonTurkishSuffixes) {
      if (lowerWord.length >= suffix.length + 2 && lowerWord.endsWith(suffix)) {
        final stem = lowerWord.substring(0, lowerWord.length - suffix.length);
        if (stem.isNotEmpty &&
            'çfhkpsşt'.contains(stem[stem.length - 1]) &&
            (suffix.startsWith('d') || suffix.startsWith('c'))) {
          continue;
        }
        // İnce ünlülü bir Türkçe kök ('bölüm', 'mukaddime', 'devlet') kalın ünlülü bir ek ('-u', '-sı', '-lar') alamaz
        if (_isFrontStemWithBackSuffix(stem, suffix)) {
          continue;
        }
        if (verbOnlyParticipleSuffixes.contains(suffix) &&
            nominalImStems.contains(stem)) {
          continue;
        }
        final stemPlain = _stripCircumflex(stem);
        if (lexicon.contains(stem) || lexicon.contains(stemPlain)) {
          return true;
        }
        // Ünsüz yumuşaması geri dönüşümü (kitab -> kitap, maksad -> maksat, aheng -> ahenk, varlığ -> varlık)
        if (stem.endsWith('b')) {
          final pStem = '${stem.substring(0, stem.length - 1)}p';
          if (lexicon.contains(pStem) || lexicon.contains(_stripCircumflex(pStem))) return true;
        } else if (stem.endsWith('c')) {
          final cStem = '${stem.substring(0, stem.length - 1)}ç';
          if (lexicon.contains(cStem) || lexicon.contains(_stripCircumflex(cStem))) return true;
        } else if (stem.endsWith('d')) {
          final tStem = '${stem.substring(0, stem.length - 1)}t';
          if (lexicon.contains(tStem) || lexicon.contains(_stripCircumflex(tStem))) return true;
        } else if (stem.endsWith('ğ')) {
          final kStem = '${stem.substring(0, stem.length - 1)}k';
          if (lexicon.contains(kStem) || lexicon.contains(_stripCircumflex(kStem))) return true;
        }
      }
    }

    return false;
  }

  /// Kökün son ünlüsü ince ünlü (e, i, ö, ü) iken ekin kalın ünlü (a, ı, o, u) içerip içermediğini denetler
  static bool _isFrontStemWithBackSuffix(String stem, String suffix) {
    if (_hasBackVowel(stem)) return false;
    return RegExp(r'[aıou]').hasMatch(suffix);
  }

  /// İnce ünlülü köke yanlışlıkla eklenmiş kalın ünlülü eki ünlü uyumuna göre inceye dönüştürür
  static String _harmonizeSuffixToFront(String suffix) {
    return suffix
        .replaceAll('ı', 'i')
        .replaceAll('u', 'ü')
        .replaceAll('a', 'e')
        .replaceAll('o', 'ö');
  }

  static Set<String> _getLexicon() {
    if (_cachedLexicon != null) return _cachedLexicon!;
    final set = <String>{
      ..._coreTurkishAndClassicalLexicon,
      ...OcrLexiconDatabase.extendedTurkishAndOttomanStems,
    };
    // DictionaryService içindeki tüm klasik/felsefi/edebi kelimeleri de dahil et
    try {
      final dictEntries = DictionaryService().search('');
      for (final e in dictEntries) {
        set.add(_toTurkishLower(e.word));
        set.add(_stripCircumflex(_toTurkishLower(e.word)));
      }
    } catch (e) {
      debugPrint('OcrProofreaderEngine lexicon warning: $e');
    }

    final withPlain = <String>{};
    for (final w in set) {
      withPlain.add(w);
      withPlain.add(_stripCircumflex(w));
      if (w.length >= 5 && (w.endsWith('mak') || w.endsWith('mek'))) {
        final verbRoot = w.substring(0, w.length - 3);
        if (!verbRoot.endsWith('lan') &&
            !verbRoot.endsWith('len') &&
            verbRoot != 'yansı') {
          withPlain.add(verbRoot);
          withPlain.add(_stripCircumflex(verbRoot));
        }
      }
    }
    _cachedLexicon = withPlain;
    TurkishMorphology.registerExtraWords(withPlain);
    TurkishMorphology.registerExtraWords(OcrLexiconDatabase.extendedTurkishAndOttomanStems);
    return _cachedLexicon!;
  }

  /// Cümle ortasında büyük harfle başlayan (muhtemel özel isim) kelimeyi tespit eder.
  static bool _isCapitalizedMidSentence(String text, int start, String token) {
    if (token.isEmpty || !RegExp(r'^[A-ZÇĞİÖŞÜÂÎÛ]').hasMatch(token)) return false;
    // Tamamı büyük harfli başlık kelimeleri özel isim sayılmaz
    if (token.length > 1 && token == token.toUpperCase()) return false;
    int i = start - 1;
    while (i >= 0 && (text[i] == ' ' || text[i] == '\t')) {
      i--;
    }
    if (i < 0) return false;
    final prev = text[i];
    return !RegExp(r'[.!?:;\n“"«(\-–—]').hasMatch(prev);
  }

  static String _stripOuterPunctuation(String input) {
    return input.replaceAll(
      RegExp(r'^[^\p{L}\p{N}]+|[^\p{L}\p{N}]+$', unicode: true),
      '',
    );
  }

  static String _toTurkishLower(String input) {
    return input
        .replaceAll('İ', 'i')
        .replaceAll('I', 'ı')
        .replaceAll('Ğ', 'ğ')
        .replaceAll('Ü', 'ü')
        .replaceAll('Ş', 'ş')
        .replaceAll('Ö', 'ö')
        .replaceAll('Ç', 'ç')
        .replaceAll('Â', 'â')
        .replaceAll('Î', 'î')
        .replaceAll('Û', 'û')
        .toLowerCase();
  }

  static String _toTurkishUpperFirst(String input) {
    if (input.isEmpty) return input;
    final first = input[0];
    final upperFirst = switch (first) {
      'i' => 'İ',
      'ı' => 'I',
      'ğ' => 'Ğ',
      'ü' => 'Ü',
      'ş' => 'Ş',
      'ö' => 'Ö',
      'ç' => 'Ç',
      'â' => 'Â',
      'î' => 'Î',
      'û' => 'Û',
      _ => first.toUpperCase(),
    };
    return '$upperFirst${input.substring(1)}';
  }

  static String _normalizeMixedCase(String token) {
    if (token.isEmpty) return token;
    final isFirstUpper = RegExp(r'^[A-ZÇĞİÖŞÜÂÎÛ]').hasMatch(token);
    final lowered = _toTurkishLower(token);
    return isFirstUpper ? _toTurkishUpperFirst(lowered) : lowered;
  }

  static String _matchCase(String source, String target) {
    if (source.isEmpty || target.isEmpty) return target;
    if (source == source.toUpperCase() && source.length > 1) {
      return target
          .replaceAll('i', 'İ')
          .replaceAll('ı', 'I')
          .toUpperCase();
    }
    if (RegExp(r'^[A-ZÇĞİÖŞÜÂÎÛ]').hasMatch(source)) {
      return _toTurkishUpperFirst(_toTurkishLower(target));
    }
    return _toTurkishLower(target);
  }

  static String _stripCircumflex(String s) {
    return s
        .replaceAll('â', 'a')
        .replaceAll('î', 'i')
        .replaceAll('û', 'u');
  }

  static bool _hasBackVowel(String word) {
    final lower = _toTurkishLower(word);
    for (int i = lower.length - 1; i >= 0; i--) {
      final ch = lower[i];
      if ('aıouâû'.contains(ch)) return true;
      if ('eiöüî'.contains(ch)) return false;
    }
    return true;
  }

  static const Set<String> _legitimateRnWords = {
    'örnek',
    'örnekler',
    'örneği',
    'zurna',
    'burnu',
    'karnı',
    'karne',
    'kurna',
    'turna',
    'korna',
    'vernik',
    'modern',
  };

  static const Set<String> _loanwordInitialClusters = {
    'pr',
    'pl',
    'ps',
    'kr',
    'kl',
    'gr',
    'gl',
    'tr',
    'fr',
    'fl',
    'sp',
    'st',
    'sk',
    'dr',
    'br',
    'bl',
  };

  static const List<String> _commonTurkishSuffixes = [
    'larından',
    'lerinden',
    'larının',
    'lerinin',
    'larında',
    'lerinde',
    'larına',
    'lerine',
    'larını',
    'lerini',
    'larıyla',
    'leriyle',
    'larıyle',
    'maktadır',
    'mektedir',
    'mışlardır',
    'mişlerdir',
    'muşlardır',
    'müşlerdir',
    'acaktır',
    'ecektir',
    'acağız',
    'eceğiz',
    'acağını',
    'eceğini',
    'acağı',
    'eceği',
    'larsak',
    'lersek',
    'arsak',
    'ersek',
    'ıyor',
    'iyor',
    'uyor',
    'üyor',
    'yordu',
    'yoruz',
    'yorlar',
    'malıdır',
    'melidir',
    'dıkları',
    'dikleri',
    'dukları',
    'dükleri',
    'tıkları',
    'tikleri',
    'tukları',
    'tükleri',
    'dığını',
    'diğini',
    'duğunu',
    'düğünü',
    'tığını',
    'tiğini',
    'tuğunu',
    'tüğünü',
    'dığına',
    'diğine',
    'duğuna',
    'düğüne',
    'dığı',
    'diği',
    'duğu',
    'düğü',
    'tığı',
    'tiği',
    'tuğu',
    'tüğü',
    'lığı',
    'liği',
    'luğu',
    'lüğü',
    'lığın',
    'liğin',
    'luğun',
    'lüğün',
    'lıkla',
    'likle',
    'lukla',
    'lükle',
    'lıktan',
    'likten',
    'luktan',
    'lükten',
    'lardan',
    'lerden',
    'larda',
    'lerde',
    'ların',
    'lerin',
    'larla',
    'lerle',
    'lardır',
    'lerdir',
    'ları',
    'leri',
    'lara',
    'lere',
    'lar',
    'ler',
    'ndan',
    'nden',
    'larında',
    'lerinde',
    'larından',
    'lerinden',
    'sına',
    'sine',
    'sını',
    'sini',
    'sında',
    'sinde',
    'sından',
    'sinden',
    'sıyla',
    'siyle',
    'ında',
    'inde',
    'unda',
    'ünde',
    'ından',
    'inden',
    'undan',
    'ünden',
    'ına',
    'ine',
    'una',
    'üne',
    'ını',
    'ini',
    'unu',
    'ünü',
    'nda',
    'nde',
    'nın',
    'nin',
    'nun',
    'nün',
    'dan',
    'den',
    'tan',
    'ten',
    'dır',
    'dir',
    'dur',
    'dür',
    'tır',
    'tir',
    'tur',
    'tür',
    'mış',
    'miş',
    'muş',
    'müş',
    'mak',
    'mek',
    'acak',
    'ecek',
    'yor',
    'lık',
    'lik',
    'luk',
    'lük',
    'sız',
    'siz',
    'suz',
    'süz',
    'daki',
    'deki',
    'taki',
    'teki',
    'mız',
    'miz',
    'muz',
    'müz',
    'nız',
    'niz',
    'nuz',
    'nüz',
    'yle',
    'yla',
    'da',
    'de',
    'ta',
    'te',
    'la',
    'le',
    'ın',
    'in',
    'un',
    'ün',
    'na',
    'ne',
    'nı',
    'ni',
    'nu',
    'nü',
    'ya',
    'ye',
    'yı',
    'yi',
    'yu',
    'yü',
    'sı',
    'si',
    'su',
    'sü',
    'dı',
    'di',
    'du',
    'dü',
    'tı',
    'ti',
    'tu',
    'tü',
    'cı',
    'ci',
    'cu',
    'cü',
    'çı',
    'çi',
    'çu',
    'çü',
    'lı',
    'li',
    'lu',
    'lü',
    'ca',
    'ce',
    'ça',
    'çe',
    'a',
    'e',
    'ı',
    'i',
    'u',
    'ü',
  ];

  static const Set<String> _coreTurkishAndClassicalLexicon = {
    'acaba', 'açık', 'açıkça', 'açıklama', 'adalet', 'adam', 'adab', 'adet', 'adım', 'adeta',
    'affedici', 'ağır', 'ağlamak', 'ahenk', 'ahlak', 'ahlâk', 'ahlâkî', 'ahval', 'aidiyet', 'aile',
    'ait', 'âit', 'akıl', 'akıllı', 'akıbet', 'aklen', 'akış', 'aksine', 'alakalı', 'alan',
    'alâka', 'alem', 'âlem', 'alev', 'alevli', 'alim', 'âlim', 'allah', 'almak', 'alt',
    'altın', 'ama', 'amaç', 'amel', 'ameli', 'amme', 'âmme', 'an', 'ana', 'ancak',
    'anlamak', 'anlam', 'anlamlı', 'anlatmak', 'anlayış', 'anarşi', 'arap', 'arapça', 'ara', 'arası',
    'arayış', 'arazi', 'araştırma', 'arkadaş', 'artık', 'arzu', 'asabiyet', 'asır', 'asıl', 'asil', 'asker',
    'askerî', 'asla', 'aşama', 'aşağı', 'aşırı', 'aşiret', 'aşk', 'aşmak', 'ata', 'atmak',
    'avrupa', 'ay', 'ayak', 'ayet', 'âyet', 'ayna', 'aynı', 'ayrı', 'ayrılık', 'ayrıntı',
    'az', 'azamet', 'azametli', 'azim', 'bab', 'baba', 'bağ', 'bağış', 'bağlı', 'bağımsız',
    'bahar', 'bahis', 'bahşetmek', 'bakış', 'bakmak', 'balkan', 'baş', 'başarı', 'başbuğ', 'başka',
    'başkan', 'başkanlık', 'başlamak', 'başlangıç', 'başlık', 'batı', 'batın', 'bayağı', 'bazen', 'bazı',
    'bedbaht', 'beden', 'bedevi', 'bedir', 'beklemek', 'belagat', 'belge', 'belirli', 'belki', 'belli',
    'ben', 'benzer', 'beraber', 'berat', 'bereket', 'berrak', 'beş', 'beşer', 'beşerî', 'beyan',
    'beyit', 'beylik', 'bırakmak', 'biçim', 'bilakis', 'bile', 'bilgi', 'bilgelik', 'bilgin', 'bilhassa',
    'bilim', 'bilmek', 'bina', 'bir', 'biraz', 'birbiri', 'birçok', 'birey', 'birer', 'birinci',
    'birlik', 'birlikte', 'bizzat', 'boş', 'boşluk', 'boyunca', 'bozulma', 'bölge', 'bölüm', 'böyle',
    'böylece', 'bu', 'bugün', 'bugünkü', 'bulmak', 'bulunmak', 'bunalmak', 'bununla', 'bura', 'burada',
    'burhan', 'buyruk', 'buyurmak', 'bünye', 'bütün', 'büyük', 'büyükbaba', 'büyüklük', 'cahil', 'câhil',
    'cahiliyet', 'câhiliyet', 'cami', 'can', 'canlı', 'cedel', 'cehalet', 'cehd', 'cemiyet', 'cennet',
    'cesaret', 'cevap', 'ceza', 'cihan', 'cihangir', 'cihangirlik', 'cihat', 'cilt', 'civar', 'coğrafi',
    'coğrafî', 'coğrafya', 'cömert', 'cumhuriyet', 'cümle', 'çaba', 'çağ', 'çağdaş', 'çalışma', 'çalışmak',
    'çare', 'çatışma', 'çelik', 'çerçeve', 'çeşit', 'çetin', 'çevre', 'çıkar', 'çıkarmak', 'çıkmak',
    'çınar', 'çiçek', 'çizgi', 'çocuk', 'çoğu', 'çoğul', 'çok', 'çözmek', 'çözüm', 'çünkü',
    'da', 'daha', 'dahi', 'dahil', 'daima', 'dâima', 'dair', 'dakika', 'dal', 'damga',
    'dar', 'darüşşifa', 'dava', 'dâvâ', 'davranış', 'dayanışma', 'dayanmak', 'de', 'defa', 'defter',
    'değer', 'değerli', 'değil', 'değişim', 'değişmek', 'delil', 'demek', 'demir', 'deneme', 'denge',
    'deniz', 'derece', 'dergi', 'derin', 'derinlik', 'derkenar', 'ders', 'dert', 'devam', 'devir',
    'devlet', 'devletçik', 'devirmek', 'dış', 'dışarı', 'diğer', 'dikkat', 'dil', 'din', 'dîn',
    'dini', 'dinî', 'dinlemek', 'dipnot', 'dirayet', 'diri', 'divan', 'diyar', 'diyalektik', 'dize',
    'doğa', 'doğal', 'doğru', 'doğruluk', 'doğuş', 'doğu', 'dokuz', 'dolayı', 'dolu', 'dost',
    'dönem', 'dönmek', 'dönüşüm', 'dört', 'dua', 'duygu', 'duymak', 'duyu', 'durak', 'durmak',
    'durum', 'dün', 'dünkü', 'dünya', 'dünyâ', 'dürtü', 'düşman', 'düşmanlık', 'düşmek', 'düşünce',
    'düşünmek', 'düşünür', 'düzen', 'ebedi', 'ebedî', 'ebru', 'edeb', 'edebi', 'edebî', 'edebiyat',
    'edep', 'efendi', 'eğer', 'eğitim', 'eğilim', 'ehliyet', 'ek', 'eklemek', 'ekol', 'eksik',
    'el', 'elbette', 'eleştiri', 'elli', 'emanet', 'emek', 'emin', 'emir', 'emniyet', 'en',
    'endişe', 'engizisyon', 'enteresan', 'erdem', 'erken', 'ermek', 'esas', 'eser', 'esir', 'eski',
    'eskiden', 'esna', 'estetik', 'eş', 'eşit', 'eşya', 'etik', 'etki', 'etkili', 'etmek',
    'etraf', 'ev', 'evet', 'evre', 'evren', 'evvel', 'ey', 'eylem', 'eylül', 'ezeli',
    'ezelî', 'fakat', 'fakir', 'fark', 'farklı', 'farz', 'fasıl', 'fasih', 'fatih', 'fayda',
    'faydalı', 'fazilet', 'fazla', 'fedakarlık', 'felaket', 'felsefe', 'felsefi', 'felsefî', 'fen', 'feraset',
    'ferman', 'fert', 'feryat', 'feryad', 'fesahat', 'fethetmek', 'fetih', 'feth', 'fıkıh', 'fırsat',
    'fırtına', 'fırtınalı', 'fıtrat', 'fiil', 'fikir', 'fikrî', 'film', 'filozof', 'firkat', 'form',
    'frenkçe', 'garip', 'gaye', 'gayret', 'gazel', 'gazi', 'gâzi', 'gece', 'geç', 'geçen',
    'geçici', 'geçmiş', 'geçmek', 'gelenek', 'gelecek', 'gelişme', 'gelmek', 'genç', 'gençlik', 'genel',
    'geniş', 'gerçek', 'gerçeklik', 'gerek', 'gerekli', 'gerekmek', 'geri', 'getirmek', 'gezmek', 'gibi',
    'gidermek', 'giriş', 'girmek', 'gitmek', 'gizli', 'gök', 'gölge', 'gönül', 'göndermek', 'göre',
    'görev', 'görmek', 'görgü', 'görünüm', 'görüş', 'göstermek', 'göz', 'gözlem', 'güç', 'güçlü',
    'gül', 'gümüş', 'gün', 'gündelik', 'güneş', 'güven', 'güvenilir', 'güvenmek', 'güzel', 'güzellik',
    'haber', 'hacim', 'hadis', 'hadîs', 'hadise', 'hâdise', 'hafıza', 'hafif', 'hak', 'hakan',
    'hakikat', 'hakiki', 'hakim', 'hâkim', 'haklı', 'hal', 'hâl', 'hala', 'halef', 'halife',
    'halis', 'hâlis', 'halk', 'halka', 'hamam', 'hangi', 'hani', 'harap', 'harf', 'hariç',
    'harita', 'hareket', 'harcamak', 'hasret', 'hasta', 'hastalık', 'haşiye', 'haşmet', 'hat', 'hata',
    'hatıra', 'hatta', 'hattâ', 'hattat', 'hava', 'hayal', 'hayat', 'hayır', 'hayran', 'hayret',
    'hayvan', 'hazır', 'hazine', 'hedef', 'hekim', 'hem', 'hemen', 'henüz', 'hep', 'hepsi',
    'her', 'herhalde', 'herkes', 'hesap', 'heybet', 'heyecan', 'hız', 'hızlı', 'hiç', 'hiçbir',
    'hicran', 'hikaye', 'hikmet', 'hilafet', 'hilâfet', 'hilm', 'himaye', 'his', 'hissetmek', 'hitap',
    'hıyanet', 'hiyânet', 'hizmet', 'hoca', 'hoş', 'hoşgörü', 'hukuk', 'hukuki', 'hukukî', 'hukûkî',
    'hukukçu', 'husus', 'hususi', 'huzur', 'hüküm', 'hükümdar', 'hükümet', 'hür', 'hürriyet', 'hüsn',
    'hüviyet', 'hüzün', 'ıslah', 'ışık', 'ibadet', 'ibare', 'ibaret', 'ibret', 'icaz', 'icazet',
    'icap', 'icma', 'icmâ', 'icra', 'iç', 'içeri', 'içerden', 'için', 'içinde', 'içtimai',
    'içtimâî', 'idare', 'idâre', 'idareci', 'idari', 'idârî', 'iddia', 'ideal', 'idealist', 'idrak',
    'ifade', 'ifâde', 'iffet', 'ifrat', 'ihsan', 'ihtilaf', 'ihtilal', 'ihtilâl', 'ihtimal', 'ihtiva',
    'ihtiyaç', 'ihtiyar', 'iki', 'ikinci', 'iklim', 'ikna', 'ikram', 'iktisadi', 'iktisadî', 'iktisat',
    'ilaç', 'ilahi', 'ilâhî', 'ilahiyat', 'ilan', 'ilave', 'ile', 'ileri', 'ilerlemek', 'iletişim',
    'ilgi', 'ilgili', 'ilham', 'ilim', 'ilke', 'ilk', 'ilmi', 'ilmî', 'imam', 'imamet',
    'imâmet', 'iman', 'imaret', 'imge', 'imkan', 'imkân', 'imparator', 'imparatorluk', 'imtihan', 'imtiyaz',
    'imza', 'inanç', 'inanmak', 'ince', 'incelemek', 'incelik', 'inci', 'indeks', 'inkılap', 'inkılâp',
    'inkılâb', 'insan', 'insani', 'insanlık', 'inşa', 'inziva', 'ip', 'irade', 'irâde', 'irfan',
    'ise', 'isim', 'islam', 'islâm', 'islâmî', 'ispat', 'istanbul', 'istek', 'istemek', 'istiare',
    'istifade', 'istiklal', 'istiklâl', 'istikrar', 'istinsah', 'iş', 'işaret', 'işbu', 'işitmek', 'işlemek',
    'işte', 'iştikak', 'itaat', 'itibar', 'itibarla', 'itibariyle', 'itidal', 'ithaf', 'itimat', 'ittifak',
    'iyi', 'iyilik', 'iz', 'izah', 'izahat', 'izin', 'izlemek', 'kabiliyet', 'kabul', 'kabûl',
    'kaç', 'kadar', 'kader', 'kadı', 'kadim', 'kadın', 'kağıt', 'kaide', 'kainat', 'kalabalık',
    'kalem', 'kalıcı', 'kalıp', 'kalite', 'kalkmak', 'kalmak', 'kalp', 'kamu', 'kamus', 'kan',
    'kanaat', 'kanat', 'kanıt', 'kanun', 'kapak', 'kapalı', 'kapatmak', 'kapı', 'kaplamak', 'kapsam',
    'kar', 'kara', 'karar', 'kardeş', 'karşı', 'karşılık', 'karşıt', 'karışık', 'kaside', 'kasıt',
    'kat', 'kategori', 'katip', 'kâtip', 'katkı', 'katman', 'katmak', 'kavim', 'kavis', 'kavram',
    'kavramak', 'kavrayış', 'kavuşmak', 'kaybetmek', 'kaydetmek', 'kaygı', 'kayıp', 'kayıt', 'kaynak', 'kazanmak',
    'kelam', 'kelâm', 'kelime', 'kemal', 'kemirmek', 'kenar', 'kendi', 'kent', 'kere', 'kerem',
    'kesin', 'kesit', 'keşif', 'ketebe', 'kıble', 'kılıç', 'kılmak', 'kısa', 'kısım', 'kıssa',
    'kış', 'kıta', 'kıymet', 'kıymetli', 'kıyas', 'ki', 'kibar', 'kibir', 'kim', 'kimse',
    'kin', 'kinaye', 'kişi', 'kitabe', 'kitap', 'kitaplık', 'klasik', 'kol', 'kolay', 'komşu',
    'konu', 'konum', 'konuşmak', 'korku', 'korumak', 'koşul', 'koymak', 'koyulmak', 'kök', 'köken',
    'köprü', 'kör', 'kötü', 'kötülük', 'köy', 'kubbe', 'kudret', 'kul', 'kulak', 'kullanmak',
    'kuram', 'kuran', 'kurallı', 'kural', 'kurmak', 'kurtarıcı', 'kurtarmak', 'kurtulmak', 'kurtuluş', 'kuruluş',
    'kurum', 'kuru', 'kusur', 'kuş', 'kuşak', 'kut', 'kutlu', 'kutsal', 'kuvvet', 'kuyumcu',
    'küçük', 'küçümsemek', 'külliye', 'külliyat', 'kültür', 'küme', 'kütüphane', 'laik', 'lakin', 'lâkin',
    'layık', 'lazım', 'levha', 'lezzet', 'lisan', 'liste', 'lütuf', 'lügat', 'maalesef', 'macera',
    'madde', 'maddi', 'mağlubiyet', 'mağlûbiyet', 'maharet', 'mahiyet', 'mahkeme', 'mahlas', 'mahrum', 'mahsus',
    'makale', 'makam', 'makul', 'mal', 'mâlî', 'malumat', 'mana', 'mânâ', 'manevi', 'manevî',
    'mantık', 'manzara', 'marifet', 'marjinalia', 'masdar', 'matbaa', 'mavi', 'mazmun', 'mecaz', 'mecbur',
    'meclis', 'mecmua', 'medeni', 'medenî', 'medeniyet', 'medrese', 'mefkure', 'mefkûre', 'meğer', 'mekan',
    'mekân', 'mektep', 'mektup', 'memleket', 'memur', 'men', 'menetmek', 'menfaat', 'mensup', 'merak',
    'merhamet', 'merhum', 'merkez', 'mertebe', 'mesai', 'mesafe', 'mesela', 'mesele', 'meslek', 'mesnevi',
    'mesuliyet', 'meşgul', 'meşk', 'meşru', 'metafizik', 'metal', 'metin', 'metot', 'mevcut', 'mevcud',
    'mevlana', 'mevlânâ', 'mevsim', 'mevzu', 'meydan', 'meyil', 'meyve', 'mezalim', 'mezâlim', 'mezhep',
    'mısra', 'mikrop', 'miktar', 'millet', 'milli', 'millî', 'mimar', 'mimari', 'minnet', 'miras',
    'misal', 'mizan', 'mizanpaj', 'mizaç', 'model', 'modern', 'mor', 'motif', 'muamele', 'muaşeret',
    'muazzam', 'muhabbet', 'muhakeme', 'muhakkak', 'muhafaza', 'muhalefet', 'muhatap', 'muhit', 'muhtaç', 'muhtelif',
    'muhterem', 'muhteşem', 'mukaddes', 'mukaddime', 'mukabele', 'musiki', 'mutlak', 'mutlu', 'mutluluk', 'muvaffak',
    'mübarek', 'mübârek', 'mücadele', 'müddet', 'müderris', 'müellif', 'müessese', 'müessir', 'müfessir', 'mühim',
    'mühimsemek', 'mühür', 'müjde', 'mükemmel', 'mülk', 'mümkün', 'münacat', 'münasebet', 'münazara', 'müntesip',
    'münzevi', 'müracaat', 'mürekkep', 'mürşit', 'müsamaha', 'müsamahakâr', 'müslüman', 'müstakil', 'müstensih', 'müstesna',
    'müşahhas', 'müşkül', 'müşterek', 'mütalaa', 'mütefekkir', 'müthiş', 'müzakere', 'naat', 'nadir', 'nakil',
    'nakış', 'nakletmek', 'nam', 'nasip', 'nasıl', 'nasihat', 'nazar', 'nazari', 'nazire', 'nazım',
    'ne', 'neden', 'nefes', 'nefis', 'nefret', 'nehir', 'nerede', 'nesil', 'nesir', 'nesih',
    'nesne', 'neşir', 'netice', 'ney', 'nezaket', 'nice', 'niçin', 'nihai', 'nihayet', 'nimet',
    'nispet', 'nitelik', 'niyet', 'niyaz', 'nizam', 'nizâm', 'nokta', 'normal', 'not', 'numara',
    'nur', 'nübüvvet', 'nüfus', 'nüsha', 'o', 'ocak', 'oda', 'odak', 'oğul', 'ok',
    'okuma', 'okumak', 'okur', 'okuyucu', 'okyanus', 'olanak', 'olarak', 'olay', 'oldukça', 'olgun',
    'olmak', 'olan', 'olaylı', 'olgu', 'olumlu', 'oluşmak', 'omuz', 'on', 'onay', 'onuncu',
    'ontoloji', 'onur', 'ora', 'orada', 'oran', 'ordu', 'orta', 'ortak', 'ortam', 'ortaya',
    'osmanlı', 'oturmak', 'otuz', 'oyun', 'öbür', 'ödev', 'ödül', 'öfke', 'öğrenmek', 'öğreti',
    'öğretmen', 'ölçü', 'ölçüt', 'ölmek', 'ölüm', 'ömür', 'ön', 'önce', 'önceki', 'öncül',
    'önem', 'önemli', 'öneri', 'önerme', 'önsöz', 'örmek', 'örnek', 'örf', 'örtmek', 'öte',
    'ötürü', 'övgü', 'övmek', 'öyle', 'öz', 'özel', 'özellik', 'özet', 'özgün', 'özgür',
    'özgürlük', 'özlem', 'özlü', 'padişah', 'parça', 'paradigma', 'paragraf', 'parlak', 'pas', 'pay',
    'paylaşmak', 'pek', 'pencere', 'perde', 'peygamber', 'plan', 'politika', 'prensip', 'problem', 'program',
    'psikoloji', 'punto', 'pusula', 'rab', 'rağmen', 'rahat', 'rahatlık', 'rahmet', 'rakam', 'ram',
    'rapor', 'rasathane', 'razı', 'rehber', 'renk', 'resim', 'resmi', 'resûl', 'resûlullah', 'risale',
    'ritüel', 'rivayet', 'rıfk', 'rıza', 'roman', 'rubai', 'ruh', 'ruhani', 'rüzgar', 'saadet',
    'saat', 'sabah', 'sabır', 'sabırlı', 'sabit', 'sadakat', 'sade', 'sadece', 'sadık', 'saf',
    'safha', 'sağ', 'sağır', 'sağlam', 'sağlamak', 'sağduyu', 'saha', 'sahaf', 'sahih', 'sahip',
    'sahne', 'sakınmak', 'sakin', 'saltanat', 'samimi', 'sanat', 'sanatçı', 'sanayi', 'sanâyi', 'sandık',
    'saniye', 'sanki', 'sanmak', 'saray', 'sarmak', 'sarsılmaz', 'satır', 'satmak', 'savaş', 'sayfa',
    'saygı', 'sayı', 'sayım', 'saymak', 'sebep', 'seci', 'seçim', 'seçkin', 'seçmek', 'sefer',
    'sehpa', 'sekiz', 'selam', 'selâm', 'sembol', 'sema', 'sen', 'sene', 'sentez', 'serbest',
    'serlevha', 'sermek', 'sert', 'servet', 'ses', 'sessiz', 'sessizlik', 'sevgi', 'sevgili', 'sevinç',
    'seviye', 'sevmek', 'seyahat', 'seyir', 'sezgi', 'sezmek', 'sıcak', 'sıfat', 'sıfır', 'sığınak',
    'sığmak', 'sıhhat', 'sık', 'sıkıntı', 'sır', 'sıra', 'sırf', 'sınıf', 'sınır', 'silsile',
    'simge', 'sinan', 'sistem', 'siyaset', 'siyasi', 'siyâsî', 'siz', 'sohbet', 'sokak', 'sol',
    'son', 'sonra', 'sonraki', 'sonuç', 'sonsuz', 'sorgulama', 'sormak', 'soru', 'sorun', 'sosyal',
    'soy', 'soyut', 'söylemek', 'söz', 'sözcük', 'sözlük', 'su', 'suistimal', 'sultan', 'sunmak',
    'suret', 'susmak', 'süslü', 'süslemek', 'sülüs', 'sünnet', 'süvari', 'süre', 'sürekli', 'süreç',
    'sürat', 'süratle', 'sürmek', 'sürûr', 'şafak', 'şaheser', 'şahıs', 'şahsiyet', 'şahit', 'şair',
    'şâir', 'şark', 'şart', 'şehir', 'şehit', 'şecaat', 'şefkat', 'şekil', 'şer', 'şeref',
    'şerh', 'şeriat', 'şerha', 'şey', 'şeyh', 'şeytan', 'şiddet', 'şiddetli', 'şifa', 'şiir',
    'şikayet', 'şimdi', 'şirket', 'şöyle', 'şu', 'şuur', 'şükür', 'şüphe', 'tabiat', 'tabii',
    'tabir', 'tâbir', 'tablo', 'taç', 'tâc', 'tahayyül', 'tahkik', 'tahlil', 'tahmin', 'tahrir',
    'tahsil', 'tahsis', 'taht', 'takdir', 'takdim', 'takip', 'takma', 'talep', 'talebe', 'talih',
    'talik', 'tam', 'tamam', 'tamamen', 'tamamlamak', 'tanık', 'tanım', 'tanımak', 'tanrı', 'taraf',
    'taramak', 'tarama', 'tarz', 'tasarım', 'tasavvur', 'tasavvuf', 'tasdik', 'tashih', 'tasnif', 'taş',
    'taşımak', 'tatlı', 'tavır', 'tavsiye', 'tayin', 'tâyin', 'taze', 'tebliğ', 'tecessüs', 'tecrübe',
    'tedavi', 'tedbir', 'tedebbür', 'tedris', 'tefekkür', 'tefrit', 'tefsir', 'tehlike', 'tek', 'tekrar',
    'teknik', 'teknoloji', 'telakki', 'telâkki', 'telaffuz', 'teleoloji', 'telif', 'telmih', 'temas', 'temâs',
    'temel', 'teminat', 'temiz', 'temsil', 'tenasüp', 'tenkit', 'tenkid', 'teori', 'tepmek', 'terbiye',
    'tercih', 'tercüme', 'terceme', 'tereddüt', 'terim', 'terk', 'terketmek', 'terkip', 'tertip', 'teselli',
    'tesir', 'tesis', 'teslim', 'tespit', 'teşbih', 'teşekkür', 'teşkil', 'teşvik', 'tevatür', 'tevekkül',
    'tevhid', 'tez', 'tezat', 'tezhip', 'tıp', 'tıbbi', 'tipografi', 'titiz', 'tohum', 'top',
    'toplam', 'toplamak', 'toplantı', 'toplu', 'topluluk', 'toplum', 'toplumsal', 'toprak', 'tören', 'tuğra',
    'tutku', 'tutmak', 'tutulmak', 'tür', 'türk', 'türkçe', 'türlü', 'türemek', 'tüm', 'tümce',
    'uç', 'ufuk', 'uğraşmak', 'uğur', 'uğruna', 'ulaşmak', 'ulu', 'ululuk', 'ulus', 'umran',
    'ümran', 'ummak', 'umulmak', 'umumi', 'umut', 'unsur', 'unvan', 'unutmak', 'unutucu', 'usul',
    'usûl', 'usta', 'uyanmak', 'uyandırıcı', 'uyarı', 'uydurmak', 'uygulama', 'uygun', 'uyku', 'uymak',
    'uyum', 'uyumlu', 'uzak', 'uzaklaşmak', 'uzay', 'uzlaşma', 'uzman', 'uzun', 'üç', 'üçüncü',
    'ülke', 'ülkü', 'ümit', 'ümmet', 'ünite', 'ünlü', 'ünsüz', 'üretim', 'üretmek', 'üslup',
    'üst', 'üstat', 'üstün', 'üzeri', 'üzerinde', 'üzerine', 'üzüntü', 'vacip', 'vâcib', 'vadi',
    'vahiy', 'vakar', 'vakıa', 'vakıf', 'vakit', 'vaki', 'vâki', 'valide', 'var', 'varak',
    'varaka', 'varlık', 'varmak', 'varsayım', 'vasıf', 'vasf', 'vasıta', 'vatan', 'vatandaş', 'vazgeçmek',
    'vazife', 've', 'veba', 'veciz', 'vefa', 'vefat', 'veli', 'vergi', 'veri', 'vermek',
    'vesile', 'veya', 'vezin', 'vezir', 'vicdan', 'vilayet', 'vurgu', 'vuslat', 'vücut', 'ya',
    'yabancı', 'yahut', 'yakın', 'yakîn', 'yaklaşım', 'yaklaşmak', 'yalnız', 'yalnızca', 'yalın', 'yan',
    'yana', 'yanlış', 'yanlışsız', 'yanılmak', 'yansıma', 'yansıtmak', 'yapı', 'yapıcı', 'yapmak', 'yaprak',
    'yar', 'yara', 'yarar', 'yaratılış', 'yaratmak', 'yardım', 'yardımlaşma', 'yargı', 'yarı', 'yarım',
    'yarın', 'yarış', 'yas', 'yasa', 'yaş', 'yaşam', 'yaşamak', 'yatmak', 'yavaş', 'yavaşça',
    'yaygın', 'yayınevi', 'yaymak', 'yaz', 'yazar', 'yazı', 'yazgı', 'yazılı', 'yazmak', 'yazma',
    'yedi', 'yedinci', 'yeni', 'yeniden', 'yer', 'yerel', 'yerine', 'yerleşik', 'yeşil',
    'yeter', 'yeterli', 'yeti', 'yetişmek', 'yetki', 'yetmiş', 'yığın', 'yıkım', 'yıkmak', 'yıl',
    'yıldız', 'yine', 'yiğit', 'yirmi', 'yiyecek', 'yoğun', 'yok', 'yokluk', 'yoksa', 'yol',
    'yolculuk', 'yorum', 'yorumbilim', 'yormak', 'yöntem', 'yön', 'yönelik', 'yönelmek', 'yönetim', 'yönetmek',
    'yüce', 'yüceltmek', 'yük', 'yüksek', 'yükseliş', 'yükselmek', 'yürek', 'yürümek', 'yürütmek', 'yüz',
    'yüzey', 'yüzyıl', 'zahir', 'zahiri', 'zahmet', 'zaman', 'zan', 'zarafet', 'zarar', 'zarif',
    'zaruri', 'zat', 'zaten', 'zayıf', 'zemin', 'zengin', 'zenginlik', 'zerre', 'zevk', 'zihin',
    'zikir', 'zincir', 'zirve', 'ziyade', 'ziyaret', 'zor', 'zorlu', 'zorunlu', 'zulüm', 'zümre',
    'meziyet', 'metod', 'incelenmek', 'incelenme', 'tarihçi', 'yanılma', 'vehim', 'vehme', 'kapılmak', 'kapılma',
    'şerefli', 'elçi', 'kılık', 'öğretmek', 'bütünlemek', 'başvurmak', 'edinmek', 'faydalanmak', 'cihet', 'inceleme',
    'kalb', 'husul', 'husule', 'tesbit', 'sürçme', 'sürçmek', 'âdet', 'barış', 'tarım',
    'bin', 'bini', 'binden', 'haldun', 'arizona', 'nogales', 'cruz', 'santa', 'fars', 'iştirak', 'mütenasip',
    'idi', 'idim', 'idin', 'idik', 'idiniz', 'idiler',
    'imiş', 'imişim', 'imişsin', 'imişiz', 'imişsiniz', 'imişler',
    'isem', 'isen', 'isek', 'iseniz', 'iseler',
  };
}

class _ParagraphProofreadPass {
  final String correctedText;
  final List<OcrCorrectionItem> autoCorrections;
  final List<OcrSuggestionItem> suggestions;
  final int wordCount;

  const _ParagraphProofreadPass({
    required this.correctedText,
    required this.autoCorrections,
    required this.suggestions,
    required this.wordCount,
  });
}
