import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_helper.dart';
import 'open_food_facts_service.dart';

enum ScanDataSource {
  onlineCloudWorker,
  onlineTurkishMarketApi,
  offlineAiSnapshot,
  offlineOnDeviceCalculation,
}

class ProductAnalysisResponse {
  final String barcode;
  final String productName;
  final String brand;
  final int organicScore;
  final String scoreCategory;
  final int novaGroup;
  final String novaVerdict;
  final String boycottStatus; // CLEAR, CAUTION, FLAGGED
  final String boycottReason;
  final String aiSummary;
  final List<String> warnings;
  final List<Map<String, String>> alternatives;
  final ScanDataSource source;
  final String statusBadgeText;
  final bool isDataIncomplete;
  final String ingredientsText;
  final Map<String, double> nutriments;
  final List<String> allergens;
  final List<String> marketChains;
  final String? netQuantity;
  final String? legalProducer;
  final double? referencePriceTry;

  ProductAnalysisResponse({
    required this.barcode,
    required this.productName,
    required this.brand,
    required this.organicScore,
    required this.scoreCategory,
    required this.novaGroup,
    required this.novaVerdict,
    required this.boycottStatus,
    required this.boycottReason,
    required this.aiSummary,
    required this.warnings,
    required this.alternatives,
    required this.source,
    required this.statusBadgeText,
    this.isDataIncomplete = false,
    this.ingredientsText = '',
    this.nutriments = const <String, double>{},
    this.allergens = const <String>[],
    this.marketChains = const <String>[],
    this.netQuantity,
    this.legalProducer,
    this.referencePriceTry,
  });
}

class OfflineFallbackManager {
  static final RegExp _ingredientsFallbackRegex = RegExp(
    r'[İiIı]çindekiler\s*:\s*(.+)$',
    dotAll: true,
  );

  /// Checks whether internet connectivity is active by testing an HTTP endpoint.
  static Future<bool> isOnline() async {
    try {
      final res = await http
          .get(Uri.parse('https://clients3.google.com/generate_204'))
          .timeout(const Duration(milliseconds: 1800));
      if (res.statusCode == 204 || res.statusCode == 200) {
        return true;
      }
    } catch (e) {
      debugPrint('Online connectivity probe note: $e');
    }

    try {
      final List<ConnectivityResult> results = await Connectivity().checkConnectivity();
      return !results.contains(ConnectivityResult.none);
    } catch (e) {
      debugPrint('Connectivity plugin check note: $e');
      return true;
    }
  }

