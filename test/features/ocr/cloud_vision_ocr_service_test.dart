import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:organicscore/features/kiler/domain/kiler_models.dart';
import 'package:organicscore/features/kiler/domain/receipt_ocr_service.dart';
import 'package:organicscore/features/ocr/domain/cloud_vision_ocr_service.dart';

void main() {
  group('CloudVisionOcrService & ReceiptOcrService.mapCloudItems', () {
    test('analyzeReceiptImageBytes signs POST /api/ocr/receipt and maps items', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'source': 'gemini_2_5_flash_lite',
            'cached': false,
            'items': [
              {
                'name': 'Yarım Yağlı Süt',
                'raw_line': 'YRM YAG SUT 1L',
                'unit_label': '1 Lt',
                'storage_zone': 'FRIDGE',
              },
              {
                'name': 'Sızma Zeytinyağı',
                'raw_line': 'SZM ZEYTINYAGI 1L',
                'unit_label': '1 Lt',
                'storage_zone': 'PANTRY',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final service = CloudVisionOcrService.forTesting(client: client);
      final items = await service.analyzeReceiptImageBytes(
        Uint8List.fromList([1, 2, 3, 4]),
      );

      expect(captured.method, 'POST');
      expect(captured.url.path, '/api/ocr/receipt');
      expect(captured.headers['X-Kilerce-User-Id'], 'test_ocr_user');
      expect(captured.headers['X-OrganicScore-Signature'], isNotEmpty);
      expect(captured.headers['X-OrganicScore-Timestamp'], isNotEmpty);

      expect(items, isNotNull);
      expect(items!.length, 2);

      final mapped = ReceiptOcrService.mapCloudItems(items);
      expect(mapped.length, 2);
      expect(mapped.first.template.name, 'Yarım Yağlı Süt');
      expect(mapped.first.template.defaultZone, StorageZone.fridge);
      expect(mapped.first.template.defaultUnit, '1 Lt');
      expect(mapped.last.template.defaultZone, StorageZone.pantry);
    });

    test('analyzeProductLabelBytes parses Turkish product label JSON', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/ocr/product-label');
        final reqJson = jsonDecode(request.body) as Map<String, dynamic>;
        expect(reqJson['mode'], 'INGREDIENTS');

        return http.Response(
          jsonEncode({
            'brand': 'Ülker',
            'product_name': 'Sütlü Çikolata',
            'net_quantity': '60 g',
            'ingredients_text': 'Şeker, kakao yağı, tam yağlı süt tozu',
            'allergens': ['Süt', 'Soya'],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final service = CloudVisionOcrService.forTesting(client: client);
      final result = await service.analyzeProductLabelBytes(
        Uint8List.fromList([9, 8, 7]),
        mode: 'INGREDIENTS',
      );

      expect(result, isNotNull);
      expect(result!.brand, 'Ülker');
      expect(result.productName, 'Sütlü Çikolata');
      expect(result.netQuantity, '60 g');
      expect(result.ingredientsText, contains('tam yağlı süt tozu'));
      expect(result.allergens, ['Süt', 'Soya']);
    });

    test('returns null cleanly on 429, 503, or empty HMAC secret for ML Kit fallback', () async {
      final rateLimitService = CloudVisionOcrService.forTesting(
        client: MockClient((_) async => http.Response('{"error":"limit"}', 429)),
      );
      expect(
        await rateLimitService.analyzeReceiptImageBytes(Uint8List.fromList([1, 2])),
        isNull,
      );

      final unconfiguredService = CloudVisionOcrService.forTesting(
        client: MockClient((_) async => http.Response('{"error":"no_key"}', 503)),
      );
      expect(
        await unconfiguredService.analyzeProductLabelBytes(Uint8List.fromList([1, 2])),
        isNull,
      );

      final noSecretService = CloudVisionOcrService.forTesting(
        hmacSecret: '',
        client: MockClient((_) async {
          fail('HTTP should not be called when hmacSecret is empty');
        }),
      );
      expect(
        await noSecretService.analyzeReceiptImageBytes(Uint8List.fromList([1, 2])),
        isNull,
      );
    });
  });
}
