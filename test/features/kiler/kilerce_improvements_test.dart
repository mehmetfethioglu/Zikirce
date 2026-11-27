import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:organicscore/core/database/database_helper.dart';
import 'package:organicscore/core/services/kilerce_backup_service.dart';
import 'package:organicscore/features/kiler/domain/receipt_ocr_service.dart';
import 'package:organicscore/features/monetization/domain/subscription_service.dart';
import 'package:organicscore/features/network/domain/open_food_facts_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Kilerce Quality & Regression Checks', () {
    test('e_numbers.json maps all entries cleanly with non-null required fields', () {
      final file = File('assets/data/e_numbers.json');
      expect(file.existsSync(), isTrue);

      final List<dynamic> items = jsonDecode(file.readAsStringSync()) as List<dynamic>;
      expect(items, isNotEmpty);

      for (final raw in items) {
        final row = DatabaseHelper.mapENumberRow(Map<String, dynamic>.from(raw as Map));
        expect((row['code'] as String).isNotEmpty, isTrue);
        expect((row['name'] as String).isNotEmpty, isTrue);
        expect(
          ['LOW', 'MODERATE', 'HIGH', 'TOXIC'].contains(row['risk_level']),
          isTrue,
        );
        expect((row['health_hazards'] as String).isNotEmpty, isTrue);
        expect((row['category'] as String).isNotEmpty, isTrue);
      }
    });

    test('OpenFoodFactsService.isPureNaturalFoodName avoids substring false positives', () {
      expect(OpenFoodFactsService.isPureNaturalFoodName('Dana Sucuk'), isFalse);
      expect(OpenFoodFactsService.isPureNaturalFoodName('Sütlü Çikolata'), isFalse);
      expect(OpenFoodFactsService.isPureNaturalFoodName('Ballı Mısır Gevreği'), isFalse);
      expect(OpenFoodFactsService.isPureNaturalFoodName('Susamlı Kraker'), isFalse);
      expect(OpenFoodFactsService.isPureNaturalFoodName('Sızma Zeytinyağı'), isTrue);
      expect(OpenFoodFactsService.isPureNaturalFoodName('Doğal Maden Suyu'), isTrue);
      expect(OpenFoodFactsService.isPureNaturalFoodName('Organik Yumurta'), isTrue);
    });

    test('ReceiptOcrService.parseReceiptText filters tax/total lines and extracts food items', () {
      const sampleReceipt = '''
        BIM BIRLESIK MAGAZALAR A.S.
        TARIH: 26.11.2026 SAAT: 14:22
        SIZMA ZEYTINYAGI 1 LT *245,00
        %01 KDV
        DOMATES SALKIM 1.250 KG *49,90
        KURU SOGAN 2 KG *32,50
        ALISVERIS POSETI *0,25
        ARA TOPLAM 327,65
        TOPKDV 3,27
        TOPLAM *327,65
        KREDI KARTI ILE ODEME
        TESEKKURLER IYI GUNLER
      ''';

      final parsed = ReceiptOcrService.parseReceiptText(sampleReceipt);
      final tags = parsed.map((e) => e.template.tag).toSet();

      expect(tags, contains('zeytinyagi'));
      expect(tags, contains('domates'));
      expect(tags, contains('sogan'));
      expect(tags.any((t) => t.contains('toplam') || t.contains('kdv') || t.contains('poset')), isFalse);
    });

    test('SubscriptionService.redeemPromoCode rejects invalid codes and enforces single-use', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      final service = SubscriptionService.instance;

      final invalidRes = await service.redeemPromoCode('RASTGELE123');
      expect(invalidRes.status, PromoCodeStatus.invalid);

      final validRes = await service.redeemPromoCode('KILERCE2026');
      expect(validRes.status, PromoCodeStatus.success);
      expect(await service.isAdFree(), isTrue);

      final reuseRes = await service.redeemPromoCode('kilerce2026');
      expect(reuseRes.status, PromoCodeStatus.alreadyRedeemed);
    });

    test('KilerceBackupService encodes and decodes v2.0 full backup payloads', () {
      final encoded = KilerceBackupService.encodeBackupPayload(
        profileJson: {'displayName': 'Ayşe', 'xp': 120},
        tables: {
          'pantry_items': [
            {'name': 'Zeytinyağı', 'normalized_tag': 'zeytinyagi'},
          ],
          'shopping_list': [],
        },
        createdAtMs: 1700000000000,
      );

      final decoded = KilerceBackupService.decodeBackupPayload(encoded);
      expect(decoded, isNotNull);
      expect(decoded!['app'], 'Kilerce');
      expect(decoded['version'], KilerceBackupService.currentSchemaVersion);
      expect((decoded['profile'] as Map)['displayName'], 'Ayşe');
      expect(((decoded['tables'] as Map)['pantry_items'] as List).length, 1);

      // Backward compatibility check for v1.0 profile-only JSON
      final v1Decoded = KilerceBackupService.decodeBackupPayload(
        '{"app":"OrganicScore","version":"1.0.0","profile":{"displayName":"Mehmet"}}',
      );
      expect(v1Decoded, isNotNull);
      expect((v1Decoded!['profile'] as Map)['displayName'], 'Mehmet');
    });
  });
}