  /// Looks up local SQLite offline AI snapshots for basement resilience.
  static Future<ProductAnalysisResponse?> getLocalSnapshot(String barcode, {bool isOnlineMode = false}) async {
    final Database db = await DatabaseHelper().database;
    final String cleanBarcode = barcode.trim();

    List<Map<String, dynamic>> boycottRows = const <Map<String, dynamic>>[];
    try {
      boycottRows = await db.query('boycott_brands');
    } catch (e) {
      debugPrint('Boycott table lookup note: $e');
    }

    final List<Map<String, dynamic>> results = await db.query(
      'offline_ai_snapshots',
      where: 'barcode = ?',
      whereArgs: [cleanBarcode],
    );

    if (results.isNotEmpty) {
      final row = results.first;
      Map<String, dynamic> summaryJson = const <String, dynamic>{};
      try {
        final dynamic decoded = jsonDecode(row['ai_summary_json'] as String? ?? '{}');
        if (decoded is Map<String, dynamic>) {
          summaryJson = decoded;
        } else if (decoded is Map) {
          summaryJson = Map<String, dynamic>.from(decoded);
        }
      } catch (e) {
        debugPrint('Snapshot JSON decode note ($cleanBarcode): $e');
      }

      final String productName = (row['product_name'] as String?)?.trim().isNotEmpty == true
          ? (row['product_name'] as String).trim()
          : 'Bilinmeyen Ürün';
      final String brandName = (row['brand'] as String?)?.trim() ?? 'Yerli Marka';
      final String resolvedBrand = brandName.isNotEmpty ? brandName : 'Doğrulanmış Üretici';
      final String summaryText = (summaryJson['summary'] as String?)?.trim() ?? 'Yerel AI snapshot özeti.';

      final List<dynamic>? altList = summaryJson['alternatives'] as List<dynamic>?;
      final List<Map<String, String>> parsedAlternatives = altList != null
          ? altList
              .whereType<Map>()
              .map((item) => {
                    'name': (item['name']?.toString() ?? 'Yerel Alternatif').trim(),
                    'brand': (item['brand']?.toString() ?? 'Yerli Marka').trim(),
                    'reason': (item['reason']?.toString() ?? 'Sağlıklı & Etik Seçenek').trim(),
                  })
              .toList()
          : <Map<String, String>>[];

      final String ingredientsText = _extractIngredientsText(summaryJson, summaryText);
      final Map<String, double> nutriments = _extractNutriments(summaryJson);
      final List<String> allergens = _extractStringList(
        summaryJson['allergens'] ?? summaryJson['allergen_warnings'],
      );
      final List<String> marketChains = _extractStringList(
        summaryJson['market_chains'] ?? summaryJson['marketChains'] ?? summaryJson['markets'],
      );
      final String? netQuantity = _extractNullableString(
        summaryJson['net_quantity'] ?? summaryJson['netQuantity'] ?? summaryJson['quantity'],
      );
      final String? legalProducer = _extractNullableString(
        summaryJson['producer_legal_name'] ??
            summaryJson['legal_producer'] ??
            summaryJson['legalProducer'] ??
            summaryJson['producer'],
      );
      final double? referencePriceTry = _extractPositiveDouble(
        summaryJson['reference_price_try'] ??
            summaryJson['referencePriceTry'] ??
            summaryJson['price_try'] ??
            summaryJson['price'],
      );

      final Map<String, String> boycottEval = evaluateBoycottStatus(
        productName: productName,
        brandName: resolvedBrand,
        boycottBrands: boycottRows,
      );
      final String storedBoycott = (summaryJson['boycott_status']?.toString() ?? '').toUpperCase();
      final String boycottStatus = (boycottEval['status_flag'] != null && boycottEval['status_flag'] != 'CLEAR')
          ? boycottEval['status_flag']!
          : ((storedBoycott == 'FLAGGED' || storedBoycott == 'CAUTION') ? storedBoycott : 'CLEAR');
      final String boycottReason = boycottStatus != 'CLEAR'
          ? (boycottEval['status_flag'] != 'CLEAR'
              ? (boycottEval['reason'] ?? 'Boykot veritabanı kaydı bulundu.')
              : (summaryJson['boycott_reason']?.toString() ?? 'Boykot veritabanı kaydı bulundu.'))
          : (boycottEval['reason'] ?? 'Etik kaynak veritabanı kontrollü');

      final String chainsLabel = marketChains.take(4).join(' / ');
      final String statusBadgeText = marketChains.isNotEmpty
          ? (isOnlineMode
              ? '🌐 Doğrulanmış Market Veritabanı ($chainsLabel)'
              : '⚡ Doğrulanmış Yerel Veritabanı ($chainsLabel)')
          : (isOnlineMode
              ? '🌐 Doğrulanmış Market Veritabanı (Canlı)'
              : '⚡ Doğrulanmış Yerel Veritabanı (BİM / A101 / ŞOK & Ulusal)');

      final List<String> warnings = (summaryJson['warnings'] as List<dynamic>?)
              ?.map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList() ??
          <String>[];

      return ProductAnalysisResponse(
        barcode: cleanBarcode,
        productName: productName,
        brand: resolvedBrand,
        organicScore: (summaryJson['organic_score'] as num?)?.toInt() ?? 50,
        scoreCategory: isOnlineMode ? 'Canlı Doğrulamalı Derecelendirme' : 'Çevrimdışı Doğrulanmış Derecelendirme',
        novaGroup: (summaryJson['nova_group'] as num?)?.toInt() ?? 3,
        novaVerdict: summaryJson['verdict']?.toString() ?? 'İşlenmiş Ürün',
        boycottStatus: boycottStatus,
        boycottReason: boycottReason,
        aiSummary: summaryText,
        warnings: warnings,
        alternatives: parsedAlternatives,
        source: isOnlineMode ? ScanDataSource.onlineCloudWorker : ScanDataSource.offlineAiSnapshot,
        statusBadgeText: statusBadgeText,
        ingredientsText: ingredientsText,
        nutriments: nutriments,
        allergens: allergens,
        marketChains: marketChains,
        netQuantity: netQuantity,
        legalProducer: legalProducer,
        referencePriceTry: referencePriceTry,
      );
    }

    // 2. Check crowdsourced_queue for user submitted products
    try {
      final List<Map<String, dynamic>> crowdResults = await db.query(
        'crowdsourced_queue',
        where: 'barcode = ?',
        whereArgs: [cleanBarcode],
      );

      if (crowdResults.isNotEmpty) {
        final row = crowdResults.last;
        final Map<String, dynamic> payload = jsonDecode(row['payload_json'] as String) as Map<String, dynamic>;
        final String name = payload['product_name'] as String? ?? 'Topluluk Ürünü';
        final String brand = payload['brand'] as String? ?? 'Katkı Markası';
        final String resolvedBrand = brand.isNotEmpty ? brand : 'Topluluk Katkısı';
        final String ingText = (payload['ingredients_text'] as String? ?? '').trim();
        final String lowerIng = ingText.toLowerCase();

        final bool hasRisks = lowerIng.contains('glikoz') ||
            lowerIng.contains('fruktoz') ||
            lowerIng.contains('palm') ||
            lowerIng.contains('margarin') ||
            lowerIng.contains('tatlandırıcı') ||
            lowerIng.contains('çin tuzu') ||
            lowerIng.contains('msg') ||
            lowerIng.contains('nitrit') ||
            lowerIng.contains('aspartam') ||
            lowerIng.contains('benzoat') ||
            RegExp(r'\b[Ee][\s\-\.]?\d{3,4}\b').hasMatch(ingText);

        final bool isPureNatural = !hasRisks &&
            OpenFoodFactsService.isPureNaturalFoodName(
              name,
              ingredientsText: ingText,
            );

        final int score = hasRisks ? 45 : (isPureNatural ? 95 : 85);
        final int nova = hasRisks ? 4 : (isPureNatural ? 1 : 2);
        final String novaText = nova == 4
            ? 'Ultra İşlenmiş Gıda (NOVA 4)'
            : (nova == 1 ? 'İşlenmemiş / Organik (NOVA 1)' : 'İşlenmiş Mutfak Malzemesi (NOVA 2)');

        final Map<String, String> boycottEval = evaluateBoycottStatus(
          productName: name,
          brandName: resolvedBrand,
          boycottBrands: boycottRows,
        );

        return ProductAnalysisResponse(
          barcode: cleanBarcode,
          productName: name,
          brand: resolvedBrand,
          organicScore: score,
          scoreCategory: 'Topluluk Doğrulamalı Derecelendirme',
          novaGroup: nova,
          novaVerdict: novaText,
          boycottStatus: boycottEval['status_flag'] ?? 'CLEAR',
          boycottReason: boycottEval['reason'] ?? 'Topluluk katkısı ile eklendi.',
          aiSummary:
              '$resolvedBrand markasına ait $name. Katkıda bulun bölümü ile yerel veritabanına kaydedildi.${ingText.isNotEmpty ? " İçindekiler: $ingText" : ""}',
          warnings: hasRisks ? ['İşlenmiş İçerik / Katkı Maddesi'] : [],
          alternatives: [],
          source: ScanDataSource.offlineAiSnapshot,
          statusBadgeText: '🤝 Topluluk Katkısı: Yerel Veritabanına Eklenen Ürün',
          ingredientsText: ingText,
        );
      }
    } catch (e) {
      debugPrint('Crowdsourced queue lookup note: $e');
    }

    return null;
  }

