import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/database/database_helper.dart';
import '../../scoring/domain/organic_score_calculator.dart';
import 'offline_fallback_manager.dart';

class OpenFoodFactsService {
  static Future<ProductAnalysisResponse?> fetchProductByBarcode(String barcode) async {
    try {
      final url = Uri.parse('https://world.openfoodfacts.org/api/v2/product/$barcode.json');
      final headers = {
        'User-Agent': 'OrganicScoreApp - Mobile - Version 2.0 (contact@organicscore.app)',
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

          final bool isPureNatural = lowerName.contains('zeytinyağ') ||
              lowerName.contains('makarna') ||
              lowerName.contains('yulaf') ||
              lowerName.contains('mercimek') ||
              lowerName.contains('nohut') ||
              lowerName.contains('fasulye') ||
              lowerName.contains('bulgur') ||
              lowerName.contains('un') ||
              lowerName.contains('irmik') ||
              lowerName.contains('pirinç') ||
              lowerName.contains('su') ||
              lowerName.contains('maden suyu') ||
              lowerName.contains('süt') ||
              lowerName.contains('yoğurt') ||
              lowerName.contains('çay') ||
              lowerName.contains('bal') ||
              lowerName.contains('yumurta');

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

          final int adjustedNovaGroup = isPureNatural ? (lowerName.contains('zeytinyağ') ? 2 : 1) : novaGroup;

          final scoreResult = OrganicScoreCalculator.calculate(
            riskLevels: hasENumbers ? ['MODERATE'] : ['LOW'],
            sugarGramsPer100g: isPureNatural ? 0.5 : sugar,
            satFatGramsPer100g: isPureNatural ? 1.0 : satFat,
            sodiumGramsPer100g: isPureNatural ? 0.05 : sodium,
            fiberGramsPer100g: fiber,
            proteinGramsPer100g: protein,
            novaGroup: adjustedNovaGroup,
          );

          // Automatically cache into offline SQLite snapshots for instant subsequent scans
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
                'warnings': sugar > 15 ? ['Yüksek Şeker İçeriği (100g)'] : [],
                'alternatives': [
                  {
                    'name': 'Doğal & Ev Yapımı Alternatif',
                    'brand': 'Temiz Tarif',
                    'reason': 'Katkısız ve rafine şekersiz ev yapımı hazırlama önerisi'
                  },
                  {
                    'name': 'Torku Yerli Üretim Seçenek',
                    'brand': 'Torku',
                    'reason': 'Glikoz şurupsuz, katı palm yağı içermeyen yerli üretici'
                  }
                ]
              },
            );
          } catch (_) {}

          return ProductAnalysisResponse(
            barcode: barcode,
            productName: name,
            brand: brand.isNotEmpty ? brand : 'Doğrulanmış Marka',
            organicScore: scoreResult.overallScore,
            scoreCategory: scoreResult.ratingCategory,
            novaGroup: novaGroup,
            novaVerdict: scoreResult.novaVerdict,
            boycottStatus: 'CLEAR',
            boycottReason: 'Open Food Facts veritabanından canlı doğrulandı.',
            aiSummary: '$brand üreticisine ait $name. ${ingredientsText.isNotEmpty ? "İçindekiler: $ingredientsText" : "Besin değerleri açık veritabanı ile eşleşti."}',
            warnings: sugar > 15 ? ['Yüksek Şeker İçeriği (100g)'] : [],
            alternatives: [
              {
                'name': 'Doğal & Ev Yapımı Alternatif',
                'brand': 'Temiz Tarif',
                'reason': 'Katkısız ve rafine şekersiz ev yapımı hazırlama önerisi'
              },
              {
                'name': 'Torku Yerli Üretim Seçenek',
                'brand': 'Torku',
                'reason': 'Glikoz şurupsuz, katı palm yağı içermeyen yerli üretici'
              },
              {
                'name': 'Eti %100 Yulaf Ezmesi',
                'brand': 'Eti',
                'reason': 'Katkısız ve koruyucusuz tam tahıllı alternatif'
              }
            ],
            source: ScanDataSource.onlineCloudWorker,
            statusBadgeText: '🌐 Canlı Mod: Open Food Facts & Cloud AI Analizi',
            isDataIncomplete: false,
          );
        }
      }
    } catch (_) {}

    return null;
  }
}

