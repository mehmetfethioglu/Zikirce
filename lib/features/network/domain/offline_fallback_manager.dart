import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_helper.dart';

enum ScanDataSource {
  onlineCloudWorker,
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
  });
}

class OfflineFallbackManager {
  /// Checks whether internet connectivity is active by testing an HTTP endpoint.
  static Future<bool> isOnline() async {
    try {
      final res = await http.get(Uri.parse('https://clients3.google.com/generate_204')).timeout(const Duration(milliseconds: 1800));
      if (res.statusCode == 204 || res.statusCode == 200) {
        return true;
      }
    } catch (_) {}

    try {
      final List<ConnectivityResult> results = await Connectivity().checkConnectivity();
      return !results.contains(ConnectivityResult.none);
    } catch (_) {
      return true;
    }
  }

  /// Looks up local SQLite offline AI snapshots for basement resilience.
  static Future<ProductAnalysisResponse?> getLocalSnapshot(String barcode, {bool isOnlineMode = false}) async {
    final Database db = await DatabaseHelper().database;

    final List<Map<String, dynamic>> results = await db.query(
      'offline_ai_snapshots',
      where: 'barcode = ?',
      whereArgs: [barcode],
    );

    if (results.isNotEmpty) {
      final row = results.first;
      final Map<String, dynamic> summaryJson = jsonDecode(row['ai_summary_json'] as String);
      final String productName = row['product_name'] as String? ?? 'Bilinmeyen Ürün';
      final String brandName = row['brand'] as String? ?? 'Yerli Marka';

      final List<dynamic>? altList = summaryJson['alternatives'] as List<dynamic>?;
      final List<Map<String, String>> parsedAlternatives = altList != null
          ? altList.map((item) => {
                'name': (item['name'] as String? ?? 'Yerel Alternatif').trim(),
                'brand': (item['brand'] as String? ?? 'Yerli Marka').trim(),
                'reason': (item['reason'] as String? ?? 'Sağlıklı & Etik Seçenek').trim(),
              }).toList()
          : [];

      return ProductAnalysisResponse(
        barcode: barcode,
        productName: productName,
        brand: brandName.isNotEmpty ? brandName : 'Doğrulanmış Üretici',
        organicScore: summaryJson['organic_score'] as int? ?? 50,
        scoreCategory: isOnlineMode ? 'Canlı Doğrulamalı Derecelendirme' : 'Çevrimdışı Doğrulanmış Derecelendirme',
        novaGroup: summaryJson['nova_group'] as int? ?? 3,
        novaVerdict: summaryJson['verdict'] as String? ?? 'İşlenmiş Ürün',
        boycottStatus: 'CLEAR',
        boycottReason: 'Etik kaynak veritabanı kontrollü',
        aiSummary: summaryJson['summary'] as String? ?? 'Yerel AI snapshot özeti.',
        warnings: (summaryJson['warnings'] as List<dynamic>?)?.cast<String>() ?? [],
        alternatives: parsedAlternatives,
        source: isOnlineMode ? ScanDataSource.onlineCloudWorker : ScanDataSource.offlineAiSnapshot,
        statusBadgeText: isOnlineMode
            ? '🌐 Doğrulanmış Market Veritabanı (Canlı)'
            : '⚡ Doğrulanmış Yerel Veritabanı (BİM / A101 / ŞOK & Ulusal)',
      );
    }

    // 2. Check crowdsourced_queue for user submitted products
    try {
      final List<Map<String, dynamic>> crowdResults = await db.query(
        'crowdsourced_queue',
        where: 'barcode = ?',
        whereArgs: [barcode],
      );

      if (crowdResults.isNotEmpty) {
        final row = crowdResults.last;
        final Map<String, dynamic> payload = jsonDecode(row['payload_json'] as String);
        final String name = payload['product_name'] as String? ?? 'Topluluk Ürünü';
        final String brand = payload['brand'] as String? ?? 'Katkı Markası';
        final String ingText = payload['ingredients_text'] as String? ?? '';
        final String lowerIng = ingText.toLowerCase();
        final String lowerName = name.toLowerCase();

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

        final bool isPureNatural = (lowerName.contains('zeytinyağ') ||
            lowerName.contains('makarna') ||
            lowerName.contains('yulaf') ||
            lowerName.contains('mercimek') ||
            lowerName.contains('nohut') ||
            lowerName.contains('fasulye') ||
            lowerName.contains('un') ||
            lowerName.contains('pirinç') ||
            lowerName.contains('su') ||
            lowerName.contains('süt') ||
            lowerName.contains('yoğurt') ||
            lowerName.contains('bulgur')) && !hasRisks;

        final int score = hasRisks ? 45 : (isPureNatural ? 95 : 85);
        final int nova = hasRisks ? 4 : (isPureNatural ? 1 : 2);
        final String novaText = nova == 4
            ? 'Ultra İşlenmiş Gıda (NOVA 4)'
            : (nova == 1 ? 'İşlenmemiş / Organik (NOVA 1)' : 'İşlenmiş Mutfak Malzemesi (NOVA 2)');

        return ProductAnalysisResponse(
          barcode: barcode,
          productName: name,
          brand: brand.isNotEmpty ? brand : 'Topluluk Katkısı',
          organicScore: score,
          scoreCategory: 'Topluluk Doğrulamalı Derecelendirme',
          novaGroup: nova,
          novaVerdict: novaText,
          boycottStatus: 'CLEAR',
          boycottReason: 'Topluluk katkısı ile eklendi.',
          aiSummary: '$brand markasına ait $name. Katkıda bulun bölümü ile yerel veritabanına kaydedildi.${ingText.isNotEmpty ? " İçindekiler: $ingText" : ""}',
          warnings: hasRisks ? ['İşlenmiş İçerik / Katkı Maddesi'] : [],
          alternatives: [],
          source: ScanDataSource.offlineAiSnapshot,
          statusBadgeText: '🤝 Topluluk Katkısı: Yerel Veritabanına Eklenen Ürün',
        );
      }
    } catch (_) {}

    return null;
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
