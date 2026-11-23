import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../core/database/database_helper.dart';
import '../../ocr/domain/ingredient_parser.dart';
import '../../product/domain/alternative_recommendation_engine.dart';
import '../../scoring/domain/organic_score_calculator.dart';
import 'offline_fallback_manager.dart';
import 'open_food_facts_service.dart';

/// Immutable HTTP response wrapper for [MarketHttpGateway].
class MarketHttpResponse {
  final int statusCode;
  final String body;

  const MarketHttpResponse({
    required this.statusCode,
    required this.body,
  });

  bool get isOk => statusCode >= 200 && statusCode < 300;
}

/// Protocol abstraction for network I/O (DIP).
abstract interface class MarketHttpGateway {
  Future<MarketHttpResponse?> getText(
    Uri uri, {
    Map<String, String>? headers,
    Duration timeout,
  });

  Future<MarketHttpResponse?> postJson(
    Uri uri, {
    required Map<String, dynamic> payload,
    Map<String, String>? headers,
    Duration timeout,
  });

  void close();
}

/// Concrete HTTP client gateway with strict timeouts, UTF-8 decoding, and deterministic close.
class HttpMarketGateway implements MarketHttpGateway {
  final http.Client _client;
  bool _isClosed = false;

  HttpMarketGateway({http.Client? client}) : _client = client ?? http.Client();

  @override
  Future<MarketHttpResponse?> getText(
    Uri uri, {
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 6),
  }) async {
    if (_isClosed) return null;
    try {
      final http.Response response = await _client.get(uri, headers: headers).timeout(timeout);
      final String decoded = utf8.decode(response.bodyBytes, allowMalformed: true);
      return MarketHttpResponse(statusCode: response.statusCode, body: decoded);
    } on TimeoutException catch (e) {
      debugPrint('MarketHttpGateway GET timeout ($uri): $e');
      return null;
    } catch (e) {
      debugPrint('MarketHttpGateway GET error ($uri): $e');
      return null;
    }
  }

  @override
  Future<MarketHttpResponse?> postJson(
    Uri uri, {
    required Map<String, dynamic> payload,
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 6),
  }) async {
    if (_isClosed) return null;
    try {
      final Map<String, String> mergedHeaders = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        ...?headers,
      };
      final http.Response response = await _client
          .post(uri, headers: mergedHeaders, body: jsonEncode(payload))
          .timeout(timeout);
      final String decoded = utf8.decode(response.bodyBytes, allowMalformed: true);
      return MarketHttpResponse(statusCode: response.statusCode, body: decoded);
    } on TimeoutException catch (e) {
      debugPrint('MarketHttpGateway POST timeout ($uri): $e');
      return null;
    } catch (e) {
      debugPrint('MarketHttpGateway POST error ($uri): $e');
      return null;
    }
  }

  @override
  void close() {
    if (_isClosed) return;
    _isClosed = true;
    try {
      _client.close();
    } catch (e) {
      debugPrint('MarketHttpGateway close note: $e');
    }
  }
}

/// Accumulated Turkish market & TGK product draft across resolver strategies.
class MarketProductDraft {
  final String barcode;
  final String? productName;
  final String? brand;
  final String ingredientsText;
  final Map<String, double> nutriments;
  final List<String> allergens;
  final List<String> marketChains;
  final String? netQuantity;
  final String? legalProducer;
  final double? referencePriceTry;
  final List<String> resolverOrigins;
  final bool resolvedFromTurkishMarket;

  const MarketProductDraft({
    required this.barcode,
    this.productName,
    this.brand,
    this.ingredientsText = '',
    this.nutriments = const <String, double>{},
    this.allergens = const <String>[],
    this.marketChains = const <String>[],
    this.netQuantity,
    this.legalProducer,
    this.referencePriceTry,
    this.resolverOrigins = const <String>[],
    this.resolvedFromTurkishMarket = false,
  });

  bool get hasIdentity => productName != null && productName!.trim().isNotEmpty;

  bool get hasIngredients => ingredientsText.trim().length > 4;

  bool get hasNutriments => nutriments.isNotEmpty;

  bool get isFullyEnriched => hasIdentity && hasIngredients && hasNutriments;

  MarketProductDraft mergeWith(MarketProductDraft incoming) {
    final Set<String> mergedChains = <String>{
      ...marketChains,
      ...incoming.marketChains,
    };
    final Set<String> mergedAllergens = <String>{
      ...allergens,
      ...incoming.allergens,
    };
    final Set<String> mergedOrigins = <String>{
      ...resolverOrigins,
      ...incoming.resolverOrigins,
    };
    final Map<String, double> mergedNutriments = <String, double>{
      ...incoming.nutriments,
      ...nutriments,
    };

    final String chosenIngredients =
        hasIngredients ? ingredientsText : incoming.ingredientsText;

    return MarketProductDraft(
      barcode: barcode,
      productName: hasIdentity ? productName : incoming.productName,
      brand: (brand != null && brand!.trim().isNotEmpty) ? brand : incoming.brand,
      ingredientsText: chosenIngredients,
      nutriments: mergedNutriments,
      allergens: mergedAllergens.toList(),
      marketChains: mergedChains.toList(),
      netQuantity: (netQuantity != null && netQuantity!.trim().isNotEmpty)
          ? netQuantity
          : incoming.netQuantity,
      legalProducer: (legalProducer != null && legalProducer!.trim().isNotEmpty)
          ? legalProducer
          : incoming.legalProducer,
      referencePriceTry: referencePriceTry ?? incoming.referencePriceTry,
      resolverOrigins: mergedOrigins.toList(),
      resolvedFromTurkishMarket:
          resolvedFromTurkishMarket || incoming.resolvedFromTurkishMarket,
    );
  }
}

/// Strategy contract for Turkish & global barcode resolution / TGK enrichment (OCP & DIP).
abstract interface class MarketResolverStrategy {
  String get strategyId;

  Future<MarketProductDraft?> resolve({
    required String barcode,
    MarketProductDraft? currentDraft,
    required MarketHttpGateway httpGateway,
  });
}

/// Strategy 1: TÜBİTAK MarketFiyatı (`api.marketfiyati.org.tr/api/v2/{nearest,searchByIdentity}`).
class TubitakMarketFiyatiStrategy implements MarketResolverStrategy {
  static final Uri _nearestUri =
      Uri.parse('https://api.marketfiyati.org.tr/api/v2/nearest');
  static final Uri _searchByIdentityUri =
      Uri.parse('https://api.marketfiyati.org.tr/api/v2/searchByIdentity');

