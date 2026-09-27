import 'dart:math';
import '../../../core/services/quran_page_repository.dart';

class SmartDistractorsService {
  static final Random _random = Random();

  /// Verilen hedef ayet için akıllı çeldirici ayetler üretir.
  /// 1. Aynı suredeki yakın/komşu ayetler
  /// 2. Aynı cüzdeki benzer kelime sayısına sahip (müteşabih) ayetler
  /// 3. Rastgele fallback ayetler
  static List<QuranAyatModel> generateDistractors({
    required QuranAyatModel targetVerse,
    required List<QuranAyatModel> allAvailableVerses,
    int distractorCount = 3,
  }) {
    if (allAvailableVerses.isEmpty) {
      return [];
    }

    final result = <QuranAyatModel>[];
    final candidatesPool = allAvailableVerses
        .where((v) => v.id != targetVerse.id && (v.sureId != targetVerse.sureId || v.ayetId != targetVerse.ayetId))
        .toList();

    if (candidatesPool.isEmpty) return result;

    // 1. Öncelik: Aynı suredeki komşu/yakın ayetler
    final sameSurahCandidates = candidatesPool
        .where((v) => v.sureId == targetVerse.sureId)
        .toList()
      ..sort((a, b) =>
          (a.ayetId - targetVerse.ayetId).abs().compareTo((b.ayetId - targetVerse.ayetId).abs()));

    for (final candidate in sameSurahCandidates) {
      if (result.length >= distractorCount) break;
      if (!result.any((r) => r.id == candidate.id)) {
        result.add(candidate);
      }
    }

    // 2. Öncelik: Benzer kelime sayısına sahip ayetler
    if (result.length < distractorCount) {
      final targetWordCount = targetVerse.ayetText.split(' ').length;

      final lengthCandidates = candidatesPool
          .where((v) => !result.any((r) => r.id == v.id))
          .toList()
        ..sort((a, b) {
          final diffA = (a.ayetText.split(' ').length - targetWordCount).abs();
          final diffB = (b.ayetText.split(' ').length - targetWordCount).abs();
          return diffA.compareTo(diffB);
        });

      for (final candidate in lengthCandidates) {
        if (result.length >= distractorCount) break;
        result.add(candidate);
      }
    }

    // 3. Fallback: Havuzda eksik kalırsa rastgele karıştırarak tamamla
    if (result.length < distractorCount) {
      final remaining = candidatesPool
          .where((v) => !result.any((r) => r.id == v.id))
          .toList()
        ..shuffle(_random);

      for (final candidate in remaining) {
        if (result.length >= distractorCount) break;
        result.add(candidate);
      }
    }

    return result;
  }
}
