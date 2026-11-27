import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../../crowdsource/presentation/boycott_report_dialog.dart';
import '../../crowdsource/presentation/crowdsource_dialog.dart';
import '../../family_profiles/domain/family_profile_engine.dart';
import '../../kiler/presentation/widgets/kilerce_product_add_card.dart';
import '../../monetization/domain/subscription_service.dart';
import '../../network/domain/edge_worker_sync_service.dart';
import '../../network/domain/offline_fallback_manager.dart';
import '../../network/domain/turkish_market_resolver_service.dart';
import '../../ocr/domain/ingredient_parser.dart';
import '../../scoring/domain/organic_score_calculator.dart';
import '../../scoring/presentation/transparent_score_card.dart';
import '../../social_share/presentation/social_share_card.dart';
import '../../taklit_tagsis/domain/taklit_tagsis_service.dart';
import '../../taklit_tagsis/presentation/taklit_tagsis_screen.dart';
import '../../taklit_tagsis/presentation/widgets/taklit_tagsis_detail_sheet.dart';
import '../domain/alternative_recommendation_engine.dart';
import 'widgets/market_nutrition_section.dart';

class ProductResultScreen extends StatefulWidget {
  final String? barcode;
  final String? ingredientsOcrText;

  const ProductResultScreen({
    super.key,
    this.barcode,
    this.ingredientsOcrText,
  });

  @override
  State<ProductResultScreen> createState() => _ProductResultScreenState();
}

