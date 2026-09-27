import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zikirce/core/database/app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('Transfer from Zikirmatik (Zikirmatikten Aktar) increments totalCount and records ZikirLog', () async {
    // 1. Fetch seeded initial dhikrs
    final zikirs = await db.select(db.zikirs).get();
    expect(zikirs.isNotEmpty, isTrue);

    final subhanallah = zikirs.firstWhere((z) => z.name == 'Sübhanallah');
    final initialTotal = subhanallah.totalCount;

    // 2. Perform transfer of 100 dhikrs
    const transferAmount = 100;
    final newTotal = initialTotal + transferAmount;
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    await (db.update(db.zikirs)..where((t) => t.id.equals(subhanallah.id))).write(
      ZikirsCompanion(
        totalCount: Value(newTotal),
        lastPracticed: Value(now),
      ),
    );

    await db.into(db.zikirLogs).insert(
      ZikirLogsCompanion.insert(
        zikirId: subhanallah.id,
        count: transferAmount,
        dateStr: dateStr,
      ),
    );

    // 3. Verify Zikir table updated
    final updated = await (db.select(db.zikirs)..where((t) => t.id.equals(subhanallah.id))).getSingle();
    expect(updated.totalCount, equals(initialTotal + 100));
    expect(updated.lastPracticed, isNotNull);

    // 4. Verify ZikirLogs table has recorded entry
    final logs = await (db.select(db.zikirLogs)..where((t) => t.zikirId.equals(subhanallah.id))).get();
    expect(logs.any((l) => l.count == 100 && l.dateStr == dateStr), isTrue);

    // 5. Perform second transfer of 500 dhikrs
    const secondTransfer = 500;
    final secondTotal = updated.totalCount + secondTransfer;
    await (db.update(db.zikirs)..where((t) => t.id.equals(subhanallah.id))).write(
      ZikirsCompanion(
        totalCount: Value(secondTotal),
        lastPracticed: Value(DateTime.now()),
      ),
    );

    await db.into(db.zikirLogs).insert(
      ZikirLogsCompanion.insert(
        zikirId: subhanallah.id,
        count: secondTransfer,
        dateStr: dateStr,
      ),
    );

    final finalZikir = await (db.select(db.zikirs)..where((t) => t.id.equals(subhanallah.id))).getSingle();
    expect(finalZikir.totalCount, equals(initialTotal + 600));

    final totalLogs = await (db.select(db.zikirLogs)..where((t) => t.zikirId.equals(subhanallah.id))).get();
    final sumOfLogs = totalLogs.fold<int>(0, (sum, l) => sum + l.count);
    expect(sumOfLogs, greaterThanOrEqualTo(600));
  });

  test('Creating custom dhikr and transferring to it works seamlessly', () async {
    final customDhikrId = await db.into(db.zikirs).insert(
      ZikirsCompanion.insert(
        name: 'Hasbiyallahu la ilahe illa Hu',
        arabic: const Value('حَسْبِيَ اللَّهُ لَا إِلٰهَ إِلَّا هُوَ'),
        target: const Value(7),
        category: const Value('Dualar'),
        isFavorite: const Value(true),
      ),
    );

    // Initial check
    final customDhikr = await (db.select(db.zikirs)..where((t) => t.id.equals(customDhikrId))).getSingle();
    expect(customDhikr.totalCount, equals(0));
    expect(customDhikr.category, equals('Dualar'));
    expect(customDhikr.isFavorite, isTrue);

    // Transfer 70
    const transferred = 70;
    await (db.update(db.zikirs)..where((t) => t.id.equals(customDhikrId))).write(
      ZikirsCompanion(
        totalCount: Value(customDhikr.totalCount + transferred),
        lastPracticed: Value(DateTime.now()),
      ),
    );

    final updated = await (db.select(db.zikirs)..where((t) => t.id.equals(customDhikrId))).getSingle();
    expect(updated.totalCount, equals(70));
  });
}