  static const List<Map<String, double>> _hubCoordinates = <Map<String, double>>[
    {'latitude': 41.0082, 'longitude': 28.9784}, // İstanbul
    {'latitude': 39.9208, 'longitude': 32.8541}, // Ankara
  ];

  static List<String> _cachedDepots = const <String>[];
  static DateTime? _depotsCachedAt;
  static const Duration _depotCacheTtl = Duration(minutes: 30);
  static const int _maxDepotIds = 60;

  static const Map<String, String> _headers = <String, String>{
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/124.0.0.0 Mobile Safari/537.36',
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  @override
  String get strategyId => 'tubitak_market_fiyati';

  @override
  Future<MarketProductDraft?> resolve({
    required String barcode,
    MarketProductDraft? currentDraft,
    required MarketHttpGateway httpGateway,
  }) async {
    try {
      final List<String> depots = await _resolveNearestDepots(httpGateway);
      final Map<String, dynamic> payload = <String, dynamic>{
        'identity': barcode,
        'identityType': 'barcode',
        if (depots.isNotEmpty) 'depots': depots,
      };

      final MarketHttpResponse? response = await httpGateway.postJson(
        _searchByIdentityUri,
        payload: payload,
        headers: _headers,
        timeout: const Duration(seconds: 5),
      );
      if (response == null || !response.isOk) {
        return null;
      }

      return MarketPayloadParser.parseTubitakSearchByIdentity(
        barcode: barcode,
        rawJson: response.body,
      );
    } catch (e) {
      debugPrint('TubitakMarketFiyatiStrategy error ($barcode): $e');
      return null;
    }
  }

  Future<List<String>> _resolveNearestDepots(MarketHttpGateway httpGateway) async {
    final DateTime now = DateTime.now();
    if (_cachedDepots.isNotEmpty &&
        _depotsCachedAt != null &&
        now.difference(_depotsCachedAt!) < _depotCacheTtl) {
      return _cachedDepots;
    }

    final Set<String> collectedDepots = <String>{};
    for (final Map<String, double> hub in _hubCoordinates) {
      final MarketHttpResponse? resp = await httpGateway.postJson(
        _nearestUri,
        payload: <String, dynamic>{
          'latitude': hub['latitude'],
          'longitude': hub['longitude'],
          'distance': 10,
        },
        headers: _headers,
        timeout: const Duration(milliseconds: 4200),
      );
      if (resp != null && resp.isOk) {
        final List<String> parsed = MarketPayloadParser.parseTubitakDepots(resp.body);
        for (final String id in parsed) {
          if (collectedDepots.length >= _maxDepotIds) break;
          collectedDepots.add(id);
        }
      }
      if (collectedDepots.length >= 24) {
        break;
      }
    }

    if (collectedDepots.isNotEmpty) {
      _cachedDepots = List<String>.unmodifiable(collectedDepots);
      _depotsCachedAt = now;
    }
    return collectedDepots.toList();
  }
}

/// Strategy 2: Migros REST (`/rest/search/screens/products` + `/rest/products/screens/{id}`, `X-PWA: true`)
/// for TGK Ingredients, Allergens, Legal Producer & 100g Nutritional Values enrichment.
class MigrosTgkStrategy implements MarketResolverStrategy {
  static const Map<String, String> _pwaHeaders = <String, String>{
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/124.0.0.0 Mobile Safari/537.36',
    'Accept': 'application/json',
    'Accept-Language': 'tr-TR,tr;q=0.9',
    'X-PWA': 'true',
    'X-FORWARDED-REST': 'true',
  };

  @override
  String get strategyId => 'migros_tgk_rest';

  @override
  Future<MarketProductDraft?> resolve({
    required String barcode,
    MarketProductDraft? currentDraft,
    required MarketHttpGateway httpGateway,
  }) async {
    if (currentDraft != null && currentDraft.isFullyEnriched) {
      return null;
    }

    try {
      final List<String> searchQueries = <String>[
        barcode,
        if (currentDraft != null && currentDraft.hasIdentity)
          MarketPayloadParser.buildCleanSearchQuery(
            productName: currentDraft.productName!,
            brand: currentDraft.brand,
          ),
      ];

      Map<String, dynamic>? matchedCandidate;
      for (final String query in searchQueries) {
        if (query.trim().isEmpty) continue;
        final Uri searchUri = Uri.https(
          'www.migros.com.tr',
          '/rest/search/screens/products',
          <String, String>{'q': query},
        );
        final MarketHttpResponse? searchResp = await httpGateway.getText(
          searchUri,
          headers: _pwaHeaders,
          timeout: const Duration(seconds: 5),
        );
        if (searchResp == null || !searchResp.isOk) continue;

        matchedCandidate = MarketPayloadParser.selectBestMigrosCandidate(
          rawSearchJson: searchResp.body,
          barcode: barcode,
          expectedName: currentDraft?.productName,
          expectedBrand: currentDraft?.brand,
          searchedByBarcode: query == barcode,
        );
        if (matchedCandidate != null) {
          break;
        }
      }

      if (matchedCandidate == null) {
        return null;
      }

      final String? productId = matchedCandidate['id']?.toString();
      if (productId == null || productId.isEmpty) {
        return null;
      }

      final Uri detailUri =
          Uri.parse('https://www.migros.com.tr/rest/products/screens/$productId');
      final MarketHttpResponse? detailResp = await httpGateway.getText(
        detailUri,
        headers: _pwaHeaders,
        timeout: const Duration(seconds: 5),
      );
      if (detailResp == null || !detailResp.isOk) {
        return null;
      }

      return MarketPayloadParser.parseMigrosScreenDetail(
        barcode: barcode,
        rawDetailJson: detailResp.body,
      );
    } catch (e) {
      debugPrint('MigrosTgkStrategy error ($barcode): $e');
      return null;
    }
  }
}

/// Strategy 3: Cepte ŞOK TGK (`www.sokmarket.com.tr`) for TGK Ingredients & Producer enrichment.
class CepteSokTgkStrategy implements MarketResolverStrategy {
  static const Map<String, String> _sokHeaders = <String, String>{
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/124.0.0.0 Mobile Safari/537.36',
    'Accept': 'text/html,application/json;q=0.9,*/*;q=0.8',
    'Accept-Language': 'tr-TR,tr;q=0.9',
  };

  @override
  String get strategyId => 'cepte_sok_tgk';

