import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../recipes/data/kilerce_cloud_recipe_client.dart';
import '../../recipes/data/kilerce_edge_config.dart';

/// Structured food line item extracted by Gemini 2.5 Flash-Lite from a grocery receipt.
class CloudReceiptItem {
  final String name;
  final String rawLine;
  final String unitLabel;
  final String storageZoneCode;

  const CloudReceiptItem({
    required this.name,
    required this.rawLine,
    required this.unitLabel,
    required this.storageZoneCode,
  });

  factory CloudReceiptItem.fromJson(Map<String, dynamic> json) {
    return CloudReceiptItem(
      name: (json['name'] as String? ?? '').trim(),
      rawLine: (json['raw_line'] as String? ?? '').trim(),
      unitLabel: (json['unit_label'] as String? ?? '1 Paket').trim(),
      storageZoneCode:
          (json['storage_zone'] as String? ?? 'PANTRY').trim().toUpperCase(),
    );
  }
}

/// Structured product metadata extracted from front packaging or rear ingredient labels.
class CloudProductLabelResult {
  final String brand;
  final String productName;
  final String netQuantity;
  final String ingredientsText;
  final List<String> allergens;

  const CloudProductLabelResult({
    required this.brand,
    required this.productName,
    required this.netQuantity,
    required this.ingredientsText,
    required this.allergens,
  });

  bool get hasPackagingData => brand.isNotEmpty || productName.isNotEmpty;

  factory CloudProductLabelResult.fromJson(Map<String, dynamic> json) {
    final rawAllergens = json['allergens'];
    final allergens = rawAllergens is List
        ? rawAllergens
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList()
        : const <String>[];

    return CloudProductLabelResult(
      brand: (json['brand'] as String? ?? '').trim(),
      productName: (json['product_name'] as String? ?? '').trim(),
      netQuantity: (json['net_quantity'] as String? ?? '').trim(),
      ingredientsText: (json['ingredients_text'] as String? ?? '').trim(),
      allergens: allergens,
    );
  }
}

/// DIP interface for cloud-assisted receipt & product label vision OCR.
abstract interface class CloudVisionOcrGateway {
  Future<List<CloudReceiptItem>?> analyzeReceiptImageBytes(
    Uint8List bytes, {
    String mimeType = 'image/jpeg',
  });

  Future<CloudProductLabelResult?> analyzeProductLabelBytes(
    Uint8List bytes, {
    String mode = 'AUTO',
    String mimeType = 'image/jpeg',
  });
}

/// HMAC-signed HTTP client invoking Cloudflare Worker `/api/ocr/*` (Gemini 2.5 Flash-Lite).
/// Returns `null` on missing config, network failure, or quota limits so callers fall back
/// cleanly to on-device ML Kit OCR.
class CloudVisionOcrService implements CloudVisionOcrGateway {
  static final CloudVisionOcrService instance =
      CloudVisionOcrService._internal();

  static const Duration _timeout = Duration(seconds: 18);
  static const int _maxRawImageBytes = 1500000;

  final http.Client _client;
  final String _baseUrl;
  final String _hmacSecret;
  final Future<String> Function() _userIdProvider;

  CloudVisionOcrService._internal({
    http.Client? client,
    String? baseUrl,
    String? hmacSecret,
    Future<String> Function()? userIdProvider,
  })  : _client = client ?? http.Client(),
        _baseUrl = (baseUrl ?? KilerceEdgeConfig.apiBaseUrl).trim(),
        _hmacSecret = (hmacSecret ?? KilerceEdgeConfig.hmacSecret).trim(),
        _userIdProvider =
            userIdProvider ?? KilerceCloudRecipeClient.instance.getOrCreateAppUserId;

  @visibleForTesting
  factory CloudVisionOcrService.forTesting({
    required http.Client client,
    String baseUrl = 'https://kilerce.example.workers.dev',
    String hmacSecret = 'test-hmac-secret',
    Future<String> Function()? userIdProvider,
  }) {
    return CloudVisionOcrService._internal(
      client: client,
      baseUrl: baseUrl,
      hmacSecret: hmacSecret,
      userIdProvider: userIdProvider ?? () async => 'test_ocr_user',
    );
  }

  Future<Map<String, dynamic>?> _postSignedOcr(
    String path,
    Map<String, dynamic> payload,
  ) async {
    if (_hmacSecret.isEmpty || _baseUrl.isEmpty) return null;

    try {
      final base = Uri.parse(_baseUrl);
      final uri = base.replace(path: path);
      final body = jsonEncode(payload);
      final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final sig = KilerceCloudRecipeClient.signCanonicalRequest(
        secret: _hmacSecret,
        timestampSec: ts,
        method: 'POST',
        wirePathAndQuery: uri.path,
        body: body,
      );
      final userId = await _userIdProvider();

      final resp = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'X-Kilerce-User-Id': userId,
              'X-OrganicScore-Timestamp': '$ts',
              'X-OrganicScore-Signature': sig,
            },
            body: body,
          )
          .timeout(_timeout);

      if (resp.statusCode != 200) {
        debugPrint('CloudVisionOcrService($path) status ${resp.statusCode}');
        return null;
      }

      final decoded = jsonDecode(utf8.decode(resp.bodyBytes));
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (e) {
      debugPrint('CloudVisionOcrService($path) fallback error: $e');
      return null;
    }
  }

  @override
  Future<List<CloudReceiptItem>?> analyzeReceiptImageBytes(
    Uint8List bytes, {
    String mimeType = 'image/jpeg',
  }) async {
    if (bytes.isEmpty || bytes.length > _maxRawImageBytes) return null;

    final map = await _postSignedOcr('/api/ocr/receipt', {
      'image_base64': base64Encode(bytes),
      'mime_type': mimeType,
    });
    if (map == null) return null;

    final rawItems = map['items'];
    if (rawItems is! List) return null;

    return rawItems
        .whereType<Map>()
        .map((e) => CloudReceiptItem.fromJson(Map<String, dynamic>.from(e)))
        .where((item) => item.name.length >= 2)
        .toList();
  }

  @override
  Future<CloudProductLabelResult?> analyzeProductLabelBytes(
    Uint8List bytes, {
    String mode = 'AUTO',
    String mimeType = 'image/jpeg',
  }) async {
    if (bytes.isEmpty || bytes.length > _maxRawImageBytes) return null;

    final map = await _postSignedOcr('/api/ocr/product-label', {
      'image_base64': base64Encode(bytes),
      'mime_type': mimeType,
      'mode': mode,
    });
    if (map == null) return null;

    return CloudProductLabelResult.fromJson(map);
  }
}
