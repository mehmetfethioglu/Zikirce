import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zikirce/core/database/app_database.dart';
import 'package:zikirce/core/services/data_reconciliation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('Multi-Device Cloud Smart Reconciliation Tests', () {
    test('Zikir counts and logs from two devices merge additively without data loss', () async {
      final now = DateTime.now();
      final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      // 1. Yerel Cihaz (Örn: Telefon) 50 adet Sübhanallah çekmiş olsun (ZikirId = 1)
      await db.into(db.zikirs).insert(
        ZikirsCompanion.insert(
          id: const Value(1),
          name: 'Sübhanallah',
          arabic: const Value('سُبْحَانَ اللَّهِ'),
          target: const Value(33),
          currentCount: const Value(17),
          totalCount: const Value(50),
          category: const Value('Tesbihat'),
        ),
        mode: InsertMode.insertOrReplace,
      );

      await db.into(db.zikirLogs).insert(
        ZikirLogsCompanion.insert(
          id: const Value(1),
          zikirId: 1,
          count: 50,
          dateStr: dateStr,
          timestamp: Value(now.subtract(const Duration(minutes: 30))),
        ),
      );

      // 2. Uzak Cihaz (Örn: Tablet) aynı gün 30 adet Sübhanallah çekmiş olsun (Log timestamp farklı)
      final remotePayload = {
        'Zikirler': [
          {
            'ZikirId': 1,
            'ZikirAdi': 'Sübhanallah',
            'ZikirMiktar': 33,
            'Sayac': 30,
            'ZikirToplam': 30,
            'IsFavorite': true,
            'Kategori': 'Tesbihat',
          }
        ],
        'ZikirLogs': [
          {
            'LogId': 999,
            'ZikirId': 1,
            'CekilenMiktar': 30,
            'TarihUnix': now.subtract(const Duration(minutes: 10)).millisecondsSinceEpoch ~/ 1000,
            'dateStr': dateStr,
          }
        ],
      };

      // 3. Akıllı Uzlaştırmayı Çalıştır
      final result = await DataReconciliationService.smartMergeCloudPayload(db, remotePayload);
      expect(result, isTrue);

      // 4. Doğrula: Zikrin totalCount'u 80 olmalı (50 + 30), her iki log da korunmalı
      final zikir = await (db.select(db.zikirs)..where((t) => t.id.equals(1))).getSingle();
      expect(zikir.totalCount, equals(80));

      final allLogs = await db.select(db.zikirLogs).get();
      expect(allLogs.length, equals(2));
      final sumLogs = allLogs.fold<int>(0, (sum, item) => sum + item.count);
      expect(sumLogs, equals(80));
    });

    test('Quran and Mukabele reading progress selects furthest read page (MAX)', () async {
      // 1. Yerelde Hatim 1 için 20. sayfada olunsun
      await db.into(db.hatims).insert(
        HatimsCompanion.insert(
          id: 'hatim_test_1',
          title: 'Mukabele Hatmi',
          completedPages: const Value(20),
          isCompleted: const Value(false),
        ),
      );

      // 2. Uzak cihazda (Tablet) 25. sayfaya kadar okunmuş olsun
      final remotePayload = {
        'Hatimler': [
          {
            'HatimId': 'hatim_test_1',
            'HatimAdi': 'Mukabele Hatmi',
            'CompletedPages': 25,
            'IsCompleted': false,
          }
        ],
        'AppSettings': {
          'MukabeleLastPage_hatim_test_1': 26,
          'TotalReadQuranPages': 25,
        }
      };

      final result = await DataReconciliationService.smartMergeCloudPayload(db, remotePayload);
      expect(result, isTrue);

      // 3. Doğrula: Hatim en ileri sayfa olan 25'e güncellenmeli
      final hatim = await (db.select(db.hatims)..where((t) => t.id.equals('hatim_test_1'))).getSingle();
      expect(hatim.completedPages, equals(25));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('MukabeleLastPage_hatim_test_1'), equals(26));
      expect(prefs.getInt('TotalReadQuranPages'), equals(25));
    });

    test('Hatim Juz Progress preserves completion from either device (UNION)', () async {
      // 1. Yerelde Cüz 1 tamamlanmış olsun
      await db.into(db.hatimCuzProgresses).insert(
        HatimCuzProgressesCompanion.insert(
          hatimId: 'hatim_group',
          juzNo: 1,
          isCompleted: const Value(true),
          readerName: const Value('Ahmet'),
        ),
      );
      // Yerelde Cüz 2 henüz tamamlanmamış
      await db.into(db.hatimCuzProgresses).insert(
        HatimCuzProgressesCompanion.insert(
          hatimId: 'hatim_group',
          juzNo: 2,
          isCompleted: const Value(false),
        ),
      );

      // 2. Uzak cihazda Cüz 2 tamamlanmış olsun
      final remotePayload = {
        'HatimCuzProgressList': [
          {
            'HatimId': 'hatim_group',
            'CuzNumber': 2,
            'Status': 2, // Tamamlandı
            'OwnerName': 'Mehmet',
          }
        ]
      };

      final result = await DataReconciliationService.smartMergeCloudPayload(db, remotePayload);
      expect(result, isTrue);

      // 3. Doğrula: Her iki cüz de tamamlanmış görünmeli
      final list = await db.select(db.hatimCuzProgresses).get();
      final cuz1 = list.firstWhere((c) => c.juzNo == 1);
      final cuz2 = list.firstWhere((c) => c.juzNo == 2);

      expect(cuz1.isCompleted, isTrue);
      expect(cuz2.isCompleted, isTrue);
      expect(cuz2.readerName, equals('Mehmet'));
    });

    test('Zikir currentCount, lap, and lastPracticed sync from phone to PC when remote has newer progress', () async {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final todayMorning = DateTime.now().subtract(const Duration(hours: 2));

      // 1. Bilgisayarda dünkü veri var (currentCount: 5, totalCount: 100, lap: 3)
      await db.into(db.zikirs).insert(
        ZikirsCompanion.insert(
          id: const Value(2),
          name: 'Elhamdülillah',
          target: const Value(33),
          currentCount: const Value(5),
          totalCount: const Value(100),
          lap: const Value(3),
          lastPracticed: Value(yesterday),
        ),
        mode: InsertMode.insertOrReplace,
      );

      // 2. Telefondan bu sabah çekilen veri geliyor (currentCount: 25, totalCount: 150, lap: 4, todayMorning)
      final remotePayload = {
        'Zikirler': [
          {
            'ZikirId': 2,
            'ZikirAdi': 'Elhamdülillah',
            'ZikirMiktar': 33,
            'Sayac': 25,
            'ZikirToplam': 150,
            'MaxSeyir': 4,
            'SonPratikUnix': todayMorning.millisecondsSinceEpoch ~/ 1000,
          }
        ],
        'ZikirLogs': [
          {
            'LogId': 888,
            'ZikirId': 2,
            'CekilenMiktar': 50,
            'TarihUnix': todayMorning.millisecondsSinceEpoch ~/ 1000,
          }
        ]
      };

      final result = await DataReconciliationService.smartMergeCloudPayload(db, remotePayload);
      expect(result, isTrue);

      // 3. Doğrula: Bilgisayardaki zikir artık 25 sayacında, 4. turda ve 150 toplamında olmalı
      final zikir = await (db.select(db.zikirs)..where((t) => t.id.equals(2))).getSingle();
      expect(zikir.currentCount, equals(25));
      expect(zikir.totalCount, equals(150));
      expect(zikir.lap, equals(4));
      expect(zikir.lastPracticed?.millisecondsSinceEpoch, equals(todayMorning.millisecondsSinceEpoch ~/ 1000 * 1000));
    });
  });
}