  @override
  Future<MarketProductDraft?> resolve({
    required String barcode,
    MarketProductDraft? currentDraft,
    required MarketHttpGateway httpGateway,
  }) async {
    if (currentDraft != null && currentDraft.isFullyEnriched) {
      return null;
    }

    try {
      final List<String> queries = <String>[
        if (currentDraft != null && currentDraft.hasIdentity)
          MarketPayloadParser.buildCleanSearchQuery(
            productName: currentDraft.productName!,
            brand: currentDraft.brand,
          )
        else
          barcode,
      ];

      for (final String query in queries) {
        if (query.trim().isEmpty) continue;
        final Uri searchUri = Uri.https(
          'www.sokmarket.com.tr',
          '/arama',
          <String, String>{'q': query},
        );
        final MarketHttpResponse? searchResp = await httpGateway.getText(
          searchUri,
          headers: _sokHeaders,
          timeout: const Duration(seconds: 5),
        );
        if (searchResp == null || !searchResp.isOk) continue;

        final String? bestPath = MarketPayloadParser.selectBestCepteSokPath(
          html: searchResp.body,
          expectedName: currentDraft?.productName,
          expectedBrand: currentDraft?.brand,
          searchedByBarcode: query == barcode,
        );
        if (bestPath == null) continue;

        final Uri detailUri = Uri.parse('https://www.sokmarket.com.tr$bestPath');
        final MarketHttpResponse? detailResp = await httpGateway.getText(
          detailUri,
          headers: _sokHeaders,
          timeout: const Duration(seconds: 5),
        );
        if (detailResp == null || !detailResp.isOk) continue;

        final MarketProductDraft? parsed = MarketPayloadParser.parseCepteSokDetailHtml(
          barcode: barcode,
          html: detailResp.body,
          fallbackTitle: currentDraft?.productName,
          fallbackBrand: currentDraft?.brand,
        );
        if (parsed != null) {
          return parsed;
        }
      }
    } catch (e) {
      debugPrint('CepteSokTgkStrategy error ($barcode): $e');
    }
    return null;
  }
}

/// Strategy 4: OpenFoodFacts fallback / TGK enrichment via [OpenFoodFactsService.fetchProductByBarcode].
class OpenFoodFactsFallbackStrategy implements MarketResolverStrategy {
  static final RegExp _summaryIngredientsRegex = RegExp(
    r'[İiIı]çindekiler\s*:\s*(.+)$',
    dotAll: true,
  );

  @override
  String get strategyId => 'open_food_facts';

  @override
  Future<MarketProductDraft?> resolve({
    required String barcode,
    MarketProductDraft? currentDraft,
    required MarketHttpGateway httpGateway,
  }) async {
    if (currentDraft != null && currentDraft.isFullyEnriched) {
      return null;
    }

    try {
      final ProductAnalysisResponse? offResponse = await OpenFoodFactsService
          .fetchProductByBarcode(barcode)
          .timeout(const Duration(seconds: 7));
      if (offResponse == null) {
        return null;
      }

      String extractedIngredients = offResponse.ingredientsText.trim();
      if (extractedIngredients.isEmpty) {
        final RegExpMatch? match =
            _summaryIngredientsRegex.firstMatch(offResponse.aiSummary);
        if (match != null) {
          extractedIngredients = (match.group(1) ?? '').trim();
        }
      }

      return MarketProductDraft(
        barcode: barcode,
        productName: offResponse.productName,
        brand: offResponse.brand,
        ingredientsText: extractedIngredients,
        nutriments: offResponse.nutriments,
        allergens: offResponse.allergens,
        netQuantity: offResponse.netQuantity,
        legalProducer: offResponse.legalProducer,
        resolverOrigins: const <String>['Open Food Facts'],
        resolvedFromTurkishMarket: false,
      );
    } on TimeoutException catch (e) {
      debugPrint('OpenFoodFactsFallbackStrategy timeout ($barcode): $e');
      return null;
    } catch (e) {
      debugPrint('OpenFoodFactsFallbackStrategy error ($barcode): $e');
      return null;
    }
  }
}

/// Pure stateless JSON/HTML parsing helpers for Turkish market endpoints (SRP).
class MarketPayloadParser {
  static final RegExp _sokProductSlugRegex = RegExp(r'(/[a-z0-9\-]+-p-\d+)');
  static final RegExp _sokKeyValueRegex = RegExp(
    r'ProductDescriptionTab_key__[^"]*">([^<]+)</p>\s*<p[^>]*ProductDescriptionTab_value__[^"]*">([^<]+)</p>',
    caseSensitive: false,
  );
  static final RegExp _sokAllergenInlineRegex = RegExp(
    r'Alerjen\s+Uyar[ıi]s[ıi]\s*:\s*([^<\n\r]+)',
    caseSensitive: false,
  );
  static final RegExp _sokTitleTagRegex = RegExp(
    r'<h1[^>]*>([^<]+)</h1>',
    caseSensitive: false,
  );

  static const Map<String, String> _marketDisplayMap = <String, String>{
    'bim': 'BİM',
    'a101': 'A101',
    'sok': 'ŞOK',
    'ceptesok': 'ŞOK',
    'migros': 'Migros',
    'carrefour': 'CarrefourSA',
    'carrefoursa': 'CarrefourSA',
    'tarim_kredi': 'Tarım Kredi',
    'tarimkredi': 'Tarım Kredi',
    'hakmar': 'Hakmar',
    'file': 'FİLE',
  };

  static List<String> parseTubitakDepots(String rawJson) {
    try {
      final dynamic decoded = jsonDecode(rawJson);
      if (decoded is! List) return const <String>[];
      final List<String> ids = <String>[];
      for (final dynamic item in decoded) {
        if (item is Map && item['id'] != null) {
          final String id = item['id'].toString().trim();
          if (id.isNotEmpty) {
            ids.add(id);
          }
        }
      }
      return ids;
    } catch (e) {
      debugPrint('parseTubitakDepots error: $e');
      return const <String>[];
    }
  }

