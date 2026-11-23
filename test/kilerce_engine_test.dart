import 'package:flutter_test/flutter_test.dart';
import 'package:organicscore/features/family_profiles/domain/family_profile_engine.dart';
import 'package:organicscore/features/kiler/domain/kiler_models.dart';
import 'package:organicscore/features/kiler/domain/receipt_ocr_service.dart';
import 'package:organicscore/features/recipes/domain/recipe_recommendation_engine.dart';

void main() {
  group('Kilerce Akıllı Envanter & Tarif Motoru Testleri', () {
    test('IngredientNormalizer taze ve paketli gıdaları doğru kategori ve konuma eşler', () {
      final domates = IngredientNormalizer.resolveMetadata('Salkım Domates 1 Kg');
      expect(domates.tag, 'domates');
      expect(domates.defaultZone, StorageZone.fridge);

      final mercimek = IngredientNormalizer.resolveMetadata('Anadolu Kırmızı Mercimek');
      expect(mercimek.tag, 'kirmizi_mercimek');
      expect(mercimek.defaultZone, StorageZone.pantry);

      final tavuk = IngredientNormalizer.resolveMetadata('Piliç Bonfile Göğüs');
      expect(tavuk.tag, 'tavuk');
      expect(tavuk.defaultShelfDays, 3);
    });

    test('ReceiptOcrService market fişi metninden fiyatları ve toplam satırlarını temizler', () {
      const rawReceipt = '''
      TARIH: 08/11/2026 SAAT: 19:45
      FIS NO: 0042
      SALKIM DOMATES       %01  *45,90
      GEZEN TAVUK YUMURTA  %01  *89,50
      SIZMA ZEYTINYAGI     %01  *320,00
      TOPLAM                    *455,40
      KREDI KARTI               *455,40
      TESEKKUR EDERIZ
      ''';

      final parsed = ReceiptOcrService.parseReceiptText(rawReceipt);
      final tags = parsed.map((e) => e.template.tag).toSet();

      expect(tags.contains('domates'), isTrue);
      expect(tags.contains('yumurta'), isTrue);
      expect(tags.contains('zeytinyagi'), isTrue);
      expect(parsed.any((e) => e.rawLine.toLowerCase().contains('toplam')), isFalse);
    });

    test('RecipeRecommendationEngine %100 eşleşen ve israf önleyici tarifleri önceliklendirir', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      const dayMs = 86400000;

      final pantry = [
        PantryItem(
          name: 'Yumurta',
          normalizedTag: 'yumurta',
          brand: 'Köy',
          category: 'Et, Tavuk & Yumurta',
          storageZone: StorageZone.fridge,
          quantityLevel: QuantityLevel.full,
          unitLabel: '10 Adet',
          healthScore: 96,
          addedAt: now,
          expiresAt: now + (10 * dayMs),
        ),
        PantryItem(
          name: 'Domates',
          normalizedTag: 'domates',
          brand: 'Manav',
          category: 'Sebze & Meyve',
          storageZone: StorageZone.fridge,
          quantityLevel: QuantityLevel.full,
          unitLabel: '1 Kg',
          healthScore: 98,
          addedAt: now,
          expiresAt: now + (1 * dayMs), // Expiring in 1 day!
        ),
        PantryItem(
          name: 'Sivri Biber',
          normalizedTag: 'biber',
          brand: 'Manav',
          category: 'Sebze & Meyve',
          storageZone: StorageZone.fridge,
          quantityLevel: QuantityLevel.half,
          unitLabel: '500 gr',
          healthScore: 97,
          addedAt: now,
          expiresAt: now + (2 * dayMs),
        ),
      ];

      final glutenFreeProfile = FamilyProfile(
        id: 1,
        profileName: 'Glutensiz Profil',
        isActive: true,
        restrictions: const ['GLUTEN'],
      );

      final readyMatches = RecipeRecommendationEngine.evaluateAll(
        pantryItems: pantry,
        activeProfile: glutenFreeProfile,
        filter: RecipeFilterTab.readyNow,
      );

      expect(readyMatches.isNotEmpty, isTrue);
      final menemen = readyMatches.firstWhere((m) => m.recipe.id == 'menemen');
      expect(menemen.isReadyToCook, isTrue);
      expect(menemen.preventsFoodWaste, isTrue);
      expect(menemen.isProfileSafe, isTrue);
    });
  });
}
