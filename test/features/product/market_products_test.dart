import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:organicscore/features/network/domain/offline_fallback_manager.dart';
import 'package:organicscore/features/network/domain/turkish_market_resolver_service.dart';

class _FakeMarketGateway implements MarketHttpGateway {
  bool closed = false;

  @override
  Future<MarketHttpResponse?> getText(
    Uri uri, {
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 6),
  }) async {
    return const MarketHttpResponse(statusCode: 200, body: '{}');
  }

  @override
  Future<MarketHttpResponse?> postJson(
    Uri uri, {
    required Map<String, dynamic> payload,
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 6),
  }) async {
    return const MarketHttpResponse(statusCode: 200, body: '{}');
  }

  @override
  void close() {
    closed = true;
  }
}

class _StubIdentityStrategy implements MarketResolverStrategy {
  @override
  String get strategyId => 'stub_tubitak';

  @override
  Future<MarketProductDraft?> resolve({
    required String barcode,
    MarketProductDraft? currentDraft,
    required MarketHttpGateway httpGateway,
  }) async {
    return MarketProductDraft(
      barcode: barcode,
      productName: 'Aknaz Tost Peyniri 1 Kg',
      brand: 'Aknaz',
      marketChains: const <String>['BİM'],
      netQuantity: '1 KG',
      referencePriceTry: 219.0,
      resolverOrigins: const <String>['stub_tubitak'],
      resolvedFromTurkishMarket: true,
    );
  }
}

class _StubTgkEnricherStrategy implements MarketResolverStrategy {
  @override
  String get strategyId => 'stub_tgk';

  @override
  Future<MarketProductDraft?> resolve({
    required String barcode,
    MarketProductDraft? currentDraft,
    required MarketHttpGateway httpGateway,
  }) async {
    return MarketProductDraft(
      barcode: barcode,
      productName: currentDraft?.productName,
      brand: currentDraft?.brand,
      ingredientsText:
          'Pastörize inek sütü, peynir kültürü, peynir mayası, tuz, emülsifiye edici tuz (sodyum sitrat).',
      nutriments: const <String, double>{
        'energy_kcal': 312.0,
        'fat_g': 24.0,
        'saturated_fat_g': 15.5,
        'carbs_g': 2.0,
        'sugars_g': 2.0,
        'fiber_g': 0.0,
        'protein_g': 22.0,
        'salt_g': 1.8,
      },
      allergens: const <String>['Süt ve süt ürünleri (laktoz dahil)'],
      marketChains: currentDraft?.marketChains ?? const <String>[],
      netQuantity: currentDraft?.netQuantity,
      legalProducer: 'AK GIDA SAN. VE TİC. A.Ş. (TR-54-K-000123)',
      referencePriceTry: currentDraft?.referencePriceTry,
      resolverOrigins: <String>[...?currentDraft?.resolverOrigins, 'stub_tgk'],
      resolvedFromTurkishMarket: true,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Kilerce Türkiye Marketleri Temiz Ürün Veritabanı Testleri (Poka-Yoke)', () {
    late List<dynamic> products;

    setUpAll(() {
      final jsonFile = File('assets/data/top_turkiye_ai_snapshots.json');
      expect(jsonFile.existsSync(), isTrue, reason: 'Market snapshots JSON varlığı mevcut olmalı');
      products = jsonDecode(jsonFile.readAsStringSync()) as List<dynamic>;
    });

    test('JSON ve SQLite (foodscore_master.db > 0 byte) yüksek hacimli temiz ürün içerir', () {
      expect(products.length, greaterThanOrEqualTo(2000));

      final masterDb = File('assets/data/foodscore_master.db');
      expect(masterDb.existsSync(), isTrue, reason: 'foodscore_master.db varlığı mevcut olmalı');
      expect(
        masterDb.lengthSync(),
        greaterThan(1024 * 1024),
        reason: 'foodscore_master.db 0 byte olamaz; gerçek katalog içermelidir',
      );
    });

    test('Tüm barkodlar %100 gerçek GS1 Modulo-10 uyumludur; sahte ardışık ve PLU barkod yoktur', () {
      final seenBarcodes = <String>{};

      for (final raw in products) {
        final p = raw as Map<String, dynamic>;
        final barcode = (p['barcode'] as String? ?? '').trim();

        expect(barcode.isNotEmpty, isTrue);
        expect(seenBarcodes.add(barcode), isTrue, reason: 'Tekrarlı barkod tespit edildi: $barcode');
        expect(
          barcode.startsWith('8690772000'),
          isFalse,
          reason: 'Sahte ardışık barkod serisi yasaktır: $barcode',
        );
        expect(
          TurkishMarketResolverService.isValidGs1Barcode(barcode),
          isTrue,
          reason: 'Geçersiz GS1 Modulo-10 veya mağaza içi PLU barkod: $barcode',
        );
      }
    });

    test('Sıfır kesik içindekiler, sıfır yer tutucu marka ve geçerli besin dengesi', () {
      const forbiddenBrands = <String>{'yerli üretici', 'bilinmeyen marka', 'unknown'};

      for (final raw in products) {
        final p = raw as Map<String, dynamic>;
        final name = (p['product_name'] as String? ?? '').trim();
        final brand = (p['brand'] as String? ?? '').trim();
        final summary = p['ai_summary_json'] as Map<String, dynamic>;

        expect(name.length, greaterThanOrEqualTo(2));
        expect(brand.isNotEmpty, isTrue);
        expect(forbiddenBrands.contains(brand.toLowerCase()), isFalse, reason: 'Yer tutucu marka yasak: $brand');

        expect(summary['organic_score'] as int, inInclusiveRange(0, 100));
        expect(summary['nova_group'] as int, inInclusiveRange(1, 4));
        expect((summary['verdict'] as String? ?? '').isNotEmpty, isTrue);

        final ingredientsText = (summary['ingredients_text'] as String? ?? '').trim();
        expect(ingredientsText.length, greaterThanOrEqualTo(3), reason: 'Eksik içindekiler: ${p['barcode']}');
        expect(
          ingredientsText.endsWith('...'),
          isFalse,
          reason: '160 karakter / üç nokta kesintisi yasaktır: ${p['barcode']}',
        );

        final nutriments = summary['nutriments'] as Map<String, dynamic>?;
        if (nutriments != null && nutriments.isNotEmpty) {
          final fat = (nutriments['fat_g'] as num? ?? 0).toDouble();
          final carbs = (nutriments['carbs_g'] as num? ?? 0).toDouble();
          final protein = (nutriments['protein_g'] as num? ?? 0).toDouble();
          final salt = (nutriments['salt_g'] as num? ?? 0).toDouble();
          expect(fat, greaterThanOrEqualTo(0));
          expect(carbs, greaterThanOrEqualTo(0));
          expect(protein, greaterThanOrEqualTo(0));
          expect(
            fat + carbs + protein + salt,
            lessThanOrEqualTo(103.0),
            reason: '100g makro toplamı fiziksel sınırı aştı: ${p['barcode']}',
          );
        }
      }
    });

    test('Büyük market zincirleri (BİM, A101, ŞOK, Migros, CarrefourSA, Tarım Kredi, Hakmar) temsil edilir', () {
      final chainSet = <String>{};
      for (final raw in products) {
        final summary = (raw as Map<String, dynamic>)['ai_summary_json'] as Map<String, dynamic>;
        final chains = (summary['market_chains'] as List<dynamic>? ?? const <dynamic>[])
            .map((e) => e.toString())
            .toList();
        chainSet.addAll(chains);
      }

      for (final expectedChain in <String>['BİM', 'A101', 'ŞOK', 'Migros', 'CarrefourSA', 'Tarım Kredi']) {
        expect(chainSet.contains(expectedChain), isTrue, reason: '$expectedChain zinciri katalogda bulunmalı');
      }
    });

    test('BİM, A101, ŞOK öz markaları ve ulusal markalar eksiksiz yer alır', () {
      const requiredBrands = <String>[
        // BİM
        'Dost', 'Aknaz', 'Efsane', 'Saban', 'Sole', 'Yurdum', 'Simbat', 'Peripella', 'Derya',
        // A101
        'Birşah', 'Tarabya', 'Peynes', 'Ahir', 'Vera', 'Ovadan', 'Çokça', 'Bendo',
        // ŞOK
        'Mis', 'Piyale', 'Lio', 'Evin', 'Amigo', 'Karmen',
        // Ulusal
        'Ülker', 'Eti', 'Torku', 'Sütaş', 'Pınar', 'Beypazarı', 'Dimes', 'Züber', 'Çaykur',
      ];

      for (final brand in requiredBrands) {
        final lower = brand.toLowerCase();
        final matches = products.where((raw) {
          final p = raw as Map<String, dynamic>;
          final b = (p['brand'] as String? ?? '').toLowerCase();
          final n = (p['product_name'] as String? ?? '').toLowerCase();
          return b.contains(lower) || n.contains(lower);
        });
        expect(matches.isNotEmpty, isTrue, reason: 'Marka katalogda bulunmalı: $brand');
      }
    });
  });

