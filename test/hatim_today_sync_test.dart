import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:zikirce/core/database/app_database.dart';
import 'package:zikirce/core/services/data_reconciliation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory(), 'test_sync.sqlite');
  });

  tearDown(() async {
    await db.close();
  });

  test('HatimTodayPages reconciles correctly from cloud payload into local SharedPreferences', () async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    // 1. Setup local hatim
    await db.into(db.hatims).insert(
      HatimsCompanion.insert(
        id: 'hatim_1',
        title: 'Bireysel Hatim',
        completedPages: const Value(145),
      ),
    );

    // Initial local today count is 0
    expect(prefs.getInt('HatimTodayPages_hatim_1_$todayStr') ?? 0, 0);

    // 2. Simulated remote payload from phone where 1 page was read today
    final remotePayload = {
      'AppVersion': '2.0',
      'Hatimler': [
        {
          'RealHatimId': 'hatim_1',
          'id': 'hatim_1',
          'HatimAdi': 'Bireysel Hatim',
          'CurrentPage': 146,
          'TodayReadPages': 1,
          'LastReadDate': todayStr,
        },
      ],
      'AppSettings': {
        'TodayReadPages': 1,
        'TodayReadPages_$todayStr': 1,
        'TotalReadQuranPages': 146,
        'HatimTodayPages': {
          'hatim_1': 1,
        },
        'HatimTodayPages_hatim_1_$todayStr': 1,
        'HatimLastReadDate_hatim_1': todayStr,
      },
    };

    // 3. Run smartMergeCloudPayload
    final success = await DataReconciliationService.smartMergeCloudPayload(db, remotePayload);
    expect(success, true);

    // 4. Verify completed pages updated to 146
    final updatedHatim = await (db.select(db.hatims)..where((t) => t.id.equals('hatim_1'))).getSingle();
    expect(updatedHatim.completedPages, 146);

    // 5. Verify HatimTodayPages is now 1 on this device!
    final hatimToday = prefs.getInt('HatimTodayPages_hatim_1_$todayStr');
    expect(hatimToday, 1);

    // 6. Verify overall TodayReadPages is 1
    final overallToday = prefs.getInt('TodayReadPages_$todayStr');
    expect(overallToday, 1);
  });
}
