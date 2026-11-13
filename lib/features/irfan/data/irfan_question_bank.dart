import '../domain/irfan_models.dart';
import 'irfan_questions_esma_dua.dart';
import 'irfan_questions_ilmihal.dart';
import 'irfan_questions_kulliyat_esma_dua.dart';
import 'irfan_questions_kulliyat_ilmihal.dart';
import 'irfan_questions_kulliyat_quran.dart';
import 'irfan_questions_kulliyat_siyer.dart';
import 'irfan_questions_quran.dart';
import 'irfan_questions_siyer.dart';

/// Unified, indexed question bank aggregating all 4 İrfan Meydanı pillars.
abstract final class IrfanQuestionBank {
  static final List<IrfanQuestion> allQuestions = List.unmodifiable([
    ...kIrfanQuestionsIlmihal,
    ...kIrfanQuestionsKulliyatIlmihal,
    ...kIrfanQuestionsSiyer,
    ...kIrfanQuestionsKulliyatSiyer,
    ...kIrfanQuestionsQuran,
    ...kIrfanQuestionsKulliyatQuran,
    ...kIrfanQuestionsEsmaDua,
    ...kIrfanQuestionsKulliyatEsmaDua,
  ]);

  static final Map<String, IrfanQuestion> _byIdIndex = {
    for (final q in allQuestions) q.id: q,
  };

  static final Map<(IrfanTopic, IrfanTier), List<IrfanQuestion>> _byNodeIndex =
      _buildNodeIndex();

  static final Map<int, List<IrfanQuestion>> _byFarzIndex = _buildFarzIndex();

  static Map<(IrfanTopic, IrfanTier), List<IrfanQuestion>> _buildNodeIndex() {
    final map = <(IrfanTopic, IrfanTier), List<IrfanQuestion>>{};
    for (final topic in IrfanTopic.values) {
      for (final tier in IrfanTier.values) {
        map[(topic, tier)] = List.unmodifiable(
          allQuestions
              .where((q) => q.topic == topic && q.tier == tier)
              .toList(),
        );
      }
    }
    return map;
  }

  static Map<int, List<IrfanQuestion>> _buildFarzIndex() {
    final temp = <int, List<IrfanQuestion>>{};
    for (final q in allQuestions) {
      final farzId = q.hikmet.linkedFarzId;
      if (farzId != null) {
        (temp[farzId] ??= <IrfanQuestion>[]).add(q);
      }
    }
    return {
      for (final entry in temp.entries)
        entry.key: List.unmodifiable(entry.value),
    };
  }

  static IrfanQuestion? byId(String id) => _byIdIndex[id];

  static List<IrfanQuestion> byNode(IrfanTopic topic, IrfanTier tier) =>
      _byNodeIndex[(topic, tier)] ?? const [];

  static List<IrfanQuestion> byFarzId(int farzId) =>
      _byFarzIndex[farzId] ?? const [];

  static List<IrfanQuestion> byThemeTags(Set<String> tags) {
    if (tags.isEmpty) return const [];
    return allQuestions
        .where((q) => q.specialDayTags.any(tags.contains))
        .toList(growable: false);
  }
}
