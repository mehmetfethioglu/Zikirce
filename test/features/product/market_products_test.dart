import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Turkish Market Products Database Integrity Tests (BİM, A101, ŞOK, Migros)', () {
    late List<dynamic> products;

    setUpAll(() {
      final file = File('assets/data/top_turkiye_ai_snapshots.json');
      expect(file.existsSync(), isTrue, reason: 'Market snapshots asset file must exist');
      final content = file.readAsStringSync();
      products = jsonDecode(content) as List<dynamic>;
    });

    test('Database contains high volume of verified Turkish market items', () {
      expect(products.length, greaterThanOrEqualTo(900));
    });

    test('BİM private label products exist and are fully populated with scores and NOVA', () {
      final bimBrands = ['Dost', 'Aknaz', 'Efsane', 'Saban', 'Sole', 'Yurdum', 'Simbat', 'Peripella', 'Derya'];
      for (final brand in bimBrands) {
        final matches = products.where((p) =>
            (p['brand'] as String? ?? '').toLowerCase().contains(brand.toLowerCase()) ||
            (p['product_name'] as String? ?? '').toLowerCase().contains(brand.toLowerCase()));
        expect(matches.isNotEmpty, isTrue, reason: 'Expected BİM brand "$brand" to exist in database');

        for (final p in matches.take(3)) {
          final barcode = p['barcode'] as String;
          expect(barcode.length, greaterThanOrEqualTo(8));
          final summary = p['ai_summary_json'] as Map<String, dynamic>;
          final score = summary['organic_score'] as int;
          expect(score, inInclusiveRange(0, 100));
          final nova = summary['nova_group'] as int;
          expect(nova, inInclusiveRange(1, 4));
          expect((summary['summary'] as String).isNotEmpty, isTrue);
        }
      }
    });

    test('A101 private label products exist and have valid biochemistry scores', () {
      final a101Brands = ['Birşah', 'Tarabya', 'Peynes', 'Ahir', 'Vera', 'Ovadan', 'Çokça', 'Bendo'];
      for (final brand in a101Brands) {
        final matches = products.where((p) =>
            (p['brand'] as String? ?? '').toLowerCase().contains(brand.toLowerCase()) ||
            (p['product_name'] as String? ?? '').toLowerCase().contains(brand.toLowerCase()));
        expect(matches.isNotEmpty, isTrue, reason: 'Expected A101 brand "$brand" to exist in database');

        final first = matches.first;
        final summary = first['ai_summary_json'] as Map<String, dynamic>;
        expect(summary['organic_score'], inInclusiveRange(0, 100));
        expect(summary['nova_group'], inInclusiveRange(1, 4));
      }
    });

    test('ŞOK private label products exist and have valid biochemistry scores', () {
      final sokBrands = ['Mis', 'Piyale', 'Lio', 'Evin', 'Amigo', 'Karmen'];
      for (final brand in sokBrands) {
        final matches = products.where((p) =>
            (p['brand'] as String? ?? '').toLowerCase().contains(brand.toLowerCase()) ||
            (p['product_name'] as String? ?? '').toLowerCase().contains(brand.toLowerCase()));
        expect(matches.isNotEmpty, isTrue, reason: 'Expected ŞOK brand "$brand" to exist in database');

        final first = matches.first;
        final summary = first['ai_summary_json'] as Map<String, dynamic>;
        expect(summary['organic_score'], inInclusiveRange(0, 100));
        expect(summary['nova_group'], inInclusiveRange(1, 4));
      }
    });

    test('Top national market brands (Ülker, Eti, Torku, Sütaş, Pınar, Beypazarı, Dimes) exist', () {
      final nationalBrands = ['Ülker', 'Eti', 'Torku', 'Sütaş', 'Pınar', 'Beypazarı', 'Dimes', 'Züber', 'Çaykur'];
      for (final brand in nationalBrands) {
        final matches = products.where((p) =>
            (p['brand'] as String? ?? '').toLowerCase().contains(brand.toLowerCase()) ||
            (p['product_name'] as String? ?? '').toLowerCase().contains(brand.toLowerCase()));
        expect(matches.isNotEmpty, isTrue, reason: 'Expected national brand "$brand" to exist in database');
      }
    });

    test('Zero missing or corrupted items in dataset (Poka-Yoke check)', () {
      final seenBarcodes = <String>{};
      for (final p in products) {
        final barcode = p['barcode'] as String?;
        expect(barcode, isNotNull);
        expect(barcode!.trim().isNotEmpty, isTrue);
        expect(seenBarcodes.contains(barcode), isFalse, reason: 'Duplicate barcode: $barcode');
        seenBarcodes.add(barcode);

        final name = p['product_name'] as String?;
        expect(name, isNotNull);
        expect(name!.trim().isNotEmpty, isTrue);

        final summary = p['ai_summary_json'] as Map<String, dynamic>?;
        expect(summary, isNotNull);
        expect(summary!['organic_score'] as int, inInclusiveRange(0, 100));
        expect(summary['nova_group'] as int, inInclusiveRange(1, 4));
        expect((summary['verdict'] as String).isNotEmpty, isTrue);
      }
    });
  });
}