  static MarketProductDraft? parseTubitakSearchByIdentity({
    required String barcode,
    required String rawJson,
  }) {
    try {
      final dynamic decoded = jsonDecode(rawJson);
      if (decoded is! Map) return null;
      final dynamic content = decoded['content'];
      if (content is! List || content.isEmpty) return null;

      final dynamic firstItem = content.first;
      if (firstItem is! Map) return null;

      final String title = (firstItem['title']?.toString() ?? '').trim();
      if (title.isEmpty) return null;

      final String brand = (firstItem['brand']?.toString() ?? '').trim();
      final String? netQuantity =
          _nonEmptyOrNull(firstItem['refinedVolumeOrWeight']?.toString());

      final Set<String> chains = <String>{};
      final List<double> prices = <double>[];

      final dynamic depotList = firstItem['productDepotInfoList'];
      if (depotList is List) {
        for (final dynamic depot in depotList) {
          if (depot is! Map) continue;
          final String rawMarket =
              (depot['marketAdi']?.toString() ?? '').trim().toLowerCase();
          if (rawMarket.isNotEmpty) {
            chains.add(_marketDisplayMap[rawMarket] ?? _titleCase(rawMarket));
          }
          final double? price = _parsePositiveDouble(depot['price']);
          if (price != null) {
            prices.add(price);
          }
        }
      }

      double? referencePrice;
      if (prices.isNotEmpty) {
        prices.sort();
        referencePrice = prices[prices.length ~/ 2];
      }

      return MarketProductDraft(
        barcode: barcode,
        productName: title,
        brand: brand.isNotEmpty ? brand : null,
        marketChains: chains.toList(),
        netQuantity: netQuantity,
        referencePriceTry: referencePrice,
        resolverOrigins: const <String>['TÜBİTAK MarketFiyatı'],
        resolvedFromTurkishMarket: true,
      );
    } catch (e) {
      debugPrint('parseTubitakSearchByIdentity error: $e');
      return null;
    }
  }

  static Map<String, dynamic>? selectBestMigrosCandidate({
    required String rawSearchJson,
    required String barcode,
    String? expectedName,
    String? expectedBrand,
    required bool searchedByBarcode,
  }) {
    try {
      final dynamic decoded = jsonDecode(rawSearchJson);
      if (decoded is! Map) return null;
      final dynamic data = decoded['data'];
      if (data is! Map) return null;

      List<dynamic> infos = const <dynamic>[];
      final dynamic searchInfo = data['searchInfo'];
      if (searchInfo is Map && searchInfo['storeProductInfos'] is List) {
        infos = searchInfo['storeProductInfos'] as List<dynamic>;
      } else if (data['products'] is List) {
        infos = data['products'] as List<dynamic>;
      }

      if (infos.isEmpty) return null;

      if (searchedByBarcode) {
        final dynamic first = infos.first;
        return first is Map ? Map<String, dynamic>.from(first) : null;
      }

      if (expectedName == null || expectedName.trim().isEmpty) {
        return null;
      }

      Map<String, dynamic>? bestMap;
      double bestScore = 0.0;

      for (final dynamic candidate in infos.take(8)) {
        if (candidate is! Map) continue;
        final String candName = (candidate['name']?.toString() ?? '').trim();
        String candBrand = '';
        if (candidate['brand'] is Map) {
          candBrand = (candidate['brand']['name']?.toString() ?? '').trim();
        } else if (candidate['brand'] != null) {
          candBrand = candidate['brand'].toString().trim();
        }

        final double similarity = computeProductSimilarity(
          expectedName: expectedName,
          expectedBrand: expectedBrand,
          candidateName: candName,
          candidateBrand: candBrand,
        );

        if (similarity > bestScore) {
          bestScore = similarity;
          bestMap = Map<String, dynamic>.from(candidate);
        }
      }

      return bestScore >= 0.45 ? bestMap : null;
    } catch (e) {
      debugPrint('selectBestMigrosCandidate error: $e');
      return null;
    }
  }

  static MarketProductDraft? parseMigrosScreenDetail({
    required String barcode,
    required String rawDetailJson,
  }) {
    try {
      final dynamic decoded = jsonDecode(rawDetailJson);
      if (decoded is! Map) return null;
      final dynamic data = decoded['data'];
      if (data is! Map) return null;

      final Map<dynamic, dynamic> dto = data['storeProductInfoDTO'] is Map
          ? data['storeProductInfoDTO'] as Map<dynamic, dynamic>
          : data;

      final String? name = _nonEmptyOrNull(dto['name']?.toString());
      String? brand;
      if (dto['brand'] is Map) {
        brand = _nonEmptyOrNull(dto['brand']['name']?.toString());
      } else if (dto['brand'] != null) {
        brand = _nonEmptyOrNull(dto['brand'].toString());
      }

      String ingredients = '';
      final List<String> allergens = <String>[];
      String? netQuantity;
      String? legalProducer;
      final Map<String, double> nutriments = <String, double>{};

      final dynamic propMap = dto['propertyInfosMap'];
      if (propMap is Map) {
        final dynamic mainList = propMap['MAIN'];
        if (mainList is List) {
          for (final dynamic item in mainList) {
            if (item is! Map) continue;
            final String propName = (item['name']?.toString() ?? '').trim();
            final String customId = (item['customId']?.toString() ?? '').trim();
            final String propVal =
                _stripHtml(item['value']?.toString() ?? '').trim();
            if (propVal.isEmpty) continue;

            final String lowerProp = propName.toLowerCase();
            if (lowerProp.contains('içindekiler') || lowerProp.contains('icindekiler')) {
              ingredients = propVal;
            } else if (lowerProp.contains('alerjen')) {
              allergens.addAll(_parseAllergenText(propVal));
            } else if (customId == 'netKg' || lowerProp.contains('net miktar')) {
              netQuantity = propVal;
            }
          }
        }

        final dynamic legalList = propMap['LEGAL'];
        if (legalList is List) {
          for (final dynamic item in legalList) {
            if (item is! Map) continue;
            final String propName = (item['name']?.toString() ?? '').trim();
            final String customId = (item['customId']?.toString() ?? '').trim();
            final String propVal =
                _stripHtml(item['value']?.toString() ?? '').trim();
            if (propVal.isEmpty) continue;

            if (customId == 'productSupplier' ||
                (propName.toLowerCase().contains('üretici') &&
                    !propName.toLowerCase().contains('adres'))) {
              legalProducer = propVal;
            }
          }
        }

        final dynamic nutrList = propMap['NUTRITIONAL'];
        if (nutrList is List) {
          for (final dynamic item in nutrList) {
            if (item is! Map) continue;
            final String customId = (item['customId']?.toString() ?? '').trim();
            final String propName =
                (item['name']?.toString() ?? '').trim().toLowerCase();
            final double? val = _parseNonNegativeDouble(item['value']);
            if (val == null) continue;

            if (customId == 'energyKcal' || propName.contains('kcal')) {
              nutriments['energy-kcal_100g'] = val;
            } else if (customId == 'fat' ||
                (propName.startsWith('yağ') || propName.startsWith('yag'))) {
              nutriments['fat_100g'] = val;
            } else if (customId == 'saturatedFat' || propName.contains('doymuş')) {
              nutriments['saturated-fat_100g'] = val;
            } else if (customId == 'carbohydrate' ||
                propName.contains('karbonhidrat')) {
              nutriments['carbohydrates_100g'] = val;
            } else if (customId == 'glucose' ||
                propName.contains('şeker') ||
                propName.contains('seker')) {
              nutriments['sugars_100g'] = val;
            } else if (customId == 'fiber' || propName.startsWith('lif')) {
              nutriments['fiber_100g'] = val;
            } else if (customId == 'protein' || propName.contains('protein')) {
              nutriments['proteins_100g'] = val;
            } else if (customId == 'salt' || propName.startsWith('tuz')) {
              nutriments['salt_100g'] = val;
              nutriments['sodium_100g'] = val / 2.5;
            }
          }
        }
      }

      double? priceTry;
      final double? rawShownPrice = _parsePositiveDouble(dto['shownPrice']);
      if (rawShownPrice != null) {
        priceTry = rawShownPrice > 500 ? (rawShownPrice / 100.0) : rawShownPrice;
      }

      if (name == null && ingredients.isEmpty && nutriments.isEmpty) {
        return null;
      }

      return MarketProductDraft(
        barcode: barcode,
        productName: name,
        brand: brand,
        ingredientsText: ingredients,
        nutriments: nutriments,
        allergens: allergens,
        marketChains: const <String>['Migros'],
        netQuantity: netQuantity,
        legalProducer: legalProducer,
        referencePriceTry: priceTry,
        resolverOrigins: const <String>['Migros TGK'],
        resolvedFromTurkishMarket: true,
      );
    } catch (e) {
      debugPrint('parseMigrosScreenDetail error: $e');
      return null;
    }
  }

