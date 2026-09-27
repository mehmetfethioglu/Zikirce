class Sm2Result {
  final int intervalDays;
  final int repetitions;
  final double easeFactor;
  final DateTime nextReviewDate;

  Sm2Result({
    required this.intervalDays,
    required this.repetitions,
    required this.easeFactor,
    required this.nextReviewDate,
  });
}

class SpacedRepetitionSm2 {
  /// Calculates the next review schedule using the SuperMemo SM-2 algorithm.
  /// [quality]: 0 to 5 (0: complete blackout, 3: pass with difficulty, 5: perfect recall)
  /// [previousRepetitions]: how many times successfully recalled
  /// [previousIntervalDays]: previous interval in days
  /// [previousEaseFactor]: default starts at 2.5
  static Sm2Result calculate({
    required int quality,
    required int previousRepetitions,
    required int previousIntervalDays,
    double previousEaseFactor = 2.5,
  }) {
    int repetitions;
    int intervalDays;
    double easeFactor = previousEaseFactor;

    // Quality 0-5 clamp
    final q = quality.clamp(0, 5);

    if (q >= 3) {
      if (previousRepetitions == 0) {
        intervalDays = 1;
      } else if (previousRepetitions == 1) {
        intervalDays = 6;
      } else {
        intervalDays = (previousIntervalDays * easeFactor).round();
      }
      repetitions = previousRepetitions + 1;
    } else {
      repetitions = 0;
      intervalDays = 1;
    }

    // Update Ease Factor (EF)
    // EF' = EF + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02))
    easeFactor = easeFactor + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02));
    if (easeFactor < 1.3) {
      easeFactor = 1.3;
    }

    final nextReview = DateTime.now().add(Duration(days: intervalDays));

    return Sm2Result(
      intervalDays: intervalDays,
      repetitions: repetitions,
      easeFactor: easeFactor,
      nextReviewDate: nextReview,
    );
  }
}
