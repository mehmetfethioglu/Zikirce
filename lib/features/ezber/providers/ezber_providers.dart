import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/providers/database_provider.dart';
import '../../../../core/utils/spaced_repetition_sm2.dart';

final memorizationPlansStreamProvider = StreamProvider<List<MemorizationPlan>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.memorizationPlans)
        ..orderBy([
          (t) => OrderingTerm(expression: t.scheduledReviewDate, mode: OrderingMode.asc),
        ]))
      .watch();
});

final todayHafizlikLogProvider = StreamProvider<HafizlikDailyLog?>((ref) {
  final db = ref.watch(databaseProvider);
  final now = DateTime.now();
  final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

  return (db.select(db.hafizlikDailyLogs)..where((t) => t.dateStr.equals(dateStr)))
      .watchSingleOrNull();
});

class EzberNotifier extends StateNotifier<void> {
  final Ref ref;

  EzberNotifier(this.ref) : super(null);

  Future<void> submitSm2Review({
    required int pageId,
    required int quality,
    required int currentReps,
    required int currentInterval,
    required double currentEf,
  }) async {
    final db = ref.read(databaseProvider);
    final result = SpacedRepetitionSm2.calculate(
      quality: quality,
      previousRepetitions: currentReps,
      previousIntervalDays: currentInterval,
      previousEaseFactor: currentEf,
    );

    int newState = 1; // Learning
    if (result.repetitions >= 4) newState = 3; // Mastered
    else if (result.repetitions >= 1) newState = 2; // Review

    await (db.update(db.memorizationPlans)..where((t) => t.pageId.equals(pageId))).write(
      MemorizationPlansCompanion(
        timesReviewed: Value(result.repetitions),
        intervalDays: Value(result.intervalDays),
        easeFactor: Value(result.easeFactor),
        scheduledReviewDate: Value(result.nextReviewDate),
        lastReviewedDate: Value(DateTime.now()),
        state: Value(newState),
      ),
    );
  }

  Future<void> addPageToPlan(int pageId, int? surahId) async {
    final db = ref.read(databaseProvider);
    await db.into(db.memorizationPlans).insertOnConflictUpdate(
      MemorizationPlansCompanion(
        pageId: Value(pageId),
        surahId: Value(surahId),
        scheduledReviewDate: Value(DateTime.now()),
        state: const Value(0), // New
      ),
    );
  }

  Future<void> updateHafizlikTask({
    required String taskType, // ham, pismis, has, vird
    required bool isDone,
  }) async {
    final db = ref.read(databaseProvider);
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final existing = await (db.select(db.hafizlikDailyLogs)..where((t) => t.dateStr.equals(dateStr))).getSingleOrNull();

    if (existing == null) {
      await db.into(db.hafizlikDailyLogs).insert(
        HafizlikDailyLogsCompanion(
          dateStr: Value(dateStr),
          isHamDone: Value(taskType == 'ham' ? isDone : false),
          isPismisDone: Value(taskType == 'pismis' ? isDone : false),
          isHasDone: Value(taskType == 'has' ? isDone : false),
          isAsgariVirdDone: Value(taskType == 'vird' ? isDone : false),
        ),
      );
    } else {
      await (db.update(db.hafizlikDailyLogs)..where((t) => t.dateStr.equals(dateStr))).write(
        HafizlikDailyLogsCompanion(
          isHamDone: taskType == 'ham' ? Value(isDone) : Value(existing.isHamDone),
          isPismisDone: taskType == 'pismis' ? Value(isDone) : Value(existing.isPismisDone),
          isHasDone: taskType == 'has' ? Value(isDone) : Value(existing.isHasDone),
          isAsgariVirdDone: taskType == 'vird' ? Value(isDone) : Value(existing.isAsgariVirdDone),
        ),
      );
    }
  }
}

final ezberNotifierProvider = Provider<EzberNotifier>((ref) {
  return EzberNotifier(ref);
});
