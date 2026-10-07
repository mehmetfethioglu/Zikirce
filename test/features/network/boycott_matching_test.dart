import 'package:flutter_test/flutter_test.dart';
import 'package:organicscore/features/network/domain/offline_fallback_manager.dart';

void main() {
  group('Zero-False-Positive Boycott Matching Engine Tests', () {
    // Representative mock boycott database containing brands that previously triggered false positives
    final List<Map<String, dynamic>> mockBoycottBrands = [
      {
        'brand_name': 'Fa',
        'parent_company': 'Henkel',
        'status_flag': 'FLAGGED',
        'reason': 'Henkel grup markası ve İsrail ortaklıkları.',
      },
      {
        'brand_name': 'Ge',
        'parent_company': 'General Electric',
        'status_flag': 'FLAGGED',
        'reason': 'İsrail askeri ve enerji teknolojisi yatırımları.',
      },
      {
        'brand_name': 'Erikli',
        'parent_company': 'Nestle',
        'status_flag': 'FLAGGED',
        'reason': 'Nestle çatı şirketi ve işgal bölgesi yatırımları.',
      },
      {
        'brand_name': 'Mars',
        'parent_company': 'Mars Inc.',
        'status_flag': 'FLAGGED',
        'reason': 'İsrail merkezli gıda girişim yatırımları.',
      },
      {
        'brand_name': 'Coca-Cola',
        'parent_company': 'The Coca-Cola Company',
        'status_flag': 'FLAGGED',
        'reason': 'Filistin işgal bölgelerindeki fabrika yatırımları ve BDS hedefi.',
      },
      {
        'brand_name': 'Coca Cola',
        'parent_company': 'The Coca-Cola Company',
        'status_flag': 'FLAGGED',
        'reason': 'Filistin işgal bölgelerindeki fabrika yatırımları ve BDS hedefi.',
      },
      {
        'brand_name': 'Fanta',
        'parent_company': 'The Coca-Cola Company',
        'status_flag': 'FLAGGED',
        'reason': 'The Coca-Cola Company grup markası.',
      },
      {
        'brand_name': 'Nescafe',
        'parent_company': 'Nestle',
        'status_flag': 'FLAGGED',
        'reason': 'Nestle iştiraki.',
      },
      {
        'brand_name': 'Danone',
        'parent_company': 'Danone S.A.',
        'status_flag': 'CAUTION',
        'reason': 'Strauss Group ortaklığı ve inceleme altında.',
      },
      {
        'brand_name': 'Lipton',
        'parent_company': 'Ekaterra',
        'status_flag': 'CAUTION',
        'reason': 'Kurumsal bağlantı incelemesinde.',
      },
      {
        'brand_name': 'Starbucks',
        'parent_company': 'Starbucks Corporation',
        'status_flag': 'FLAGGED',
        'reason': 'Filistin açıklamalarına karşı sendika davası ve kurumsal tutum.',
      },
      {
        'brand_name': 'Oreo',
        'parent_company': 'Mondelez',
        'status_flag': 'FLAGGED',
        'reason': 'Mondelez International grup markası.',
      },
    ];

    group('Eti Brand False-Positive Elimination (Bug Reproduction & Fix)', () {
      test('Eti Lifalif Yulaf Ezmesi must NOT match Fa -> CLEAR', () {
        final result = OfflineFallbackManager.evaluateBoycottStatus(
          productName: 'Lifalif Yulaf Ezmesi',
          brandName: 'Eti',
          boycottBrands: mockBoycottBrands,
        );

        expect(result['status_flag'], equals('CLEAR'));
        expect(result['brand_name'], equals('Eti'));
      });

      test('Lifalif Ince Ogutulmus Yulaf Ezmesi with brand Eti Lifalif -> CLEAR', () {
        final result = OfflineFallbackManager.evaluateBoycottStatus(
          productName: 'İnce Öğütülmüş Yulaf Ezmesi',
          brandName: 'Eti Lifalif',
          boycottBrands: mockBoycottBrands,
        );

        expect(result['status_flag'], equals('CLEAR'));
      });

      test('Eti Burcak Bitkisel icerikli must NOT match Erikli -> CLEAR', () {
        final result = OfflineFallbackManager.evaluateBoycottStatus(
          productName: 'Eti Burçak Bitkisel içerikli Çok Tahıllı Bisküvi',
          brandName: 'Eti',
          boycottBrands: mockBoycottBrands,
        );

        expect(result['status_flag'], equals('CLEAR'));
      });

      test('Eti Karam Bitter Cikolata -> CLEAR', () {
        final result = OfflineFallbackManager.evaluateBoycottStatus(
          productName: 'Eti Karam Bitter Çikolata 50g',
          brandName: 'Eti',
          boycottBrands: mockBoycottBrands,
        );

        expect(result['status_flag'], equals('CLEAR'));
      });

      test('Sut Burger must NOT match Ge -> CLEAR', () {
        final result = OfflineFallbackManager.evaluateBoycottStatus(
          productName: 'Süt Burger Ballı',
          brandName: 'Eti',
          boycottBrands: mockBoycottBrands,
        );

        expect(result['status_flag'], equals('CLEAR'));
      });

      test('Eti Crax Cubuk Kraker -> CLEAR', () {
        final result = OfflineFallbackManager.evaluateBoycottStatus(
          productName: 'Crax Patlayan Lezzet Baharatlı Çubuk Kraker',
          brandName: 'Eti',
          boycottBrands: mockBoycottBrands,
        );

        expect(result['status_flag'], equals('CLEAR'));
      });

      test('Lifalif with generic brand should still NOT match Fa due to word boundaries -> CLEAR', () {
        final result = OfflineFallbackManager.evaluateBoycottStatus(
          productName: 'Lifalif Yulaf Ezmesi 500g',
          brandName: 'Yerli Üretici',
          boycottBrands: mockBoycottBrands,
        );

        expect(result['status_flag'], equals('CLEAR'));
      });
    });

    group('Other Safe Domestic Brands Verification', () {
      test('Torku Banada Findik Kremasi -> CLEAR', () {
        final result = OfflineFallbackManager.evaluateBoycottStatus(
          productName: 'Banada Kakaolu Fındık Kreması',
          brandName: 'Torku',
          boycottBrands: mockBoycottBrands,
        );

        expect(result['status_flag'], equals('CLEAR'));
      });

      test('Pinar Sut 1L -> CLEAR', () {
        final result = OfflineFallbackManager.evaluateBoycottStatus(
          productName: 'Tam Yağlı Süt 1 Litre',
          brandName: 'Pınar',
          boycottBrands: mockBoycottBrands,
        );

        expect(result['status_flag'], equals('CLEAR'));
      });

      test('Sutas Ayran 300ml -> CLEAR', () {
        final result = OfflineFallbackManager.evaluateBoycottStatus(
          productName: 'Geleneksel Ayran 300ml',
          brandName: 'Sütaş',
          boycottBrands: mockBoycottBrands,
        );

        expect(result['status_flag'], equals('CLEAR'));
      });
    });

    group('Known Boycott Targets Detection (Recall Check)', () {
      test('Coca-Cola with official brand -> FLAGGED', () {
        final result = OfflineFallbackManager.evaluateBoycottStatus(
          productName: 'Orijinal Tat Kutu Kola 330ml',
          brandName: 'Coca-Cola',
          boycottBrands: mockBoycottBrands,
        );

        expect(result['status_flag'], equals('FLAGGED'));
        expect(result['brand_name'], equals('Coca-Cola'));
      });

      test('Coca cola 2lt with generic brand -> FLAGGED', () {
        final result = OfflineFallbackManager.evaluateBoycottStatus(
          productName: 'Coca cola 2lt pet şişe',
          brandName: 'Yerli Üretici',
          boycottBrands: mockBoycottBrands,
        );

        expect(result['status_flag'], equals('FLAGGED'));
      });

      test('Fanta Portakal 2.5 lt with generic brand -> FLAGGED', () {
        final result = OfflineFallbackManager.evaluateBoycottStatus(
          productName: 'fanta portakal 2.5 lt',
          brandName: 'Yerli Üretici',
          boycottBrands: mockBoycottBrands,
        );

        expect(result['status_flag'], equals('FLAGGED'));
      });

      test('Nescafe 3u1 arada with generic brand -> FLAGGED', () {
        final result = OfflineFallbackManager.evaluateBoycottStatus(
          productName: 'Nescafe 3ü1 arada hazır kahve',
          brandName: 'Yerli Üretici',
          boycottBrands: mockBoycottBrands,
        );

        expect(result['status_flag'], equals('FLAGGED'));
      });

      test('Erikli 1lt su with generic brand -> FLAGGED (matched as standalone token)', () {
        final result = OfflineFallbackManager.evaluateBoycottStatus(
          productName: 'Erikli 1lt doğal kaynak suyu',
          brandName: 'Yerli Üretici',
          boycottBrands: mockBoycottBrands,
        );

        expect(result['status_flag'], equals('FLAGGED'));
        expect(result['brand_name'], equals('Erikli'));
      });

      test('Danone Cilekli Yogurt -> CAUTION', () {
        final result = OfflineFallbackManager.evaluateBoycottStatus(
          productName: 'Danone Çilekli Yoğurt 4x100g',
          brandName: 'Danone',
          boycottBrands: mockBoycottBrands,
        );

        expect(result['status_flag'], equals('CAUTION'));
      });

      test('Starbucks Frappuccino -> FLAGGED', () {
        final result = OfflineFallbackManager.evaluateBoycottStatus(
          productName: 'Frappuccino Mocha Kahve 250ml',
          brandName: 'Starbucks',
          boycottBrands: mockBoycottBrands,
        );

        expect(result['status_flag'], equals('FLAGGED'));
      });

      test('Oreo Original Biskuvi -> FLAGGED', () {
        final result = OfflineFallbackManager.evaluateBoycottStatus(
          productName: 'Oreo Orijinal Kakaolu Bisküvi',
          brandName: 'Oreo',
          boycottBrands: mockBoycottBrands,
        );

        expect(result['status_flag'], equals('FLAGGED'));
      });
    });
  });
}
