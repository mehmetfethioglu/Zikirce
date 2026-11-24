import 'package:flutter/foundation.dart';

/// Metin yoğunluğuna göre hedef okuma hızı ve öbek boyutu stratejisi (OCP).
enum TextDensityTier {
  fluent(
    id: 'fluent',
    label: 'Akıcı & Rahat',
    speedMultiplier: 1.08,
    chunkWords: 3,
  ),
  literary(
    id: 'literary',
    label: 'Edebi & Düşünsel',
    speedMultiplier: 1.00,
    chunkWords: 3,
  ),
  academic(
    id: 'academic',
    label: 'Akademik / Yoğun',
    speedMultiplier: 0.86,
    chunkWords: 2,
  );

  final String id;
  final String label;
  final double speedMultiplier;
  final int chunkWords;

  const TextDensityTier({
    required this.id,
    required this.label,
    required this.speedMultiplier,
    required this.chunkWords,
  });

  /// `OfflineAiService` karmaşıklık etiketinden yoğunluk derecesi türetir.
  static TextDensityTier fromComplexityLabel(String label) {
    final lower = label.toLowerCase();
    if (lower.contains('akademik') || lower.contains('yoğun')) {
      return TextDensityTier.academic;
    }
    if (lower.contains('edebi') || lower.contains('düşünsel')) {
      return TextDensityTier.literary;
    }
    return TextDensityTier.fluent;
  }

  /// Kalıcı kimlikten yoğunluk derecesi çözer.
  static TextDensityTier fromId(String id) {
    for (final tier in TextDensityTier.values) {
      if (tier.id == id) return tier;
    }
    return TextDensityTier.literary;
  }
}

/// Akıcı fasıl içindeki bilişsel rehberlik ve Kademeli Bırakma (Scaffolding) fazları.
enum GuidedFlowPhase {
  overdrive(
    label: 'Ritim Isınması',
    wpmFactor: 1.16,
    highlightOpacity: 0.95,
  ),
  cruise(
    label: 'Tam Akış',
    wpmFactor: 1.00,
    highlightOpacity: 0.78,
  ),
  scaffoldingFade(
    label: 'Kademeli Bırakma',
    wpmFactor: 1.02,
    highlightOpacity: 0.34,
  ),
  unassistedFlow(
    label: 'Serbest Göz Akışı',
    wpmFactor: 1.02,
    highlightOpacity: 0.12,
  );

  final String label;
  final double wpmFactor;
  final double highlightOpacity;

  const GuidedFlowPhase({
    required this.label,
    required this.wpmFactor,
    required this.highlightOpacity,
  });

  /// Fasıl ilerleme oranına (`0.0..1.0`) ve Pro kademeli bırakma seçeneğine göre fazı seçer.
  static GuidedFlowPhase forProgress(
    double progressRatio, {
    required bool scaffoldingEnabled,
  }) {
    final p = progressRatio.clamp(0.0, 1.0);
    if (p < 0.18) {
      return GuidedFlowPhase.overdrive;
    }
    if (!scaffoldingEnabled || p < 0.72) {
      return GuidedFlowPhase.cruise;
    }
    if (p < 0.90) {
      return GuidedFlowPhase.scaffoldingFade;
    }
    return GuidedFlowPhase.unassistedFlow;
  }
}

/// Fasıl bitiminde bir sonraki okuma hızını kalibre eden öz-bildirim seçenekleri.
enum TempoCalibrationFeedback {
  tooSlow(
    label: 'Yavaştı',
    subtitle: 'Temponu +20 WPM artır',
    wpmDelta: 20,
  ),
  inFlow(
    label: 'Tam Akıştaydım',
    subtitle: 'İdeal ritmi koru (+5 WPM)',
    wpmDelta: 5,
  ),
  tooFast(
    label: 'Anlam Kaçtı',
    subtitle: 'Temponu -20 WPM yumuşat',
    wpmDelta: -20,
  );

  final String label;
  final String subtitle;
  final int wpmDelta;

  const TempoCalibrationFeedback({
    required this.label,
    required this.subtitle,
    required this.wpmDelta,
  });
}

/// Ucu açık odak dayanıklılığı süre şablonları.
enum FasilDurationPreset {
  spark5(
    minutes: 5,
    title: '5 Dk • Kıvılcım',
    subtitle: 'Günlük alışkanlık faslı',
    requiresPro: false,
  ),
  focus12(
    minutes: 12,
    title: '12 Dk • Odak',
    subtitle: 'Dengeli mütalaa akışı',
    requiresPro: true,
  ),
  deep20(
    minutes: 20,
    title: '20 Dk • Derin Mütalaa',
    subtitle: 'İçsessiz derin okuma',
    requiresPro: true,
  ),
  mastery30(
    minutes: 30,
    title: '30 Dk • İhtisas',
    subtitle: 'Üst düzey odak dayanıklılığı',
    requiresPro: true,
  );

  final int minutes;
  final String title;
  final String subtitle;
  final bool requiresPro;

  const FasilDurationPreset({
    required this.minutes,
    required this.title,
    required this.subtitle,
    required this.requiresPro,
  });
}

/// Çevresel Görüş Piramidi satır verisi.
@immutable
class PyramidSpanRow {
  final String leftWord;
  final String centerAnchor;
  final String rightWord;
  final double horizontalGap;

  const PyramidSpanRow({
    required this.leftWord,
    required this.centerAnchor,
    required this.rightWord,
    required this.horizontalGap,
  });
}

/// Gerçek kitap paragrafı içinde karakter offsetleriyle hizalanmış anlam öbeği.
@immutable
class SemanticChunkSpan {
  final int paragraphIndex;
  final int startOffset;
  final int endOffset;
  final String text;
  final int wordCount;

  const SemanticChunkSpan({
    required this.paragraphIndex,
    required this.startOffset,
    required this.endOffset,
    required this.text,
    required this.wordCount,
  });
}

/// Aktif kitabın yaklaşan sayfalarından üretilen 60 saniyelik lexical ısınma paketi.
@immutable
class WarmupLexicalPack {
  final String sourceTitle;
  final String sourceAuthor;
  final int targetPage;
  final TextDensityTier densityTier;
  final List<String> keyConcepts;
  final List<PyramidSpanRow> pyramidRows;
  final List<String> overdriveChunks;
  final bool isFromUserBook;
  final String rawExcerptText;
  final int suggestedWpm;

  const WarmupLexicalPack({
    required this.sourceTitle,
    required this.sourceAuthor,
    required this.targetPage,
    required this.densityTier,
    required this.keyConcepts,
    required this.pyramidRows,
    required this.overdriveChunks,
    required this.isFromUserBook,
    required this.rawExcerptText,
    this.suggestedWpm = 260,
  });
}

/// Akıcı fasıl bitiminde aktif hatırlama ve Haşiye köprüsü için sunulan özet verisi.
@immutable
class FasilReflectionSummary {
  final String bookTitle;
  final int? bookId;
  final int startPage;
  final int endPage;
  final int pagesRead;
  final int wordsRead;
  final int durationSeconds;
  final int averageWpm;
  final List<String> keyConcepts;
  final String centralRecallSentence;
  final TextDensityTier densityTier;
  final List<String> insightSnippets;

  const FasilReflectionSummary({
    required this.bookTitle,
    this.bookId,
    this.startPage = 1,
    required this.endPage,
    required this.pagesRead,
    required this.wordsRead,
    required this.durationSeconds,
    required this.averageWpm,
    required this.keyConcepts,
    required this.centralRecallSentence,
    required this.densityTier,
    this.insightSnippets = const [],
  });
}