  static String _extractIngredientsText(Map<String, dynamic> summaryJson, String summaryFallback) {
    final dynamic direct = summaryJson['ingredients_text'] ??
        summaryJson['ingredientsText'] ??
        summaryJson['ingredients'];
    if (direct != null) {
      final String text = direct.toString().trim();
      if (text.isNotEmpty) {
        return text;
      }
    }
    final RegExpMatch? match = _ingredientsFallbackRegex.firstMatch(summaryFallback);
    if (match != null) {
      final String extracted = (match.group(1) ?? '').trim();
      if (extracted.isNotEmpty) {
        return extracted;
      }
    }
    return '';
  }

  static Map<String, double> _extractNutriments(Map<String, dynamic> summaryJson) {
    final dynamic rawMap = summaryJson['nutriments'] ??
        summaryJson['nutritional_values'] ??
        summaryJson['nutrition'];
    if (rawMap is! Map) {
      return const <String, double>{};
    }
    final Map<String, double> parsed = <String, double>{};
    rawMap.forEach((dynamic key, dynamic value) {
      if (key == null || value == null) return;
      final String k = key.toString().trim();
      if (k.isEmpty) return;
      double? numVal;
      if (value is num) {
        numVal = value.toDouble();
      } else {
        numVal = double.tryParse(value.toString().replaceAll(',', '.').trim());
      }
      if (numVal != null && numVal.isFinite) {
        parsed[k] = numVal;
      }
    });
    return parsed;
  }

