import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/database/database_helper.dart';
import '../../product/domain/alternative_recommendation_engine.dart';
import '../../scoring/domain/organic_score_calculator.dart';
import 'offline_fallback_manager.dart';

class OpenFoodFactsService {
  static const List<String> _processedFoodBlocklist = [
    'sucuk',
    'salam',
    'sosis',
    'cikolata',
    'biskuvi',
    'gofret',
    'cips',
    'kraker',
    'kek',
    'pasta',
    'seker',
    'gevrek',
    'susam',
    'sos',
    'surup',
    'arom',
    'tatli',
    'dondurma',
    'kola',
    'gazoz',
    'enerji',
    'krem',
    'bar',
    'karisim',
    'hazir',
    'pogaca',
    'borek',
    'margar',
  ];

  static const List<String> _pureNaturalKeywords = [
    'zeytinyagi',
    'sizma zeytinyagi',
    'makarna',
    'yulaf',
    'yulaf ezmesi',
    'mercimek',
    'kirmizi mercimek',
    'yesil mercimek',
    'nohut',
    'fasulye',
    'kuru fasulye',
    'bulgur',
    'un',
    'tam bugday unu',
    'irmik',
    'pirinc',
    'su',
    'maden suyu',
    'sut',
    'yogurt',
    'cay',
    'bal',
    'yumurta',
  ];

  /// Word-boundary aware check that avoids false positives like "Sucuk" matching "su"
  /// or "Sütlü Çikolata" matching "süt".
  static bool isPureNaturalFoodName(
    String productName, {
    String ingredientsText = '',
  }) {
    final String normName = OfflineFallbackManager.normalizeForMatching(productName);
    if (normName.isEmpty) return false;

    final String normIng = OfflineFallbackManager.normalizeForMatching(ingredientsText);
    final String combined = '$normName $normIng';

    for (final String blocked in _processedFoodBlocklist) {
      if (combined.contains(blocked)) {
        return false;
      }
    }

    for (final String keyword in _pureNaturalKeywords) {
      final RegExp pattern = RegExp('(^|\\s)${RegExp.escape(keyword)}(\\s|\$)');
      if (pattern.hasMatch(normName)) {
        return true;
      }
    }
    return false;
  }

