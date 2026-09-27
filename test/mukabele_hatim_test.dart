import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zikirce/core/database/app_database.dart';
import 'package:zikirce/core/providers/database_provider.dart';
import 'package:zikirce/features/gamification/services/golden_day_service.dart';
import 'package:zikirce/features/hatim/providers/hatim_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('Mukabele Hatim creation and active provider verification', () async {
    final hatimNotifier = container.read(hatimNotifierProvider);

    // 1. Create a 30-Day Ramadan Mukabele
    final hatimId = await hatimNotifier.createMukabeleHatim(
      title: '30 Günlük Ramazan Mukabelesi',
      startPage: 1,
      targetDate: DateTime.now().add(const Duration(days: 30)),
    );

    expect(hatimId.startsWith('mukabele_'), isTrue);

    final hatims = await db.select(db.hatims).get();
    expect(hatims.length, 1);
    expect(hatims.first.title, '30 Günlük Ramazan Mukabelesi');
    expect(hatims.first.completedPages, 0);
    expect(hatims.first.isCompleted, isFalse);

    // Verify 30 juz records were created
    final juzRecords = await (db.select(db.hatimCuzProgresses)..where((t) => t.hatimId.equals(hatimId))).get();
    expect(juzRecords.length, 30);
    expect(juzRecords.every((j) => !j.isCompleted), isTrue);

    // Verify active Mukabele stream provider
    final activeHatim = await container.read(activeMukabeleHatimProvider.future);
    expect(activeHatim, isNotNull);
    expect(activeHatim?.id, hatimId);
  });

  test('Mukabele Hatim custom start page initializes completed pages and juzes', () async {
    final hatimNotifier = container.read(hatimNotifierProvider);

    // Start Mukabele from Juz 5 (Page 82)
    final hatimId = await hatimNotifier.createMukabeleHatim(
      title: '5. Cüz Mukabelesi',
      startPage: 82,
    );

    final hatim = await (db.select(db.hatims)..where((t) => t.id.equals(hatimId))).getSingle();
    expect(hatim.completedPages, 81);

    // Juzes 1 to 4 (80 pages) should be marked completed
    final juzRecords = await (db.select(db.hatimCuzProgresses)..where((t) => t.hatimId.equals(hatimId))).get();
    final completedJuzes = juzRecords.where((j) => j.isCompleted).map((j) => j.juzNo).toList();
    expect(completedJuzes, [1, 2, 3, 4]);

    final lastPage = await HatimNotifier.getMukabeleLastPage(hatimId);
    expect(lastPage, 82);
  });

  test('Mukabele reading progression updates daily goals, streaks, and last position', () async {
    final prefs = await SharedPreferences.getInstance();
    final todayStr = GoldenDayService.getTodayStr();
    final hatimNotifier = container.read(hatimNotifierProvider);

    final hatimId = await hatimNotifier.createMukabeleHatim(
      title: 'Bireysel Mukabele Hatmi',
      startPage: 1,
    );

    // Read 2 pages (Daily goal target met)
    await hatimNotifier.updateHatimPageProgress(hatimId: hatimId, targetPage: 2);
    await hatimNotifier.saveMukabeleLastPage(hatimId, 3);

    final todayPages = prefs.getInt('TodayReadPages_$todayStr');
    final hatimToday = prefs.getInt('HatimTodayPages_${hatimId}_$todayStr');
    final lastPage = await HatimNotifier.getMukabeleLastPage(hatimId);

    expect(todayPages, 2);
    expect(hatimToday, 2);
    expect(lastPage, 3);

    // Advance to 20 pages (Completes Juz 1)
    await hatimNotifier.updateHatimPageProgress(hatimId: hatimId, targetPage: 20);
    await hatimNotifier.saveMukabeleLastPage(hatimId, 21);

    final updatedHatim = await (db.select(db.hatims)..where((t) => t.id.equals(hatimId))).getSingle();
    expect(updatedHatim.completedPages, 20);

    final juz1 = await (db.select(db.hatimCuzProgresses)..where((t) => t.hatimId.equals(hatimId) & t.juzNo.equals(1))).getSingle();
    expect(juz1.isCompleted, isTrue);

    final newLastPage = await HatimNotifier.getMukabeleLastPage(hatimId);
    expect(newLastPage, 21);
  });
}