  static List<String> _extractStringList(dynamic raw) {
    if (raw == null) return const <String>[];
    if (raw is List) {
      final Set<String> unique = <String>{};
      for (final dynamic item in raw) {
        if (item == null) continue;
        final String val = item.toString().trim();
        if (val.isNotEmpty) {
          unique.add(val);
        }
      }
      return unique.toList();
    }
    if (raw is String) {
      final String trimmed = raw.trim();
      if (trimmed.isEmpty) return const <String>[];
      return trimmed
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList();
    }
    return const <String>[];
  }

  static String? _extractNullableString(dynamic raw) {
    if (raw == null) return null;
    final String text = raw.toString().trim();
    return text.isEmpty ? null : text;
  }

  static double? _extractPositiveDouble(dynamic raw) {
    if (raw == null) return null;
    double? value;
    if (raw is num) {
      value = raw.toDouble();
    } else {
      final String cleaned = raw
          .toString()
          .replaceAll('₺', '')
          .replaceAll('TL', '')
          .replaceAll(',', '.')
          .trim();
      value = double.tryParse(cleaned);
    }
    if (value == null || !value.isFinite || value <= 0) {
      return null;
    }
    return value;
  }

  /// Normalizes Turkish characters and punctuation for strict matching.
  static String normalizeForMatching(String input) {
    if (input.trim().isEmpty) return '';
    var text = input.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();
    const map = {
      'ı': 'i',
      'ş': 's',
      'ğ': 'g',
      'ü': 'u',
      'ö': 'o',
      'ç': 'c',
    };
    map.forEach((k, v) => text = text.replaceAll(k, v));
    text = text.replaceAll(RegExp(r'[^a-z0-9]'), ' ');
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Queries SQLite boycott brands table by product title and brand.
  static Future<Map<String, String>> getBoycottStatus({
    required String productName,
    String? brandName,
  }) async {
    final Database db = await DatabaseHelper().database;
    final List<Map<String, dynamic>> allBoycottBrands = await db.query('boycott_brands');
    return evaluateBoycottStatus(
      productName: productName,
      brandName: brandName,
      boycottBrands: allBoycottBrands,
    );
  }

  /// Pure, zero-false-positive 3-tier hierarchical matching engine:
  /// Tier 1: Exact / Normalized Official Brand Match (prevents false positives on known brands like Eti)
  /// Tier 2: Word-Boundary Regex Match (\b...\b) on product name
  /// Tier 3: Length <= 3 protection (avoids short tokens like 'fa' in 'lifalif' or 'erikli' in 'içerikli')
  static Map<String, String> evaluateBoycottStatus({
    required String productName,
    String? brandName,
    required List<Map<String, dynamic>> boycottBrands,
  }) {
    final String normBrand = normalizeForMatching(brandName ?? '');
    final String normProduct = normalizeForMatching(productName);

    const genericBrands = {
      'yerli uretici',
      'bilinmeyen marka',
      'bilinmeyen',
      'genel urun',
      'diger',
      'markasiz',
      '',
    };

    final bool hasSpecificBrand = normBrand.isNotEmpty &&
        !genericBrands.contains(normBrand) &&
        normBrand.length >= 2;

    // --- TIER 1: Official Brand Field Match ---
    if (hasSpecificBrand) {
      for (final row in boycottBrands) {
        final String rawBrand = (row['brand_name'] as String? ?? '').trim();
        final String rawParent = (row['parent_company'] as String? ?? '').trim();
        final String normRowBrand = normalizeForMatching(rawBrand);
        final String normRowParent = normalizeForMatching(rawParent);

        if ((normRowBrand.isNotEmpty && normBrand == normRowBrand) ||
            (normRowParent.isNotEmpty && normBrand == normRowParent)) {
          return {
            'brand_name': rawBrand,
            'parent_company': rawParent.isNotEmpty ? rawParent : rawBrand,
            'status_flag': row['status_flag'] as String? ?? 'FLAGGED',
            'reason': row['reason'] as String? ?? 'Gazze işgali ve İsrail bağlantısı / desteği nedeniyle boykot listesinde.',
            'evidence_url': row['evidence_url'] as String? ?? '',
            'category': row['category'] as String? ?? 'Genel',
          };
        }
      }

      // If official brand is explicitly specified and confirmed NOT in the boycott database:
      // (e.g. Eti, Torku, Pınar, Sütaş, Ülker yerli serileri)
      // We do not allow noisy substrings in the product name (e.g. "Lifalif" -> "Fa") to flag it.
      const verifiedSafeBrands = {
        'eti',
        'eti gida',
        'eti lifalif',
        'eti karam',
        'eti crax',
        'torku',
        'pinar',
        'sutas',
        'dogus',
        'dimes',
        'tat',
        'balka',
        'aroma',
      };

      if (verifiedSafeBrands.contains(normBrand)) {
        return {
          'brand_name': brandName ?? 'Doğrulanmış Üretici',
          'parent_company': brandName ?? 'Doğrulanmış Üretici',
          'status_flag': 'CLEAR',
          'reason': 'Doğrulanmış yerli / etik üretici. Gazze hassasiyetine aykırı boykot kaydı bulunmamaktadır (Yeşil Listede).',
          'evidence_url': '',
          'category': 'Temiz',
        };
      }
    }

    // --- TIER 2 & 3: Word-Boundary Regex Match on Product Name ---
    final Set<String> productTokens = normProduct.split(' ').where((t) => t.isNotEmpty).toSet();

    for (final row in boycottBrands) {
      final String rawBrand = (row['brand_name'] as String? ?? '').trim();
      final String normRowBrand = normalizeForMatching(rawBrand);

      if (normRowBrand.isEmpty || normRowBrand.length < 2) continue;

      // Tier 3: Very short brand names (<= 3 characters, e.g. "Fa", "Off", "Lg", "Ta")
      // MUST match as an exact whole token and require specific brand context
      if (normRowBrand.length <= 3) {
        if (productTokens.contains(normRowBrand) &&
            hasSpecificBrand &&
            normBrand == normRowBrand) {
          return {
            'brand_name': rawBrand,
            'parent_company': (row['parent_company'] as String?) ?? rawBrand,
            'status_flag': row['status_flag'] as String? ?? 'FLAGGED',
            'reason': row['reason'] as String? ?? 'Gazze işgali ve İsrail bağlantısı / desteği nedeniyle boykot listesinde.',
            'evidence_url': row['evidence_url'] as String? ?? '',
            'category': row['category'] as String? ?? 'Genel',
          };
        }
        continue;
      }

      // Word boundary matching: ensures "lifalif" doesn't match "fa" and "içerikli" doesn't match "erikli"
      final pattern = RegExp(r'(^|\s)' + RegExp.escape(normRowBrand) + r'(\s|$)');
      if (pattern.hasMatch(normProduct)) {
        return {
          'brand_name': rawBrand,
          'parent_company': (row['parent_company'] as String?) ?? rawBrand,
          'status_flag': row['status_flag'] as String? ?? 'FLAGGED',
          'reason': row['reason'] as String? ?? 'Gazze işgali ve İsrail bağlantısı / desteği nedeniyle boykot listesinde.',
          'evidence_url': row['evidence_url'] as String? ?? '',
          'category': row['category'] as String? ?? 'Genel',
        };
      }
    }

    return {
      'brand_name': brandName ?? 'Genel Ürün',
      'parent_company': brandName ?? 'Genel Ürün',
      'status_flag': 'CLEAR',
      'reason': 'Gazze hassasiyetine aykırı boykot veya etik ihlal kaydı bulunamadı (Yeşil Listede).',
      'evidence_url': '',
      'category': 'Temiz',
    };
  }
}