  static Future<ProductAnalysisResponse?> fetchProductByBarcode(String barcode) async {
    try {
      final url = Uri.parse('https://world.openfoodfacts.org/api/v2/product/$barcode.json');
      final headers = {
        'User-Agent': 'KilerceApp - Mobile - Version 3.2 (contact@organicscore.app)',
        'Accept': 'application/json',
      };
      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 7));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        if (data['status'] == 1 && data['product'] != null) {
          final product = data['product'];
          final String name = product['product_name_tr'] ??
              product['product_name'] ??
              product['product_name_en'] ??
              'Barkodlu Ürün ($barcode)';
          final String brand = (product['brands'] as String? ?? 'Genel Ürün').split(',').first.trim();
          final int novaGroup = (product['nova_group'] as num?)?.toInt() ?? 3;
          final String ingredientsText = product['ingredients_text_tr'] ?? product['ingredients_text'] ?? '';

          final nutriments = product['nutriments'] as Map<String, dynamic>? ?? {};
          final bool hasNutrition = nutriments.containsKey('sugars_100g') ||
              nutriments.containsKey('energy-kcal_100g') ||
              nutriments.containsKey('proteins_100g') ||
              nutriments.containsKey('fat_100g');
          final bool hasIngredients = ingredientsText.trim().length > 5;

          final double sugar = (nutriments['sugars_100g'] as num?)?.toDouble() ?? 12.0;
          final double satFat = (nutriments['saturated-fat_100g'] as num?)?.toDouble() ?? 2.0;
          final double sodium = (nutriments['sodium_100g'] as num?)?.toDouble() ?? 0.2;
          final double fiber = (nutriments['fiber_100g'] as num?)?.toDouble() ?? 1.0;
          final double protein = (nutriments['proteins_100g'] as num?)?.toDouble() ?? 3.0;

          final String lowerName = name.toLowerCase();
          final String lowerIng = ingredientsText.toLowerCase();

          final bool hasENumbers = RegExp(r'\b[Ee][\s\-\.]?\d{3,4}\b').hasMatch(ingredientsText) ||
              lowerIng.contains('glikoz') ||
              lowerIng.contains('fruktoz') ||
              lowerIng.contains('palm') ||
              lowerIng.contains('tatlandırıcı');

          final bool isPureNatural = !hasENumbers &&
              isPureNaturalFoodName(name, ingredientsText: ingredientsText);

          final bool isIncomplete = !hasNutrition && !hasIngredients && !isPureNatural;

          if (isIncomplete) {
            return ProductAnalysisResponse(
              barcode: barcode,
              productName: name,
              brand: brand.isNotEmpty ? brand : 'Doğrulanmamış Ürün',
              organicScore: -1,
              scoreCategory: 'İçerik Bilgisi Eksik',
              novaGroup: 0,
              novaVerdict: 'İçindekiler Bilgisi Eksik (Doğrulanmadı)',
              boycottStatus: 'CLEAR',
              boycottReason: 'Açık gıda veritabanında bu barkodun içindekiler listesi henüz girilmemiş.',
              aiSummary: '$brand üreticisine ait $name. Paketin arkasındaki içindekiler etiketini fotoğraflayarak gerçek puanını öğrenebilir ve topluluğa katkı sağlayabilirsiniz.',
              warnings: ['İçindekiler ve Besin Değerleri Eksik'],
              alternatives: [],
              source: ScanDataSource.onlineCloudWorker,
              statusBadgeText: '⚠️ Doğrulanmamış Ürün: İçerik Bilgisi Eksik',
              isDataIncomplete: true,
            );
          }

          final int adjustedNovaGroup = isPureNatural
              ? (lowerName.contains('zeytinyağ') || lowerName.contains('zeytinyag') ? 2 : 1)
              : novaGroup;

          final scoreResult = OrganicScoreCalculator.calculate(
            riskLevels: hasENumbers ? ['MODERATE'] : ['LOW'],
            sugarGramsPer100g: isPureNatural ? 0.5 : sugar,
            satFatGramsPer100g: isPureNatural ? 1.0 : satFat,
            sodiumGramsPer100g: isPureNatural ? 0.05 : sodium,
            fiberGramsPer100g: fiber,
            proteinGramsPer100g: protein,
            novaGroup: adjustedNovaGroup,
          );

          final boycottEval = await OfflineFallbackManager.getBoycottStatus(
            productName: name,
            brandName: brand,
          );
          final String boycottStatus = boycottEval['status_flag'] ?? 'CLEAR';
          final String boycottReason = boycottEval['reason'] ?? 'Open Food Facts veritabanından canlı doğrulandı.';

          final RecommendationResult recResult = AlternativeRecommendationEngine.getRecommendations(
            currentBarcode: barcode,
            currentProductName: name,
            currentBrand: brand,
            currentScore: scoreResult.overallScore,
            currentBoycottStatus: boycottStatus,
            rawIngredients: ingredientsText,
          );
          final List<Map<String, String>> dynamicAlternatives = recResult.alternatives
              .map((a) => {'name': a.name, 'brand': a.brand, 'reason': a.reason})
              .toList();

          try {
            await DatabaseHelper().saveSnapshot(
              barcode: barcode,
              productName: name,
              brand: brand,
              aiSummaryJson: {
                'organic_score': scoreResult.overallScore,
                'nova_group': adjustedNovaGroup,
                'verdict': scoreResult.novaVerdict,
                'summary': '$brand üreticisine ait $name. ${ingredientsText.isNotEmpty ? "İçindekiler: $ingredientsText" : "Doğrulanmış açık veri kaydı."}',
                'warnings': sugar > 15 ? ['Yüksek Şeker İçeriği (100g)'] : <String>[],
                'alternatives': dynamicAlternatives,
              },
            );
          } catch (e) {
            debugPrint('OpenFoodFactsService.saveSnapshot error ($barcode): $e');
          }

          return ProductAnalysisResponse(
            barcode: barcode,
            productName: name,
            brand: brand.isNotEmpty ? brand : 'Doğrulanmış Marka',
            organicScore: scoreResult.overallScore,
            scoreCategory: scoreResult.ratingCategory,
            novaGroup: adjustedNovaGroup,
            novaVerdict: scoreResult.novaVerdict,
            boycottStatus: boycottStatus,
            boycottReason: boycottReason,
            aiSummary: '$brand üreticisine ait $name. ${ingredientsText.isNotEmpty ? "İçindekiler: $ingredientsText" : "Besin değerleri açık veritabanı ile eşleşti."}',
            warnings: sugar > 15 ? ['Yüksek Şeker İçeriği (100g)'] : [],
            alternatives: dynamicAlternatives,
            source: ScanDataSource.onlineCloudWorker,
            statusBadgeText: '🌐 Canlı Mod: Open Food Facts & Cloud AI Analizi',
            isDataIncomplete: false,
            ingredientsText: ingredientsText,
          );
        }
      }
    } catch (e) {
      debugPrint('OpenFoodFactsService.fetchProductByBarcode error ($barcode): $e');
    }

    return null;
  }
}