  static String? selectBestCepteSokPath({
    required String html,
    String? expectedName,
    String? expectedBrand,
    required bool searchedByBarcode,
  }) {
    final Iterable<RegExpMatch> matches = _sokProductSlugRegex.allMatches(html);
    final List<String> uniquePaths = <String>[];
    final Set<String> seen = <String>{};
    for (final RegExpMatch m in matches) {
      final String? slug = m.group(1);
      if (slug != null && seen.add(slug)) {
        uniquePaths.add(slug);
      }
      if (uniquePaths.length >= 8) break;
    }
    if (uniquePaths.isEmpty) return null;

    if (searchedByBarcode) {
      return uniquePaths.first;
    }
    if (expectedName == null || expectedName.trim().isEmpty) {
      return null;
    }

    String? bestPath;
    double bestScore = 0.0;
    for (final String path in uniquePaths) {
      final String slugWords = path
          .replaceAll(RegExp(r'-p-\d+$'), '')
          .replaceAll('/', ' ')
          .replaceAll('-', ' ');
      final double score = computeProductSimilarity(
        expectedName: expectedName,
        expectedBrand: expectedBrand,
        candidateName: slugWords,
        candidateBrand: expectedBrand,
      );
      if (score > bestScore) {
        bestScore = score;
        bestPath = path;
      }
    }
    return bestScore >= 0.45 ? bestPath : null;
  }

  static MarketProductDraft? parseCepteSokDetailHtml({
    required String barcode,
    required String html,
    String? fallbackTitle,
    String? fallbackBrand,
  }) {
    try {
      String ingredients = '';
      String? legalProducer;
      String? netQuantity;
      final List<String> allergens = <String>[];

      for (final RegExpMatch match in _sokKeyValueRegex.allMatches(html)) {
        final String key = _stripHtml(match.group(1) ?? '').trim().toLowerCase();
        final String val = _stripHtml(match.group(2) ?? '').trim();
        if (val.isEmpty) continue;

        if (key.contains('içindekiler') || key.contains('icindekiler')) {
          ingredients = val;
        } else if (key.contains('işletmeci') || key.contains('üretici')) {
          legalProducer = val;
        } else if (key.contains('net miktar')) {
          netQuantity = val;
        } else if (key.contains('alerjen')) {
          allergens.addAll(_parseAllergenText(val));
        }
      }

      if (allergens.isEmpty) {
        final RegExpMatch? inlineAllergen = _sokAllergenInlineRegex.firstMatch(html);
        if (inlineAllergen != null) {
          allergens.addAll(_parseAllergenText(inlineAllergen.group(1) ?? ''));
        }
      }

      String? pageTitle = fallbackTitle;
      if (pageTitle == null || pageTitle.trim().isEmpty) {
        final RegExpMatch? h1Match = _sokTitleTagRegex.firstMatch(html);
        if (h1Match != null) {
          pageTitle = _stripHtml(h1Match.group(1) ?? '').trim();
        }
      }

      if ((pageTitle == null || pageTitle.isEmpty) && ingredients.isEmpty) {
        return null;
      }

      return MarketProductDraft(
        barcode: barcode,
        productName: pageTitle,
        brand: fallbackBrand,
        ingredientsText: ingredients,
        allergens: allergens,
        marketChains: const <String>['ŞOK'],
        netQuantity: netQuantity,
        legalProducer: legalProducer,
        resolverOrigins: const <String>['Cepte ŞOK TGK'],
        resolvedFromTurkishMarket: true,
      );
    } catch (e) {
      debugPrint('parseCepteSokDetailHtml error: $e');
      return null;
    }
  }

