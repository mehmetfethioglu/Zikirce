import 'package:flutter_test/flutter_test.dart';
import 'package:organicscore/features/taklit_tagsis/domain/taklit_tagsis_service.dart';

void main() {
  group('TaklitTagsisService Grouping & Classification Tests', () {
    test('groups items by brand and calculates hazards correctly', () {
      final now = DateTime.now();
      final items = [
        TaklitTagsisItem(
          id: 1,
          brandName: 'GÜRSÜT',
          companyName: 'Gürsüt Mandıra Sanayi A.Ş.',
          productName: 'Tam Yağlı Kaşar',
          reason: '[Taklit/Tağşiş - Madde Eklenmesi] Bitkisel Yağ Tespiti',
          category: 'Süt ve Süt Ürünleri',
          announcedAt: now.subtract(const Duration(days: 2)),
        ),
        TaklitTagsisItem(
          id: 2,
          brandName: 'GÜRSÜT',
          companyName: 'Gürsüt Mandıra Sanayi A.Ş.',
          productName: 'Tost Peyniri',
          reason: '[Taklit/Tağşiş - Madde Eklenmesi] Nişasta Tespiti',
          category: 'Süt ve Süt Ürünleri',
          announcedAt: now.subtract(const Duration(days: 1)),
        ),
        TaklitTagsisItem(
          id: 3,
          brandName: 'KÖFTECİ YUSUF',
          companyName: 'Köfteci Yusuf Hazır Yemek San. ve Tic. A.Ş.',
          productName: 'Pişmiş Köfte',
          reason: '[Sağlığı Tehlikeye Düşürecek Gıdalar] Domuz Eti Tespiti',
          category: 'Et ve Et Ürünleri',
          announcedAt: now,
        ),
        TaklitTagsisItem(
          id: 4,
          brandName: '-',
          companyName: 'ZEYNEP ET VE TAVUK DÜNYASI-MERYEM SUBAŞI',
          productName: 'Dana Kıyma',
          reason: '[Sağlığı Tehlikeye Düşürecek Gıdalar] Tek Tırnaklı Eti Tespiti',
          category: 'Et ve Et Ürünleri',
          announcedAt: now.subtract(const Duration(days: 5)),
        ),
      ];

      final groups = TaklitTagsisService.groupItemsByBrand(items);

      expect(groups.length, 3);

      // 1. Köfteci Yusuf (most recent date)
      final yusuf = groups.firstWhere((g) => g.brandName.toUpperCase().contains('KÖFTECİ YUSUF'));
      expect(yusuf.productCount, 1);
      expect(yusuf.hasHealthHazard, isTrue);
      expect(yusuf.primaryCategory, 'Et ve Et Ürünleri');
      expect(yusuf.primaryReasonSummary, contains('Domuz Eti Tespiti'));

      // 2. Gürsüt (2 products, no health hazard -> fraud)
      final gursut = groups.firstWhere((g) => g.brandName.toUpperCase().contains('GÜRSÜT'));
      expect(gursut.productCount, 2);
      expect(gursut.hasHealthHazard, isFalse);
      expect(gursut.uniqueReasons.length, 2);
      expect(gursut.uniqueReasons, contains('Bitkisel Yağ Tespiti'));
      expect(gursut.uniqueReasons, contains('Nişasta Tespiti'));

      // 3. Fallback brand from company name '-'
      final fallbackGroup = groups.firstWhere((g) => g.companyName.contains('MERYEM SUBAŞI'));
      expect(fallbackGroup.brandName, 'ZEYNEP ET VE TAVUK DÜNYASI');
      expect(fallbackGroup.hasHealthHazard, isTrue);
      expect(fallbackGroup.primaryReasonSummary, contains('Tek Tırnaklı Eti Tespiti'));
    });

    test('isItemMatching prevents false positives on brands like Eti and generic terms', () {
      final ergunItem = TaklitTagsisItem(
        id: 10,
        brandName: 'ERGÜN SUCUKLARI',
        companyName: 'ERGÜN ET VE ET ÜRÜNLERİ- ERGÜN SUCUK İMALATHANESİ-METİN ERGÜN',
        productName: 'ISIL İŞLEM GÖRMÜŞ DANA SUCUK',
        reason: 'Tek Tırnaklı Eti Tespiti',
        category: 'Et ve Et Ürünleri',
        announcedAt: DateTime.now(),
      );

      final tadindaAyran = TaklitTagsisItem(
        id: 11,
        brandName: 'TADINDA',
        companyName: 'MİRZABEY ET SÜT ÜRÜNLERİ SANAYİ TİCARET LİMİTED ŞİRKETİ',
        productName: 'AYRAN',
        reason: '% Protein Oranının Düşük Olması',
        category: 'Süt ve Süt Ürünleri',
        announcedAt: DateTime.now(),
      );

      // 1. Eti Lifalif must NEVER match Ergün Sucukları (even though reason has "Eti" and company has "şirketi"/"metin")
      expect(
        TaklitTagsisService.isItemMatching(
          ergunItem,
          productName: 'Lifalif Yulaf Ezmesi',
          brandName: 'Eti',
        ),
        isFalse,
      );

      // 2. Eti Browni must NEVER match Ergün Sucukları
      expect(
        TaklitTagsisService.isItemMatching(
          ergunItem,
          productName: 'Browni İntense',
          brandName: 'Eti',
        ),
        isFalse,
      );

      // 3. Sütaş Ayran must NEVER match Tadında Ayran just because productName contains 'Ayran'
      expect(
        TaklitTagsisService.isItemMatching(
          tadindaAyran,
          productName: 'Sütaş Ayran',
          brandName: 'Sütaş',
        ),
        isFalse,
      );

      // 4. Ergün Sucukları Dana Sucuk MUST match correctly
      expect(
        TaklitTagsisService.isItemMatching(
          ergunItem,
          productName: 'Dana Sucuk',
          brandName: 'Ergün Sucukları',
        ),
        isTrue,
      );

      // 5. Ergün single word brand MUST match Ergün Sucukları
      expect(
        TaklitTagsisService.isItemMatching(
          ergunItem,
          productName: 'Sucuk',
          brandName: 'Ergün',
        ),
        isTrue,
      );

      // 6. Tadında Ayran MUST match Tadında
      expect(
        TaklitTagsisService.isItemMatching(
          tadindaAyran,
          productName: 'Ayran',
          brandName: 'Tadında',
        ),
        isTrue,
      );
    });
  });
}