class _ProductResultScreenState extends State<ProductResultScreen> {
  bool _isLoading = true;
  String _productName = 'Analiz Edilen Ürün';
  String _brand = 'Genel Ürün';
  OrganicScoreResult? _scoreResult;
  PersonalMatchResult? _personalMatch;
  IngredientParseResult? _ocrResult;
  List<ProfileViolation> _profileViolations = [];
  Map<String, String> _boycottInfo = {'status_flag': 'CLEAR', 'reason': 'Temiz'};
  ProductAnalysisResponse? _snapshotResponse;
  FamilyProfile? _activeProfile;
  TaklitTagsisItem? _tagsisMatch;
  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _analyzeProduct();
    _initBannerAd();
  }

  Future<void> _initBannerAd() async {
    final bool isPro = await SubscriptionService.instance.isPremium();
    if (isPro) return;

    _bannerAd = BannerAd(
      adUnitId: SubscriptionService.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) {
            setState(() {
              _isBannerAdLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
    );
    _bannerAd?.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  static double? _lookupNutriment(Map<String, double> map, List<String> keys) {
    for (final String key in keys) {
      final double? val = map[key];
      if (val != null && val.isFinite && val >= 0) {
        return val;
      }
    }
    return null;
  }

  Future<void> _analyzeProduct() async {
    setState(() => _isLoading = true);

    _profileViolations = [];
    _activeProfile = await FamilyProfileEngine.getActiveProfile();

    final bool online = await OfflineFallbackManager.isOnline();

    if (widget.barcode != null) {
      _snapshotResponse = await OfflineFallbackManager.getLocalSnapshot(
        widget.barcode!,
        isOnlineMode: online,
      );

      if (_snapshotResponse == null && online) {
        _snapshotResponse =
            await TurkishMarketResolverService.resolveByBarcode(widget.barcode!);
      }

      if (_snapshotResponse != null) {
        _productName = _snapshotResponse!.productName;
        _brand = _snapshotResponse!.brand;

        final String resolvedIngredients =
            _snapshotResponse!.ingredientsText.isNotEmpty
                ? _snapshotResponse!.ingredientsText
                : _snapshotResponse!.aiSummary;
        _ocrResult = await IngredientParser.parseIngredients(resolvedIngredients);
        final List<String> snapshotRisks =
            _ocrResult?.additives.map((a) => a.riskLevel).toList() ??
                const <String>[];

        final Map<String, double> nutriments = _snapshotResponse!.nutriments;
        final double? sugarVal = _lookupNutriment(
          nutriments,
          const <String>['sugars_g', 'sugars_100g', 'sugar_g'],
        );
        final double? satFatVal = _lookupNutriment(
          nutriments,
          const <String>[
            'saturated_fat_g',
            'saturated-fat_100g',
            'saturated_fat_100g',
          ],
        );
        final double? saltVal = _lookupNutriment(
          nutriments,
          const <String>['salt_g', 'salt_100g'],
        );
        final double? sodiumVal = _lookupNutriment(
              nutriments,
              const <String>['sodium_g', 'sodium_100g'],
            ) ??
            (saltVal != null ? saltVal / 2.5 : null);
        final double? fiberVal = _lookupNutriment(
          nutriments,
          const <String>['fiber_g', 'fiber_100g'],
        );
        final double? proteinVal = _lookupNutriment(
          nutriments,
          const <String>['protein_g', 'proteins_100g', 'protein_100g'],
        );

        if (_snapshotResponse!.isDataIncomplete ||
            (_snapshotResponse!.organicScore < 0 && nutriments.isEmpty)) {
          _scoreResult = OrganicScoreResult.incomplete(
            reason: _snapshotResponse!.novaVerdict,
          );
        } else if (nutriments.isNotEmpty) {
          _scoreResult = OrganicScoreCalculator.calculate(
            riskLevels: snapshotRisks,
            sugarGramsPer100g: sugarVal ?? 0.0,
            satFatGramsPer100g: satFatVal ?? 0.0,
            sodiumGramsPer100g: sodiumVal ?? 0.0,
            fiberGramsPer100g: fiberVal ?? 0.0,
            proteinGramsPer100g: proteinVal ?? 0.0,
            novaGroup: _snapshotResponse!.novaGroup > 0
                ? _snapshotResponse!.novaGroup
                : (snapshotRisks.contains('TOXIC') ||
                        snapshotRisks.contains('HIGH')
                    ? 4
                    : 3),
          );
        } else {
          _scoreResult = OrganicScoreCalculator.fromDirectScore(
            _snapshotResponse!.organicScore,
            _snapshotResponse!.novaGroup,
            verdict: _snapshotResponse!.novaVerdict,
          );
        }

        if (_activeProfile != null && !_snapshotResponse!.isDataIncomplete) {
          _profileViolations = FamilyProfileEngine.evaluateViolations(
            activeProfile: _activeProfile!,
            ingredientsText: resolvedIngredients,
            detectedRiskLevels: snapshotRisks,
            sugarPer100g: sugarVal ?? 0.0,
            sodiumPer100g: sodiumVal ?? 0.0,
          );
        }
      } else {
        _productName = 'Ürün (Barkod: ${widget.barcode})';
        _brand = 'Doğrulanmamış Marka';
        _scoreResult = OrganicScoreResult.incomplete(
          reason:
              'Bu barkodun içindekiler ve besin bilgisi veritabanında henüz doğrulanmamıştır.',
        );
      }

      _boycottInfo = await OfflineFallbackManager.getBoycottStatus(
        productName: _productName,
        brandName: _brand,
      );

      _tagsisMatch = await TaklitTagsisService.checkTaklitTagsisStatus(
        productName: _productName,
        brandName: _brand,
      );
    }

    if (widget.ingredientsOcrText != null) {
      _ocrResult =
          await IngredientParser.parseIngredients(widget.ingredientsOcrText!);
      _productName = 'İçindekiler OCR Analizi';

      final List<String> risks =
          _ocrResult!.additives.map((a) => a.riskLevel).toList();
      final Map<String, double> ocrNutriments =
          _snapshotResponse?.nutriments ?? const <String, double>{};
      final double ocrSugar = _lookupNutriment(
            ocrNutriments,
            const <String>['sugars_g', 'sugars_100g', 'sugar_g'],
          ) ??
          (widget.ingredientsOcrText!.toLowerCase().contains('glikoz')
              ? 22.0
              : 5.0);
      final double ocrSatFat = _lookupNutriment(
            ocrNutriments,
            const <String>[
              'saturated_fat_g',
              'saturated-fat_100g',
              'saturated_fat_100g',
            ],
          ) ??
          6.0;
      final double? ocrSalt = _lookupNutriment(
        ocrNutriments,
        const <String>['salt_g', 'salt_100g'],
      );
      final double ocrSodium = _lookupNutriment(
            ocrNutriments,
            const <String>['sodium_g', 'sodium_100g'],
          ) ??
          (ocrSalt != null ? ocrSalt / 2.5 : 0.5);
      final double ocrFiber = _lookupNutriment(
            ocrNutriments,
            const <String>['fiber_g', 'fiber_100g'],
          ) ??
          1.0;
      final double ocrProtein = _lookupNutriment(
            ocrNutriments,
            const <String>['protein_g', 'proteins_100g', 'protein_100g'],
          ) ??
          2.0;

      _scoreResult = OrganicScoreCalculator.calculate(
        riskLevels: risks,
        sugarGramsPer100g: ocrSugar,
        satFatGramsPer100g: ocrSatFat,
        sodiumGramsPer100g: ocrSodium,
        fiberGramsPer100g: ocrFiber,
        proteinGramsPer100g: ocrProtein,
        novaGroup: risks.contains('TOXIC') || risks.contains('HIGH') ? 4 : 3,
      );

      if (_activeProfile != null) {
        _profileViolations = FamilyProfileEngine.evaluateViolations(
          activeProfile: _activeProfile!,
          ingredientsText: widget.ingredientsOcrText!,
          detectedRiskLevels: risks,
          sugarPer100g: ocrSugar,
          sodiumPer100g: ocrSodium,
        );
      }
    }

    if (_scoreResult != null && _activeProfile != null) {
      final List<String> risks =
          _ocrResult?.additives.map((a) => a.riskLevel).toList() ?? [];
      final String rawText = widget.ingredientsOcrText ??
          (_snapshotResponse != null
              ? (_snapshotResponse!.ingredientsText.isNotEmpty
                  ? _snapshotResponse!.ingredientsText
                  : _snapshotResponse!.aiSummary)
              : '');
      _personalMatch = OrganicScoreCalculator.evaluatePersonalMatch(
        scoreResult: _scoreResult!,
        sensitivity: _activeProfile!.sensitivity,
        profileName: _activeProfile!.profileName,
        rawIngredients: rawText,
        riskLevels: risks,
        activeProfileRestrictions: _activeProfile!.restrictions,
      );
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  RecommendationResult _getCategoryRecommendations() {
    return AlternativeRecommendationEngine.getRecommendations(
      currentBarcode: widget.barcode ?? '',
      currentProductName: _productName,
      currentBrand: _brand,
      currentScore: _scoreResult?.overallScore ?? 50,
      currentBoycottStatus: _boycottInfo['status_flag'] ?? 'CLEAR',
      rawIngredients: widget.ingredientsOcrText ??
          (_snapshotResponse != null
              ? (_snapshotResponse!.ingredientsText.isNotEmpty
                  ? _snapshotResponse!.ingredientsText
                  : _snapshotResponse!.aiSummary)
              : null),
    );
  }

  Color _getScoreColor(BuildContext context, int score) {
    if (score < 0) return context.accentWarm;
    if (score >= 80) return context.accentPrimary;
    if (score >= 60) return context.accentSecondary;
    if (score >= 40) return context.accentWarm;
    return context.accentDanger;
  }

  Color _getScoreTint(BuildContext context, int score) {
    if (score < 0 || (score >= 40 && score < 60)) return context.pastelPeachTint;
    if (score >= 60) return context.pastelSageTint;
    return context.pastelBlushTint;
  }

  Color _getRiskColor(BuildContext context, String riskLevel) {
    switch (riskLevel.toUpperCase()) {
      case 'TOXIC':
        return context.accentLavender;
      case 'HIGH':
        return context.accentDanger;
      case 'MODERATE':
        return context.accentWarm;
      case 'LOW':
      default:
        return context.accentPrimary;
    }
  }

  Color _getRiskTint(BuildContext context, String riskLevel) {
    switch (riskLevel.toUpperCase()) {
      case 'TOXIC':
        return context.pastelLavenderTint;
      case 'HIGH':
        return context.pastelBlushTint;
      case 'MODERATE':
        return context.pastelPeachTint;
      case 'LOW':
      default:
        return context.pastelSageTint;
    }
  }

  String _getRiskLabel(String riskLevel) {
    switch (riskLevel.toUpperCase()) {
      case 'TOXIC':
        return 'Toksik';
      case 'HIGH':
        return 'Yüksek';
      case 'MODERATE':
        return 'Orta';
      case 'LOW':
      default:
        return 'Düşük';
    }
  }

  void _navigateToAlternativeProduct(AlternativeProduct alt) {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductResultScreen(barcode: alt.barcode),
      ),
    );
  }

  void _showScoreCalculationModal(BuildContext context) {
    if (_scoreResult == null) return;

    final surfaceColor = context.surfaceColor;
    final textPrimary = context.textPrimaryColor;
    final textSecondary = context.textSecondaryColor;
    final borderColor = context.cardBorderColor;
    final scoreColor = _getScoreColor(context, _scoreResult!.overallScore);
    final scoreTint = _getScoreTint(context, _scoreResult!.overallScore);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: borderColor),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: textSecondary.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: context.pastelSageTint,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.analytics_outlined,
                        color: context.accentPrimary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'OrganicScore Hesabı',
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '3 bileşenli şeffaf puanlama',
                            style: TextStyle(color: textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: textSecondary),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: scoreTint,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Toplam Puan',
                            style: TextStyle(color: textSecondary, fontSize: 12),
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                _scoreResult!.overallScore < 0
                                    ? '?'
                                    : '${_scoreResult!.overallScore}',
                                style: TextStyle(
                                  color: scoreColor,
                                  fontSize: 30,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                _scoreResult!.overallScore < 0
                                    ? ' (Belirsiz)'
                                    : ' / 100',
                                style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 13.5,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _scoreResult!.ratingCategory,
                          style: TextStyle(
                            color: scoreColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildFormulaComponentRow(
                  context,
                  icon: Icons.science_outlined,
                  title: 'Katkı Maddesi Hijyeni (%40)',
                  score: _scoreResult!.additiveScore,
                  description:
                      'E-kodları ve sentetik koruyucular değerlendirilir.',
                  color: context.accentPrimary,
                ),
                const SizedBox(height: 10),
                _buildFormulaComponentRow(
                  context,
                  icon: Icons.restaurant_outlined,
                  title: 'Besin Değerleri Dengesi (%40)',
                  score: _scoreResult!.nutriScore,
                  description:
                      'Şeker, doymuş yağ, tuz, lif ve protein dengesi ölçülür.',
                  color: context.accentSecondary,
                ),
                const SizedBox(height: 10),
                _buildFormulaComponentRow(
                  context,
                  icon: Icons.factory_outlined,
                  title: 'NOVA İşleme Düzeyi (%20)',
                  score: _scoreResult!.novaScore,
                  description: _scoreResult!.novaVerdict,
                  color: context.accentWarm,
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: context.subtleSurfaceColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Formül: (Katkı × 0.40) + (Besin × 0.40) + (NOVA × 0.20)',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFormulaComponentRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required double score,
    required String description,
    required Color color,
  }) {
    final textPrimary = context.textPrimaryColor;
    final textSecondary = context.textSecondaryColor;
    final borderColor = context.cardBorderColor;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BioMinimalUi.cardDecoration(context, radius: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 17),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${score.round()} / 100',
                style: TextStyle(
                  color: color,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (score / 100.0).clamp(0.0, 1.0),
              backgroundColor: borderColor,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: TextStyle(color: textSecondary, fontSize: 11.5),
          ),
        ],
      ),
    );
  }

  bool get _isIncomplete {
    if (widget.ingredientsOcrText != null) return false;
    if (_scoreResult != null && _scoreResult!.isDataIncomplete) return true;
    if (_snapshotResponse == null) return true;
    if (_snapshotResponse!.isDataIncomplete ||
        _snapshotResponse!.organicScore < 0) {
      return true;
    }
    final summary = _snapshotResponse!.aiSummary.toLowerCase();
    if (_productName.contains('Barkodlu Ürün') ||
        _brand.contains('Bilinmeyen Marka') ||
        _brand.contains('Doğrulanmamış')) {
      return true;
    }
    if (!summary.contains('içindekiler:')) return true;
    return false;
  }

  Future<void> _quickSnapIngredientsAndScore() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (photo == null) return;

      setState(() => _isLoading = true);

      final inputImage = InputImage.fromFilePath(photo.path);
      final textRecognizer =
          TextRecognizer(script: TextRecognitionScript.latin);
      final RecognizedText recognizedText =
          await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      final String rawText = recognizedText.text.trim();
      if (rawText.isEmpty || rawText.length < 10) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Fotoğrafta net bir içindekiler metni okunamadı. Lütfen tekrar deneyin.',
              ),
              backgroundColor: context.accentWarm,
            ),
          );
        }
        return;
      }

      _ocrResult = await IngredientParser.parseIngredients(rawText);
      final List<String> risks =
          _ocrResult!.additives.map((a) => a.riskLevel).toList();

      final lowerText = rawText.toLowerCase();
      final bool hasGlucose =
          lowerText.contains('glikoz') || lowerText.contains('fruktoz');
      final bool hasPalm =
          lowerText.contains('palm') || lowerText.contains('margarin');

      _scoreResult = OrganicScoreCalculator.calculate(
        riskLevels: risks,
        sugarGramsPer100g: hasGlucose ? 24.0 : 6.0,
        satFatGramsPer100g: hasPalm ? 12.0 : 3.0,
        sodiumGramsPer100g: 0.3,
        fiberGramsPer100g: 2.0,
        proteinGramsPer100g: 3.0,
        novaGroup: risks.contains('TOXIC') ||
                risks.contains('HIGH') ||
                hasGlucose ||
                hasPalm
            ? 4
            : (risks.isNotEmpty ? 3 : 2),
      );

      if (widget.barcode != null) {
        final db = await DatabaseHelper().database;
        final int now = DateTime.now().millisecondsSinceEpoch;

        final Map<String, dynamic> snapshotPayload = {
          'organic_score': _scoreResult!.overallScore,
          'nova_group':
              risks.contains('TOXIC') || risks.contains('HIGH') ? 4 : 3,
          'verdict': _scoreResult!.novaVerdict,
          'summary':
              '$_brand üreticisine ait $_productName. Gönüllü OCR etiketi ile analiz edildi. İçindekiler: $rawText',
          'warnings':
              risks.contains('TOXIC') ? ['Zararlı Katkı Maddesi İçerir'] : [],
          'alternatives': [],
        };

        await db.insert('offline_ai_snapshots', {
          'barcode': widget.barcode!,
          'product_name': _productName,
          'brand': _brand,
          'ai_summary_json': jsonEncode(snapshotPayload),
          'synced_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);

        await db.insert('crowdsourced_queue', {
          'type': 'ALTERNATIVE_SUGGESTION',
          'barcode': widget.barcode!,
          'payload_json': jsonEncode({
            'product_name': _productName,
            'brand': _brand,
            'ingredients_text': rawText,
            'organic_score': _scoreResult!.overallScore,
            'submitted_at': now,
          }),
          'status': 'PENDING',
        });

        EdgeWorkerSyncService.syncPendingQueue();
      }

      final reward = await SubscriptionService.instance.rewardContribution();

      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(reward.message),
            backgroundColor: context.accentPrimary,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fotoğraf tarama hatası: $e'),
            backgroundColor: context.accentDanger,
          ),
        );
      }
    }
  }

  Widget _buildEnrichmentCard(BuildContext context) {
    final textPrimary = context.textPrimaryColor;
    final textSecondary = context.textSecondaryColor;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BioMinimalUi.cardDecoration(
        context,
        fillColor: context.pastelPeachTint,
        accentBorder: context.accentWarm.withValues(alpha: 0.35),
        radius: 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: context.accentWarm,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'İçerik Bilgisi Eksik',
                  style: TextStyle(
                    color: context.accentWarm,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Etiketin arkasını çekerek skoru anında hesaplayın ve 24 saat reklamsız kullanım kazanın.',
            style: TextStyle(color: textPrimary, fontSize: 12.5, height: 1.35),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _quickSnapIngredientsAndScore,
              style: ElevatedButton.styleFrom(
                backgroundColor: context.accentWarm,
                foregroundColor: context.onAccentPrimary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.camera_alt_rounded, size: 18),
              label: const Text(
                'İçindekiler Etiketini Tara (+24s Reklamsız)',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: TextButton.icon(
              onPressed: () async {
                await CrowdsourceDialog.showProductContributionModal(
                  context,
                  initialBarcode: widget.barcode,
                  prefilledProductName:
                      _productName.contains('Barkodlu Ürün')
                          ? null
                          : _productName,
                  prefilledBrand: _brand.contains('Bilinmeyen Marka') ||
                          _brand.contains('Doğrulanmamış')
                      ? null
                      : _brand,
                );
                _analyzeProduct();
              },
              icon: Icon(Icons.edit_note_rounded, size: 16, color: textSecondary),
              label: Text(
                'Katkı Formunu Aç',
                style: TextStyle(color: textSecondary, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final surfaceColor = context.surfaceColor;
    final textPrimary = context.textPrimaryColor;
    final textSecondary = context.textSecondaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ürün Analizi'),
        actions: [
          IconButton(
            icon: Icon(Icons.gavel_outlined, color: textPrimary),
            tooltip: 'Taklit & Tağşiş Kara Liste',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TaklitTagsisScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.share_outlined, color: textPrimary),
            tooltip: 'Paylaş',
            onPressed: () {
              if (_scoreResult != null) {
                SocialShareCard.showShareModal(
                  context,
                  productName: _productName,
                  organicScore: _scoreResult!.overallScore,
                  verdict: _scoreResult!.ratingCategory,
                  hazardsCount: _ocrResult?.additives.length ?? 0,
                );
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: context.accentPrimary),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Clean Product Header
                  Text(
                    _brand,
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _productName,
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Missing Data Banner
                  if (_isIncomplete) _buildEnrichmentCard(context),

                  // 2. Pastel Hero Score Card
                  if (_scoreResult != null) ...[
                    GestureDetector(
                      onTap: () => _showScoreCalculationModal(context),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BioMinimalUi.cardDecoration(
                          context,
                          fillColor: _getScoreTint(
                            context,
                            _scoreResult!.overallScore,
                          ),
                          accentBorder: _getScoreColor(
                            context,
                            _scoreResult!.overallScore,
                          ).withValues(alpha: 0.25),
                          radius: 24,
                        ),
                        child: Row(
                          children: [
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: 76,
                                  height: 76,
                                  child: CircularProgressIndicator(
                                    value: _scoreResult!.overallScore < 0
                                        ? 0.0
                                        : _scoreResult!.overallScore / 100.0,
                                    strokeWidth: 7,
                                    strokeCap: StrokeCap.round,
                                    backgroundColor: surfaceColor,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      _getScoreColor(
                                        context,
                                        _scoreResult!.overallScore,
                                      ),
                                    ),
                                  ),
                                ),
                                Text(
                                  _scoreResult!.overallScore < 0
                                      ? '?'
                                      : '${_scoreResult!.overallScore}',
                                  style: TextStyle(
                                    color: _getScoreColor(
                                      context,
                                      _scoreResult!.overallScore,
                                    ),
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _scoreResult!.ratingCategory,
                                    style: TextStyle(
                                      color: _getScoreColor(
                                        context,
                                        _scoreResult!.overallScore,
                                      ),
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _scoreResult!.novaVerdict,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: textPrimary,
                                      fontSize: 12.5,
                                      height: 1.35,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Skor detayları ›',
                                    style: TextStyle(
                                      color: _getScoreColor(
                                        context,
                                        _scoreResult!.overallScore,
                                      ),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    KilerceProductAddCard(
                      barcode: widget.barcode,
                      productName: _productName,
                      brand: _brand,
                      healthScore: _scoreResult!.overallScore,
                      netQuantity: _snapshotResponse?.netQuantity,
                      marketChains:
                          _snapshotResponse?.marketChains ?? const [],
                    ),
                    if (_snapshotResponse != null &&
                        (_snapshotResponse!.nutriments.isNotEmpty ||
                            _snapshotResponse!.ingredientsText
                                .trim()
                                .isNotEmpty ||
                            _snapshotResponse!.marketChains.isNotEmpty ||
                            _snapshotResponse!.allergens.isNotEmpty ||
                            (_snapshotResponse!.netQuantity?.trim().isNotEmpty ??
                                false) ||
                            (_snapshotResponse!.legalProducer
                                    ?.trim()
                                    .isNotEmpty ??
                                false) ||
                            (_snapshotResponse!.referencePriceTry != null &&
                                _snapshotResponse!.referencePriceTry! > 0)))
                      MarketNutritionSection(
                        nutriments: _snapshotResponse!.nutriments,
                        ingredientsText: _snapshotResponse!.ingredientsText,
                        marketChains: _snapshotResponse!.marketChains,
                        allergens: _snapshotResponse!.allergens,
                        netQuantity: _snapshotResponse!.netQuantity,
                        legalProducer: _snapshotResponse!.legalProducer,
                        referencePriceTry:
                            _snapshotResponse!.referencePriceTry,
                      ),
                    Semantics(
                      header: true,
                      label:
                          '$_brand $_productName analiz skoru ${_scoreResult!.overallScore}',
                      child: TransparentScoreCard(
                        scoreResult: _scoreResult!,
                        personalMatch: _personalMatch,
                        activeProfile: _activeProfile,
                        onSensitivityChanged: _analyzeProduct,
                      ),
                    ),
                  ],

                  // 3. Ministry Taklit & Tağşiş Alert
                  if (_tagsisMatch != null) ...[
                    Builder(
                      builder: (context) {
                        final bool isHazard = _tagsisMatch!.isHealthHazard;
                        final Color alertColor = isHazard
                            ? context.accentDanger
                            : context.accentWarm;
                        final Color alertTint = isHazard
                            ? context.pastelBlushTint
                            : context.pastelPeachTint;

                        return GestureDetector(
                          onTap: () {
                            final group = TaklitTagsisBrandGroup(
                              brandName: _tagsisMatch!.brandName,
                              companyName: _tagsisMatch!.companyName,
                              primaryCategory: _tagsisMatch!.category,
                              hasHealthHazard: isHazard,
                              uniqueReasons: [_tagsisMatch!.cleanReason],
                              products: [_tagsisMatch!],
                              latestAnnouncedAt: _tagsisMatch!.announcedAt,
                            );
                            TaklitTagsisDetailSheet.show(context, group);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            margin: const EdgeInsets.only(bottom: 14),
                            decoration: BioMinimalUi.cardDecoration(
                              context,
                              fillColor: alertTint,
                              accentBorder: alertColor.withValues(alpha: 0.4),
                              radius: 18,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.gpp_maybe_rounded,
                                      color: alertColor,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        isHazard
                                            ? 'Sağlığı Tehlikeye Düşüren Gıda İkazı'
                                            : 'Taklit ve Tağşiş İkazı',
                                        style: TextStyle(
                                          color: alertColor,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13.5,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      size: 18,
                                      color: alertColor,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Bakanlık Bulgusu: ${_tagsisMatch!.cleanReason}',
                                  style: TextStyle(
                                    color: textPrimary,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Raporu gör ›',
                                  style: TextStyle(
                                    color: alertColor,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],

                  // 4. Boycott & Ethical Status
                  Builder(
                    builder: (context) {
                      final status = _boycottInfo['status_flag'] ?? 'CLEAR';
                      final isFlagged = status == 'FLAGGED';
                      final isCaution = status == 'CAUTION';

                      if (!isFlagged && !isCaution) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: context.pastelSageTint,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_circle_outline_rounded,
                                color: context.accentPrimary,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Boykot kaydı yok',
                                  style: TextStyle(
                                    color: textPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  BoycottReportDialog.show(
                                    context,
                                    barcode: widget.barcode ?? '',
                                    productName: _productName,
                                    brandName: _brand,
                                    currentStatus: status,
                                  );
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: context.accentPrimary,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text(
                                  'Bildir',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      final accentColor = isFlagged
                          ? context.accentDanger
                          : context.accentWarm;
                      final tintColor = isFlagged
                          ? context.pastelBlushTint
                          : context.pastelPeachTint;
                      final statusTitle = isFlagged
                          ? 'Boykot Kapsamında'
                          : 'İnceleme Altında / Dolaylı Bağlantı';

                      return Container(
                        padding: const EdgeInsets.all(14),
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BioMinimalUi.cardDecoration(
                          context,
                          fillColor: tintColor,
                          accentBorder: accentColor.withValues(alpha: 0.38),
                          radius: 16,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  isFlagged
                                      ? Icons.flag_rounded
                                      : Icons.warning_amber_rounded,
                                  color: accentColor,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        statusTitle,
                                        style: TextStyle(
                                          color: accentColor,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        _boycottInfo['reason'] ?? '',
                                        style: TextStyle(
                                          color: textPrimary,
                                          fontSize: 12,
                                          height: 1.35,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {
                                  BoycottReportDialog.show(
                                    context,
                                    barcode: widget.barcode ?? '',
                                    productName: _productName,
                                    brandName: _brand,
                                    currentStatus: status,
                                  );
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: accentColor,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text(
                                  'Hatalı durum bildir',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  // 5. Family Profile Violations
                  if (_profileViolations.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BioMinimalUi.cardDecoration(
                        context,
                        fillColor: context.pastelBlushTint,
                        accentBorder:
                            context.accentDanger.withValues(alpha: 0.4),
                        radius: 16,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.report_problem_rounded,
                                color: context.accentDanger,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Aile Profili Uyarısı',
                                style: TextStyle(
                                  color: context.accentDanger,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ..._profileViolations.map(
                            (v) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Text(
                                '• ${v.title}: ${v.message}',
                                style: TextStyle(
                                  color: textPrimary,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // 6. Clean Additives Card
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(16),
                    decoration: BioMinimalUi.cardDecoration(context, radius: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Katkı Maddeleri',
                                style: TextStyle(
                                  color: textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (_ocrResult != null &&
                                _ocrResult!.additives.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: context.pastelPeachTint,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${_ocrResult!.additives.length} madde',
                                  style: TextStyle(
                                    color: context.accentWarm,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_ocrResult == null || _ocrResult!.additives.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 11,
                            ),
                            decoration: BoxDecoration(
                              color: context.pastelSageTint,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_circle_outline_rounded,
                                  color: context.accentPrimary,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Riskli katkı maddesi tespit edilmedi',
                                    style: TextStyle(
                                      color: textPrimary,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          ...List.generate(_ocrResult!.additives.length,
                              (index) {
                            final additive = _ocrResult!.additives[index];
                            final riskColor =
                                _getRiskColor(context, additive.riskLevel);
                            final riskTint =
                                _getRiskTint(context, additive.riskLevel);
                            final riskLabel = _getRiskLabel(additive.riskLevel);

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (index > 0) const Divider(height: 20),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: riskTint,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        additive.code,
                                        style: TextStyle(
                                          color: riskColor,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 11.5,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        additive.name,
                                        style: TextStyle(
                                          color: textPrimary,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: riskTint,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        riskLabel,
                                        style: TextStyle(
                                          color: riskColor,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 10.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  additive.healthHazards.isNotEmpty
                                      ? additive.healthHazards
                                      : 'Kategori: ${additive.category}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: textSecondary,
                                    fontSize: 12,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            );
                          }),
                      ],
                    ),
                  ),

                  // 7. AI Summary Card
                  if (_snapshotResponse != null)
                    Builder(
                      builder: (context) {
                        final bool isLowScoreOrFlagged =
                            (_boycottInfo['status_flag'] == 'FLAGGED') ||
                                (_scoreResult != null &&
                                    _scoreResult!.overallScore >= 0 &&
                                    _scoreResult!.overallScore < 50);

                        final aiHeaderColor = isLowScoreOrFlagged
                            ? context.accentDanger
                            : context.accentSecondary;

                        return GestureDetector(
                          onTap: () => _showFullAiSummaryModal(context),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(16),
                            decoration: BioMinimalUi.cardDecoration(
                              context,
                              fillColor: isLowScoreOrFlagged
                                  ? context.pastelBlushTint
                                  : surfaceColor,
                              accentBorder: isLowScoreOrFlagged
                                  ? context.accentDanger.withValues(alpha: 0.38)
                                  : null,
                              radius: 20,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      isLowScoreOrFlagged
                                          ? Icons.warning_amber_rounded
                                          : Icons.auto_awesome_rounded,
                                      color: aiHeaderColor,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Özet Değerlendirme',
                                        style: TextStyle(
                                          color: aiHeaderColor,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      Icons.open_in_full_rounded,
                                      size: 15,
                                      color: aiHeaderColor,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _snapshotResponse!.aiSummary,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: textPrimary,
                                    fontSize: 12.5,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    'Devamını oku ›',
                                    style: TextStyle(
                                      color: aiHeaderColor,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                  // 8. Healthy Alternatives Carousel
                  Builder(
                    builder: (context) {
                      final RecommendationResult recResult =
                          _getCategoryRecommendations();
                      final alts = recResult.alternatives;
                      if (alts.isEmpty) return const SizedBox.shrink();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            recResult.isAlreadyOptimal
                                ? 'Benzer Temiz Tercihler'
                                : 'Sağlıklı Alternatifler',
                            style: TextStyle(
                              color: textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 15.5,
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 148,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: alts.length,
                              itemBuilder: (context, index) {
                                final alt = alts[index];
                                final scoreColor =
                                    _getScoreColor(context, alt.score);
                                final scoreTint =
                                    _getScoreTint(context, alt.score);

                                return GestureDetector(
                                  onTap: () =>
                                      _navigateToAlternativeProduct(alt),
                                  child: Container(
                                    width: 210,
                                    margin: const EdgeInsets.only(right: 10),
                                    padding: const EdgeInsets.all(13),
                                    decoration: BioMinimalUi.cardDecoration(
                                      context,
                                      radius: 18,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                alt.brand,
                                                style: TextStyle(
                                                  color: context.accentPrimary,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 7,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: scoreTint,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                '${alt.score}',
                                                style: TextStyle(
                                                  color: scoreColor,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          alt.name,
                                          style: TextStyle(
                                            color: textPrimary,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            height: 1.2,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 5),
                                        Expanded(
                                          child: Text(
                                            alt.reason,
                                            style: TextStyle(
                                              color: textSecondary,
                                              fontSize: 11,
                                              height: 1.25,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (alt.badges.isNotEmpty)
                                          Wrap(
                                            spacing: 4,
                                            runSpacing: 4,
                                            children: alt.badges
                                                .take(2)
                                                .map(
                                                  (b) => Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: context
                                                          .subtleSurfaceColor,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                        6,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      b,
                                                      style: TextStyle(
                                                        color: textSecondary,
                                                        fontSize: 9.5,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                )
                                                .toList(),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 18),
                  Center(
                    child: TextButton.icon(
                      onPressed: () async {
                        await CrowdsourceDialog.showProductContributionModal(
                          context,
                          initialBarcode: widget.barcode,
                          prefilledProductName:
                              _productName.contains('Barkodlu Ürün')
                                  ? null
                                  : _productName,
                          prefilledBrand: _brand.contains('Bilinmeyen Marka')
                              ? null
                              : _brand,
                        );
                        _analyzeProduct();
                      },
                      icon: Icon(Icons.edit_note, color: textSecondary),
                      label: Text(
                        'Ürün Bilgisini Düzenle',
                        style: TextStyle(color: textSecondary, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: (_isBannerAdLoaded && _bannerAd != null)
          ? Container(
              alignment: Alignment.center,
              width: _bannerAd!.size.width.toDouble(),
              height: _bannerAd!.size.height.toDouble(),
              child: AdWidget(ad: _bannerAd!),
            )
          : null,
    );
  }

  void _showFullAiSummaryModal(BuildContext context) {
    if (_snapshotResponse == null) return;
    final surfaceColor = context.surfaceColor;
    final textPrimary = context.textPrimaryColor;
    final textSecondary = context.textSecondaryColor;
    final borderColor = context.cardBorderColor;

    final bool isLowScoreOrFlagged =
        (_boycottInfo['status_flag'] == 'FLAGGED') ||
            (_scoreResult != null &&
                _scoreResult!.overallScore >= 0 &&
                _scoreResult!.overallScore < 50);

    final headerColor =
        isLowScoreOrFlagged ? context.accentDanger : context.accentSecondary;
    final headerTint = isLowScoreOrFlagged
        ? context.pastelBlushTint
        : context.pastelSageTint;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.80,
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: textSecondary.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(
                    isLowScoreOrFlagged
                        ? Icons.warning_amber_rounded
                        : Icons.auto_awesome_rounded,
                    color: headerColor,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Özet Değerlendirme Raporu',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: headerTint,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _snapshotResponse!.productName,
                                  style: TextStyle(
                                    color: textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _snapshotResponse!.brand,
                                  style: TextStyle(
                                    color: textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: surfaceColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${_snapshotResponse!.organicScore}/100',
                              style: TextStyle(
                                color: headerColor,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'İçerik & Biyokimya Özeti',
                      style: TextStyle(
                        color: headerColor,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: context.subtleSurfaceColor,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        _snapshotResponse!.aiSummary
                            .replaceAll(RegExp(r'\.\.\.$'), '.'),
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 13.5,
                          height: 1.55,
                        ),
                      ),
                    ),
                    if (_snapshotResponse!.warnings.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Öne Çıkan Uyarılar',
                        style: TextStyle(
                          color: context.accentDanger,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._snapshotResponse!.warnings.map(
                        (w) => Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: context.pastelBlushTint,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: context.accentDanger,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  w,
                                  style: TextStyle(
                                    color: textPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
