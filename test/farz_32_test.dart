import 'package:flutter_test/flutter_test.dart';
import 'package:zikirce/features/namaz_vakitleri/data/farz_32_data.dart';
import 'package:zikirce/features/namaz_vakitleri/domain/models/farz_knowledge_item.dart';

void main() {
  group('32 Farz Veri Bütünlüğü ve Diyanet İlmihali Uyumluluğu Testleri', () {
    test('Toplam farz sayısı tam olarak 32 olmalıdır', () {
      expect(kFarz32List.length, equals(32));
    });

    test('Farz ID numaraları 1\'den 32\'ye kadar kesintisiz ve sıralı olmalıdır', () {
      for (int i = 0; i < kFarz32List.length; i++) {
        expect(kFarz32List[i].id, equals(i + 1));
      }
    });

    test('Farz kategorileri ve adetleri fıkhi tasnife birebir uymalıdır', () {
      final imanList = kFarz32List.where((f) => f.category == FarzCategory.iman).toList();
      final islamList = kFarz32List.where((f) => f.category == FarzCategory.islam).toList();
      final abdestList = kFarz32List.where((f) => f.category == FarzCategory.abdest).toList();
      final gusulList = kFarz32List.where((f) => f.category == FarzCategory.gusul).toList();
      final teyemmumList = kFarz32List.where((f) => f.category == FarzCategory.teyemmum).toList();
      final namazSartList = kFarz32List.where((f) => f.category == FarzCategory.namazSart).toList();
      final namazRukunList = kFarz32List.where((f) => f.category == FarzCategory.namazRukun).toList();

      expect(imanList.length, equals(6), reason: 'İmanın Şartları 6 olmalı');
      expect(islamList.length, equals(5), reason: 'İslam\'ın Şartları 5 olmalı');
      expect(abdestList.length, equals(4), reason: 'Abdestin Farzları 4 olmalı');
      expect(gusulList.length, equals(3), reason: 'Guslün Farzları 3 olmalı');
      expect(teyemmumList.length, equals(2), reason: 'Teyemmümün Farzları 2 olmalı');
      expect(namazSartList.length, equals(6), reason: 'Namazın Şartları 6 olmalı');
      expect(namazRukunList.length, equals(6), reason: 'Namazın Rükünleri 6 olmalı');

      expect(
        imanList.length +
            islamList.length +
            abdestList.length +
            gusulList.length +
            teyemmumList.length +
            namazSartList.length +
            namazRukunList.length,
        equals(32),
      );
    });

    test('Her farzın bildirim özeti kısa, öz ve bildirim sınırlarına uygun olmalıdır', () {
      for (final item in kFarz32List) {
        expect(item.notificationSummary.isNotEmpty, isTrue);
        expect(
          item.notificationSummary.length,
          lessThanOrEqualTo(180),
          reason: 'Farz #${item.id} (${item.title}) bildirim metni çok uzun: ${item.notificationSummary.length} karakter',
        );
      }
    });

    test('Her farzın Diyanet İlmihali kaynak referansı ve detaylı makalesi bulunmalıdır', () {
      for (final item in kFarz32List) {
        expect(item.title.isNotEmpty, isTrue);
        expect(item.fullContent.length, greaterThan(150), reason: 'Farz #${item.id} makalesi çok kısa');
        expect(item.sourceCitation.contains('Diyanet İşleri Başkanlığı İlmihali'), isTrue);
        expect(item.sourceCitation.contains('Cilt 1'), isTrue);
      }
    });
  });
}
