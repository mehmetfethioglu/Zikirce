import 'package:flutter_test/flutter_test.dart';
import 'package:zikirce/core/database/app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Hatim Filtering & Badge Ribbon Tests', () {
    test('Correctly filters active vs completed hatims', () {
      final now = DateTime.now();

      final activeHatim = Hatim(
        id: 'hatim_1',
        title: 'Bireysel Hatim',
        totalPages: 604,
        completedPages: 120,
        isCompleted: false,
        isGroup: false,
        createdAt: now,
      );

      final completedHatimByFlag = Hatim(
        id: 'hatim_2',
        title: '1. Hatm-i Şerif',
        totalPages: 604,
        completedPages: 604,
        isCompleted: true,
        isGroup: false,
        createdAt: now,
      );

      final completedHatimByPages = Hatim(
        id: 'hatim_3',
        title: 'Ramazan Hatmi',
        totalPages: 604,
        completedPages: 604,
        isCompleted: false,
        isGroup: false,
        createdAt: now,
      );

      final activeMukabele = Hatim(
        id: 'mukabele_1',
        title: 'Mukabele Hatmi',
        totalPages: 604,
        completedPages: 45,
        isCompleted: false,
        isGroup: false,
        createdAt: now,
      );

      final allHatims = [
        activeHatim,
        completedHatimByFlag,
        completedHatimByPages,
        activeMukabele,
      ];

      final activeList = allHatims.where((h) => !h.isCompleted && h.completedPages < 604).toList();
      final completedList = allHatims.where((h) => h.isCompleted || h.completedPages >= 604).toList();

      expect(activeList.length, equals(2));
      expect(activeList.map((h) => h.id), containsAll(['hatim_1', 'mukabele_1']));

      expect(completedList.length, equals(2));
      expect(completedList.map((h) => h.id), containsAll(['hatim_2', 'hatim_3']));
    });
  });
}
