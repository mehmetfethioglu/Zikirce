import 'package:flutter/foundation.dart';

/// Display mode for PDF books inside [ReaderScreen].
enum ReaderDisplayMode {
  textReflow,
  opticalReflow,
  originalPdf,
}

/// Normalized (`0..1`) bounding box of a single OCR-recognized word on a page.
@immutable
class OcrWordBox {
  final String word;
  final double normalizedLeft;
  final double normalizedTop;
  final double normalizedWidth;
  final double normalizedHeight;
  final double confidence;

  const OcrWordBox({
    required this.word,
    required this.normalizedLeft,
    required this.normalizedTop,
    required this.normalizedWidth,
    required this.normalizedHeight,
    this.confidence = 1.0,
  });

  Map<String, dynamic> toJson() => {
        'w': word,
        'l': normalizedLeft,
        't': normalizedTop,
        'wd': normalizedWidth,
        'h': normalizedHeight,
        'c': confidence,
      };

  factory OcrWordBox.fromJson(Map<String, dynamic> json) {
    return OcrWordBox(
      word: (json['w'] as String?) ?? '',
      normalizedLeft: (json['l'] as num?)?.toDouble() ?? 0.0,
      normalizedTop: (json['t'] as num?)?.toDouble() ?? 0.0,
      normalizedWidth: (json['wd'] as num?)?.toDouble() ?? 0.0,
      normalizedHeight: (json['h'] as num?)?.toDouble() ?? 0.0,
      confidence: (json['c'] as num?)?.toDouble() ?? 1.0,
    );
  }
}

/// Hysteresis controller that prevents mode flickering between Text Reflow
/// and Optical Print Flow across consecutive pages of old scanned PDFs.
class ReadingModeHysteresis {
  const ReadingModeHysteresis._();

  /// If the opening pages average below 78% confidence, default the book to
  /// Optical Print Flow (`Baskı Akışı`).
  static const double bookDefaultOpticalThreshold = 0.78;

  /// In an active Text Reflow book, a single page switches automatically to
  /// Optical Print Flow only if its confidence drops strictly below 72%.
  static const double singlePageFallbackThreshold = 0.72;

  /// Chooses initial default mode from the book's early pages or dense non-Latin pages.
  static ReaderDisplayMode decideBookDefaultMode({
    required List<double> initialPageConfidences,
    required bool hasDenseNonLatin,
  }) {
    if (hasDenseNonLatin) {
      return ReaderDisplayMode.opticalReflow;
    }
    if (initialPageConfidences.isEmpty) {
      return ReaderDisplayMode.textReflow;
    }
    final avg = initialPageConfidences.reduce((a, b) => a + b) /
        initialPageConfidences.length;
    if (avg < bookDefaultOpticalThreshold) {
      return ReaderDisplayMode.opticalReflow;
    }
    return ReaderDisplayMode.textReflow;
  }

  /// Resolves the effective display mode for a single page with hysteresis
  /// and explicit user-choice preservation.
  static ReaderDisplayMode resolveEffectiveModeForPage({
    required ReaderDisplayMode activeBookMode,
    required bool userExplicitlySelectedMode,
    required double pageConfidence,
    required bool hasOpticalData,
  }) {
    if (userExplicitlySelectedMode) {
      return activeBookMode;
    }
    if (activeBookMode == ReaderDisplayMode.originalPdf) {
      return ReaderDisplayMode.originalPdf;
    }
    if (activeBookMode == ReaderDisplayMode.opticalReflow) {
      return hasOpticalData
          ? ReaderDisplayMode.opticalReflow
          : ReaderDisplayMode.textReflow;
    }
    if (hasOpticalData && pageConfidence < singlePageFallbackThreshold) {
      return ReaderDisplayMode.opticalReflow;
    }
    return ReaderDisplayMode.textReflow;
  }
}