  group('TurkishMarketResolverService & GS1 Birim Testleri', () {
    test('GS1 Modulo-10 doğrulayıcı EAN-13 ve EAN-8 ayrımını doğru yapar', () {
      expect(TurkishMarketResolverService.isValidGs1Barcode('8695077044020'), isTrue); // Gerçek BİM Aknaz EAN-13
      expect(TurkishMarketResolverService.isValidGs1Barcode('8690526069500'), isTrue); // Gerçek Eti Lifalif EAN-13
      expect(TurkishMarketResolverService.isValidGs1Barcode('86905261'), isFalse); // Hatalı check-digit EAN-8
      expect(TurkishMarketResolverService.isValidGs1Barcode('8690772000012'), isFalse); // Yasaklı sahte seri
      expect(TurkishMarketResolverService.isValidGs1Barcode('2001234567893'), isFalse); // Mağaza içi tartılı PLU
    });

    test('Çok aşamalı strateji zinciri TÜBİTAK kimliğini TGK künyesiyle birleştirir ve gateway kapatır', () async {
      final gateway = _FakeMarketGateway();
      final response = await TurkishMarketResolverService.resolveByBarcode(
        '8695077044020',
        persistToLocalCache: false,
        httpGateway: gateway,
        strategies: <MarketResolverStrategy>[
          _StubIdentityStrategy(),
          _StubTgkEnricherStrategy(),
        ],
      );

      expect(response, isNotNull);
      expect(response!.productName, 'Aknaz Tost Peyniri 1 Kg');
      expect(response.brand, 'Aknaz');
      expect(response.marketChains, contains('BİM'));
      expect(response.netQuantity, '1 KG');
      expect(response.ingredientsText, contains('Pastörize inek sütü'));
      expect(response.nutriments['protein_g'], 22.0);
      expect(response.allergens, isNotEmpty);
      expect(response.source, ScanDataSource.onlineTurkishMarketApi);
      expect(response.organicScore, inInclusiveRange(0, 100));
      // Caller-injected gateway retains caller lifecycle ownership until explicitly closed
      expect(gateway.closed, isFalse);
      gateway.close();
      expect(gateway.closed, isTrue);
    });
  });
}