  static String buildCleanSearchQuery({
    required String productName,
    String? brand,
  }) {
    final String cleaned = productName
        .replaceAll(RegExp(r'[()\[\],/]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (brand != null &&
        brand.trim().isNotEmpty &&
        !OfflineFallbackManager.normalizeForMatching(cleaned)
            .contains(OfflineFallbackManager.normalizeForMatching(brand))) {
      return '${brand.trim()} $cleaned'.trim();
    }
    return cleaned;
  }

  static double computeProductSimilarity({
    required String expectedName,
    String? expectedBrand,
    required String candidateName,
    String? candidateBrand,
  }) {
    final String normExpected = OfflineFallbackManager.normalizeForMatching(expectedName);
    final String normCandidate = OfflineFallbackManager.normalizeForMatching(candidateName);
    if (normExpected.isEmpty || normCandidate.isEmpty) return 0.0;

    if (expectedBrand != null &&
        expectedBrand.trim().isNotEmpty &&
        candidateBrand != null &&
        candidateBrand.trim().isNotEmpty) {
      final String b1 = OfflineFallbackManager.normalizeForMatching(expectedBrand);
      final String b2 = OfflineFallbackManager.normalizeForMatching(candidateBrand);
      if (b1.isNotEmpty && b2.isNotEmpty && b1 != b2 && !normCandidate.contains(b1)) {
        return 0.0;
      }
    }

    final Set<String> expTokens =
        normExpected.split(' ').where((t) => t.length >= 2).toSet();
    final Set<String> candTokens =
        normCandidate.split(' ').where((t) => t.length >= 2).toSet();
    if (expTokens.isEmpty || candTokens.isEmpty) return 0.0;

    final int intersection = expTokens.intersection(candTokens).length;
    return intersection / expTokens.length;
  }

  static List<String> _parseAllergenText(String raw) {
    final String cleaned = _stripHtml(raw).trim();
    final String lower = cleaned.toLowerCase();
    if (cleaned.isEmpty ||
        lower.contains('alerjen içermez') ||
        lower.contains('alerjen icermez') ||
        lower == 'yok' ||
        lower == 'yoktur' ||
        lower == '-') {
      return const <String>[];
    }
    return <String>[cleaned];
  }

  static String _stripHtml(String input) {
    return input
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String? _nonEmptyOrNull(String? value) {
    if (value == null) return null;
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static double? _parsePositiveDouble(dynamic raw) {
    final double? val = _parseNonNegativeDouble(raw);
    return (val != null && val > 0) ? val : null;
  }

  static double? _parseNonNegativeDouble(dynamic raw) {
    if (raw == null) return null;
    if (raw is num) {
      final double d = raw.toDouble();
      return (d.isFinite && d >= 0) ? d : null;
    }
    final String cleaned = raw
        .toString()
        .replaceAll(RegExp(r'[^0-9,.\-]'), '')
        .replaceAll(',', '.')
        .trim();
    final double? parsed = double.tryParse(cleaned);
    if (parsed == null || !parsed.isFinite || parsed < 0) return null;
    return parsed;
  }

  static String _titleCase(String raw) {
    if (raw.isEmpty) return raw;
    return raw[0].toUpperCase() + raw.substring(1);
  }
}

class _BoundedTtlLruCache<K, V> {
  final int maxEntries;
  final Duration ttl;
  final LinkedHashMap<K, ({V value, DateTime expiresAt})> _store =
      LinkedHashMap<K, ({V value, DateTime expiresAt})>();

  _BoundedTtlLruCache({
    required this.maxEntries,
    required this.ttl,
  });

  V? get(K key) {
    final entry = _store.remove(key);
    if (entry == null) return null;
    if (DateTime.now().isAfter(entry.expiresAt)) {
      return null;
    }
    _store[key] = entry;
    return entry.value;
  }

  void put(K key, V value) {
    _store.remove(key);
    while (_store.length >= maxEntries && _store.isNotEmpty) {
      _store.remove(_store.keys.first);
    }
    _store[key] = (value: value, expiresAt: DateTime.now().add(ttl));
  }
}

/// Orchestrator service resolving Turkish market barcodes via OCP strategy chain,
/// scoring with [OrganicScoreCalculator.calculate], and caching into SQLite.
class TurkishMarketResolverService {
  static final _BoundedTtlLruCache<String, ProductAnalysisResponse> _memoryCache =
      _BoundedTtlLruCache<String, ProductAnalysisResponse>(
    maxEntries: 128,
    ttl: const Duration(minutes: 20),
  );

  static final List<MarketResolverStrategy> _defaultStrategies =
      List<MarketResolverStrategy>.unmodifiable(<MarketResolverStrategy>[
    TubitakMarketFiyatiStrategy(),
    MigrosTgkStrategy(),
    CepteSokTgkStrategy(),
    OpenFoodFactsFallbackStrategy(),
  ]);

  static final RegExp _eCodeRegex = RegExp(
    r'\b[Ee][\s\-\.]?\d{3,4}[a-zA-Z]?\b',
    caseSensitive: false,
  );

  /// Validates GS1 EAN-8 / EAN-13 Modulo-10 check digit and rejects 13-digit PLU (20-29) & synthetic `8690772000` barcodes.
  static bool isValidGs1Barcode(String barcode) {
    return DatabaseHelper.isValidGs1Barcode(barcode);
  }

  /// Resolves [barcode] sequentially through TÜBİTAK MarketFiyatı -> Migros TGK -> Cepte ŞOK TGK -> OpenFoodFacts,
  /// scores with [OrganicScoreCalculator.calculate], and caches into SQLite via [DatabaseHelper.saveSnapshot].
  static Future<ProductAnalysisResponse?> resolveByBarcode(
    String barcode, {
    bool persistToLocalCache = true,
    List<MarketResolverStrategy>? strategies,
    MarketHttpGateway? httpGateway,
  }) async {
    final String cleanBarcode = barcode.trim();
    if (!isValidGs1Barcode(cleanBarcode)) {
      return null;
    }

    final ProductAnalysisResponse? cached = _memoryCache.get(cleanBarcode);
    if (cached != null) {
      return cached;
    }

    final bool ownsGateway = httpGateway == null;
    final MarketHttpGateway gateway = httpGateway ?? HttpMarketGateway();
    final List<MarketResolverStrategy> activeStrategies =
        strategies ?? _defaultStrategies;

    MarketProductDraft? accumulatedDraft;
    try {
      for (final MarketResolverStrategy strategy in activeStrategies) {
        final MarketProductDraft? partial = await strategy.resolve(
          barcode: cleanBarcode,
          currentDraft: accumulatedDraft,
          httpGateway: gateway,
        );
        if (partial != null) {
          accumulatedDraft = accumulatedDraft == null
              ? partial
              : accumulatedDraft.mergeWith(partial);
        }
        if (accumulatedDraft != null && accumulatedDraft.isFullyEnriched) {
          break;
        }
      }
    } catch (e) {
      debugPrint('TurkishMarketResolverService pipeline error ($cleanBarcode): $e');
    } finally {
      if (ownsGateway) {
        gateway.close();
      }
    }

    if (accumulatedDraft == null || !accumulatedDraft.hasIdentity) {
      return null;
    }

    final ProductAnalysisResponse response = await _evaluateAndBuildResponse(
      draft: accumulatedDraft,
      persistToLocalCache: persistToLocalCache,
    );

    if (!response.isDataIncomplete) {
      _memoryCache.put(cleanBarcode, response);
    }
    return response;
  }

  static Future<ProductAnalysisResponse> _evaluateAndBuildResponse({
    required MarketProductDraft draft,
    required bool persistToLocalCache,
  }) async {
    final String productName = draft.productName!.trim();
    final String brand = (draft.brand != null && draft.brand!.trim().isNotEmpty)
        ? draft.brand!.trim()
        : 'Doğrulanmış Üretici';
    final String ingredientsText = draft.ingredientsText.trim();
    final String lowerName = productName.toLowerCase();
    final String lowerIng = ingredientsText.toLowerCase();

    Map<String, String> boycottEval;
    try {
      boycottEval = await OfflineFallbackManager.getBoycottStatus(
        productName: productName,
        brandName: brand,
      );
    } catch (e) {
      debugPrint('Boycott lookup fallback note: $e');
      boycottEval = OfflineFallbackManager.evaluateBoycottStatus(
        productName: productName,
        brandName: brand,
        boycottBrands: const <Map<String, dynamic>>[],
      );
    }
    final String boycottStatus = boycottEval['status_flag'] ?? 'CLEAR';
    final String boycottReason =
        boycottEval['reason'] ?? 'Etik kaynak veritabanı kontrollü.';

    final bool isPureNatural = _isRecognizedNaturalFood(lowerName, lowerIng);
    final bool isIncomplete =
        !draft.hasIngredients && !draft.hasNutriments && !isPureNatural;

    final ScanDataSource dataSource = draft.resolvedFromTurkishMarket
        ? ScanDataSource.onlineTurkishMarketApi
        : ScanDataSource.onlineCloudWorker;

    if (isIncomplete) {
      final String chainsSuffix = draft.marketChains.isNotEmpty
          ? ' (${draft.marketChains.take(4).join(' / ')})'
          : '';
      return ProductAnalysisResponse(
        barcode: draft.barcode,
        productName: productName,
        brand: brand,
        organicScore: -1,
        scoreCategory: 'İçerik Bilgisi Eksik',
        novaGroup: 0,
        novaVerdict: 'İçindekiler Bilgisi Eksik (Doğrulanmadı)',
        boycottStatus: boycottStatus,
        boycottReason: boycottReason,
        aiSummary:
            '$brand üreticisine ait $productName$chainsSuffix. Paketin arkasındaki TGK içindekiler etiketini fotoğraflayarak tam analiz yapabilirsiniz.',
        warnings: const <String>['TGK İçindekiler ve Besin Değerleri Henüz Eşleşmedi'],
        alternatives: const <Map<String, String>>[],
        source: dataSource,
        statusBadgeText: '⚠️ Market Kaydı Doğrulandı$chainsSuffix — İçerik Etiketi Bekleniyor',
        isDataIncomplete: true,
        marketChains: draft.marketChains,
        netQuantity: draft.netQuantity,
        legalProducer: draft.legalProducer,
        referencePriceTry: draft.referencePriceTry,
      );
    }

    final ({List<String> riskLevels, List<String> warnings}) additiveAnalysis =
        await _extractAdditiveRisksAndWarnings(ingredientsText);

    final int novaGroup = _determineNovaGroup(
      lowerName: lowerName,
      lowerIngredients: lowerIng,
      ingredientsRaw: ingredientsText,
      isPureNatural: isPureNatural,
    );

    final double sugar =
        draft.nutriments['sugars_100g'] ?? (isPureNatural ? 0.5 : 5.0);
    final double satFat =
        draft.nutriments['saturated-fat_100g'] ?? (isPureNatural ? 1.0 : 2.0);
    final double sodium = draft.nutriments['sodium_100g'] ??
        (draft.nutriments['salt_100g'] != null
            ? draft.nutriments['salt_100g']! / 2.5
            : (isPureNatural ? 0.04 : 0.2));
    final double fiber =
        draft.nutriments['fiber_100g'] ?? (isPureNatural ? 2.0 : 1.0);
    final double protein =
        draft.nutriments['proteins_100g'] ?? (isPureNatural ? 3.5 : 3.0);

    final OrganicScoreResult scoreResult = OrganicScoreCalculator.calculate(
      riskLevels: additiveAnalysis.riskLevels,
      sugarGramsPer100g: sugar,
      satFatGramsPer100g: satFat,
      sodiumGramsPer100g: sodium,
      fiberGramsPer100g: fiber,
      proteinGramsPer100g: protein,
      novaGroup: novaGroup,
    );

    final List<String> warnings = <String>[
      ...additiveAnalysis.warnings,
      if (sugar > 15.0)
        'Yüksek Şeker Oranı (100g üründe ${sugar.toStringAsFixed(1)}g şeker)',
      if (satFat > 5.0)
        'Yüksek Doymuş Yağ (100g üründe ${satFat.toStringAsFixed(1)}g)',
      if (sodium > 0.6)
        'Yüksek Tuz / Sodyum İçeriği',
    ];

    final RecommendationResult recResult =
        AlternativeRecommendationEngine.getRecommendations(
      currentBarcode: draft.barcode,
      currentProductName: productName,
      currentBrand: brand,
      currentScore: scoreResult.overallScore,
      currentBoycottStatus: boycottStatus,
      rawIngredients: ingredientsText,
    );
    final List<Map<String, String>> alternatives =
        recResult.alternatives.take(3).map((a) => a.toMap()).toList();

    final String chainsLabel = draft.marketChains.isNotEmpty
        ? draft.marketChains.take(4).join(' / ')
        : (draft.resolvedFromTurkishMarket ? 'Ulusal Market' : 'Açık Veri');

    final String statusBadgeText = draft.resolvedFromTurkishMarket
        ? '🇹🇷 Canlı Türkiye Market & TGK Doğrulaması ($chainsLabel)'
        : '🌐 Canlı Mod: Open Food Facts & Cloud AI Analizi';

    final String priceInfo = draft.referencePriceTry != null
        ? ' Referans Market Fiyatı: ₺${draft.referencePriceTry!.toStringAsFixed(2)}.'
        : '';
    final String summaryText =
        '$brand markasına ait $productName.$priceInfo ${ingredientsText.isNotEmpty ? "İçindekiler: $ingredientsText" : "TGK besin profili doğrulandı."}';

    if (persistToLocalCache) {
      try {
        await DatabaseHelper().saveSnapshot(
          barcode: draft.barcode,
          productName: productName,
          brand: brand,
          aiSummaryJson: <String, dynamic>{
            'organic_score': scoreResult.overallScore,
            'nova_group': novaGroup,
            'verdict': scoreResult.novaVerdict,
            'summary': summaryText,
            'warnings': warnings,
            'alternatives': alternatives,
            'ingredients_text': ingredientsText,
            'nutriments': draft.nutriments,
            'allergens': draft.allergens,
            'market_chains': draft.marketChains,
            if (draft.netQuantity != null) 'net_quantity': draft.netQuantity,
            if (draft.legalProducer != null) 'legal_producer': draft.legalProducer,
            if (draft.referencePriceTry != null)
              'reference_price_try': draft.referencePriceTry,
            'boycott_status': boycottStatus,
            'boycott_reason': boycottReason,
            'resolved_sources': draft.resolverOrigins,
          },
        );
      } catch (e) {
        debugPrint('SQLite snapshot cache save note (${draft.barcode}): $e');
      }
    }

    return ProductAnalysisResponse(
      barcode: draft.barcode,
      productName: productName,
      brand: brand,
      organicScore: scoreResult.overallScore,
      scoreCategory: scoreResult.ratingCategory,
      novaGroup: novaGroup,
      novaVerdict: scoreResult.novaVerdict,
      boycottStatus: boycottStatus,
      boycottReason: boycottReason,
      aiSummary: summaryText,
      warnings: warnings,
      alternatives: alternatives,
      source: dataSource,
      statusBadgeText: statusBadgeText,
      isDataIncomplete: false,
      ingredientsText: ingredientsText,
      nutriments: draft.nutriments,
      allergens: draft.allergens,
      marketChains: draft.marketChains,
      netQuantity: draft.netQuantity,
      legalProducer: draft.legalProducer,
      referencePriceTry: draft.referencePriceTry,
    );
  }

  static Future<({List<String> riskLevels, List<String> warnings})>
      _extractAdditiveRisksAndWarnings(String ingredientsText) async {
    if (ingredientsText.isEmpty) {
      return (riskLevels: const <String>[], warnings: const <String>[]);
    }

    final List<String> riskLevels = <String>[];
    final Set<String> warnings = <String>{};

    try {
      final IngredientParseResult parsed =
          await IngredientParser.parseIngredients(ingredientsText);
      for (final DetectedAdditive additive in parsed.additives) {
        riskLevels.add(additive.riskLevel);
        if (additive.riskLevel == 'HIGH' || additive.riskLevel == 'TOXIC') {
          warnings.add('${additive.code} (${additive.name}) yüksek riskli katkı');
        }
      }
    } catch (e) {
      debugPrint('IngredientParser SQLite lookup fallback note: $e');
    }

    final String lower = ingredientsText.toLowerCase();
    const Map<String, (String risk, String label)> biochemicalMarkers =
        <String, (String, String)>{
      'sodyum nitrit': ('TOXIC', 'Sodyum Nitrit (E250) İşlenmiş Et Koruyucusu'),
      'titanyum dioksit': ('TOXIC', 'Titanyum Dioksit (E171)'),
      'glikoz şurubu': ('HIGH', 'Glikoz / Mısır Şurubu'),
      'fruktoz şurubu': ('HIGH', 'Fruktoz Şurubu'),
      'glikoz-fruktoz': ('HIGH', 'Glikoz-Fruktoz Şurubu'),
      'hidrojenize': ('HIGH', 'Hidrojenize Bitkisel Yağ (Trans Yağ Riski)'),
      'monosodyum glutamat': ('HIGH', 'Monosodyum Glutamat (Çin Tuzu / E621)'),
      'aspartam': ('HIGH', 'Aspartam (Yapay Tatlandırıcı)'),
      'palm': ('MODERATE', 'Palm Yağı'),
      'karagenan': ('MODERATE', 'Karagenan (Kıvam Artırıcı)'),
      'aroma verici': ('MODERATE', 'Yapay / Doğala Özdeş Aroma Verici'),
      'emülgatör': ('LOW', 'Emülgatör Katkısı'),
    };

    biochemicalMarkers.forEach((String term, (String, String) meta) {
      if (lower.contains(term)) {
        riskLevels.add(meta.$1);
        warnings.add(meta.$2);
      }
    });

    if (riskLevels.isEmpty && _eCodeRegex.hasMatch(ingredientsText)) {
      riskLevels.add('MODERATE');
    }

    return (riskLevels: riskLevels, warnings: warnings.toList());
  }

  static bool _isRecognizedNaturalFood(String lowerName, String lowerIng) {
    final bool hasUltraMarkers = lowerIng.contains('glikoz') ||
        lowerIng.contains('fruktoz') ||
        lowerIng.contains('palm') ||
        lowerIng.contains('hidrojenize') ||
        lowerIng.contains('emülgatör') ||
        lowerIng.contains('aroma verici') ||
        lowerIng.contains('tatlandırıcı') ||
        lowerIng.contains('şeker') ||
        _eCodeRegex.hasMatch(lowerIng);
    if (hasUltraMarkers) return false;

    const List<String> naturalKeywords = <String>[
      'zeytinyağ',
      'maden suyu',
      'doğal kaynak suyu',
      'içme suyu',
      'yumurta',
      'mercimek',
      'nohut',
      'fasulye',
      'bulgur',
      'pirinç',
      'yulaf ezmesi',
      'tam yağlı süt',
      'yarım yağlı süt',
      'pastörize süt',
      'süzme yoğurt',
      'doğal yoğurt',
      'çiçek balı',
      'çam balı',
      'siyah çay',
    ];
    return naturalKeywords.any((String kw) => lowerName.contains(kw));
  }

  static int _determineNovaGroup({
    required String lowerName,
    required String lowerIngredients,
    required String ingredientsRaw,
    required bool isPureNatural,
  }) {
    final int eCount = _eCodeRegex.allMatches(ingredientsRaw).length;
    if (eCount >= 2 ||
        lowerIngredients.contains('glikoz') ||
        lowerIngredients.contains('fruktoz') ||
        lowerIngredients.contains('palm') ||
        lowerIngredients.contains('hidrojenize') ||
        lowerIngredients.contains('monosodyum glutamat') ||
        lowerIngredients.contains('aspartam') ||
        lowerIngredients.contains('asesülfam') ||
        lowerIngredients.contains('aroma verici') ||
        lowerIngredients.contains('emülgatör') ||
        lowerIngredients.contains('renklendirici')) {
      return 4;
    }

    if (lowerName.contains('zeytinyağ') ||
        lowerName.contains('tereyağ') ||
        lowerName.contains('ayçiçek yağ') ||
        lowerName.contains('sirke')) {
      return 2;
    }

    if (isPureNatural && eCount == 0) {
      return 1;
    }

    return 3;
  }
}
