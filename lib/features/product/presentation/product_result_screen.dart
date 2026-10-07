import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../../crowdsource/presentation/crowdsource_dialog.dart';
import '../../crowdsource/presentation/boycott_report_dialog.dart';
import '../../family_profiles/domain/family_profile_engine.dart';
import '../../network/domain/offline_fallback_manager.dart';
import '../../network/domain/open_food_facts_service.dart';
import '../../network/domain/edge_worker_sync_service.dart';
import '../../ocr/domain/ingredient_parser.dart';
import '../../scoring/domain/organic_score_calculator.dart';
import '../../scoring/presentation/transparent_score_card.dart';
import '../../social_share/presentation/social_share_card.dart';
import '../../taklit_tagsis/domain/taklit_tagsis_service.dart';
import '../../taklit_tagsis/presentation/taklit_tagsis_screen.dart';
import '../../taklit_tagsis/presentation/widgets/taklit_tagsis_detail_sheet.dart';
import '../../monetization/domain/subscription_service.dart';
import '../domain/alternative_recommendation_engine.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

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

  Future<void> _analyzeProduct() async {
    setState(() => _isLoading = true);

    _activeProfile = await FamilyProfileEngine.getActiveProfile();

    final bool online = await OfflineFallbackManager.isOnline();

    if (widget.barcode != null) {
      _snapshotResponse = await OfflineFallbackManager.getLocalSnapshot(widget.barcode!, isOnlineMode: online);

      if (_snapshotResponse == null && online) {
        _snapshotResponse = await OpenFoodFactsService.fetchProductByBarcode(widget.barcode!);
      }

      if (_snapshotResponse != null) {
        _productName = _snapshotResponse!.productName;
        _brand = _snapshotResponse!.brand;
        if (_snapshotResponse!.isDataIncomplete || _snapshotResponse!.organicScore < 0) {
          _scoreResult = OrganicScoreResult.incomplete(reason: _snapshotResponse!.novaVerdict);
        } else {
          _scoreResult = OrganicScoreCalculator.fromDirectScore(
            _snapshotResponse!.organicScore,
            _snapshotResponse!.novaGroup,
            verdict: _snapshotResponse!.novaVerdict,
          );
        }
        _ocrResult = await IngredientParser.parseIngredients(_snapshotResponse!.aiSummary);
      } else {
        _productName = 'Ürün (Barkod: ${widget.barcode})';
        _brand = 'Doğrulanmamış Marka';
        _scoreResult = OrganicScoreResult.incomplete(
          reason: 'Bu barkodun içindekiler ve besin bilgisi veritabanında henüz doğrulanmamıştır.',
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
      _ocrResult = await IngredientParser.parseIngredients(widget.ingredientsOcrText!);
      _productName = 'İçindekiler OCR Analizi';
      
      final List<String> risks = _ocrResult!.additives.map((a) => a.riskLevel).toList();
      _scoreResult = OrganicScoreCalculator.calculate(
        riskLevels: risks,
        sugarGramsPer100g: widget.ingredientsOcrText!.toLowerCase().contains('glikoz') ? 22.0 : 5.0,
        satFatGramsPer100g: 6.0,
        sodiumGramsPer100g: 0.5,
        fiberGramsPer100g: 1.0,
        proteinGramsPer100g: 2.0,
        novaGroup: risks.contains('TOXIC') || risks.contains('HIGH') ? 4 : 3,
      );

      if (_activeProfile != null) {
        _profileViolations = FamilyProfileEngine.evaluateViolations(
          activeProfile: _activeProfile!,
          ingredientsText: widget.ingredientsOcrText!,
          detectedRiskLevels: risks,
          sugarPer100g: 22.0,
          sodiumPer100g: 0.5,
        );
      }
    }

    if (_scoreResult != null && _activeProfile != null) {
      final List<String> risks = _ocrResult?.additives.map((a) => a.riskLevel).toList() ?? [];
      final String rawText = widget.ingredientsOcrText ?? _snapshotResponse?.aiSummary ?? '';
      _personalMatch = OrganicScoreCalculator.evaluatePersonalMatch(
        scoreResult: _scoreResult!,
        sensitivity: _activeProfile!.sensitivity,
        profileName: _activeProfile!.profileName,
        rawIngredients: rawText,
        riskLevels: risks,
        activeProfileRestrictions: _activeProfile!.restrictions,
      );
    }

    setState(() => _isLoading = false);
  }

  RecommendationResult _getCategoryRecommendations() {
    return AlternativeRecommendationEngine.getRecommendations(
      currentBarcode: widget.barcode ?? '',
      currentProductName: _productName,
      currentBrand: _brand,
      currentScore: _scoreResult?.overallScore ?? 50,
      currentBoycottStatus: _boycottInfo['status_flag'] ?? 'CLEAR',
      rawIngredients: widget.ingredientsOcrText ?? _snapshotResponse?.aiSummary,
    );
  }

  Color _getScoreColor(int score) {
    if (score < 0) return AppColors.cautionGold;
    if (score >= 80) return AppColors.primaryEmerald;
    if (score >= 60) return AppColors.primaryMint;
    if (score >= 40) return AppColors.cautionGold;
    return AppColors.dangerRed;
  }

  Color _getRiskColor(String riskLevel) {
    switch (riskLevel.toUpperCase()) {
      case 'TOXIC':
        return AppColors.toxicPurple;
      case 'HIGH':
        return AppColors.dangerRed;
      case 'MODERATE':
        return AppColors.cautionGold;
      case 'LOW':
      default:
        return AppColors.primaryEmerald;
    }
  }

  void _navigateToAlternativeProduct(AlternativeProduct alt) {
    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductResultScreen(
          barcode: alt.barcode,
        ),
      ),
    );
  }

  void _showScoreCalculationModal(BuildContext context) {
    if (_scoreResult == null) return;

    final isDark = context.isDarkMode;
    final surfaceColor = context.surfaceColor;
    final textPrimary = context.textPrimaryColor;
    final textSecondary = context.textSecondaryColor;
    final borderColor = context.cardBorderColor;

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
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
                blurRadius: 25,
                spreadRadius: 5,
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: textSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryEmerald.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.analytics, color: AppColors.primaryEmerald, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'OrganicScore™ Algoritması',
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Bilimsel 3 Bileşenli Puanlama Formülü',
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
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryEmerald.withValues(alpha: isDark ? 0.15 : 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primaryEmerald.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Toplam Ürün Puanı', style: TextStyle(color: textSecondary, fontSize: 12)),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              _scoreResult!.overallScore < 0 ? '?' : '${_scoreResult!.overallScore}',
                              style: TextStyle(
                                color: _getScoreColor(_scoreResult!.overallScore),
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(_scoreResult!.overallScore < 0 ? ' (Belirsiz)' : ' / 100', style: TextStyle(color: textSecondary, fontSize: 14)),
                          ],
                        ),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: _getScoreColor(_scoreResult!.overallScore),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _scoreResult!.ratingCategory,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Puanı Oluşturan 3 Ana Bileşen:',
                style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),
              _buildFormulaComponentRow(
                context,
                icon: Icons.science,
                title: 'Katkı Maddesi Hijyeni (%40 Ağırlık)',
                score: _scoreResult!.additiveScore,
                description: 'E-kodları, toksik renklendiriciler ve sentetik koruyucular düşülerek 100 üzerinden hesaplanır.',
                color: AppColors.primaryEmerald,
              ),
              const SizedBox(height: 12),
              _buildFormulaComponentRow(
                context,
                icon: Icons.restaurant,
                title: 'Besin Değerleri Dengesi (%40 Ağırlık)',
                score: _scoreResult!.nutriScore,
                description: 'Aşırı şeker, doymuş yağ ve tuz cezalandırılır; lif ve protein oranları yüksek gıdalar ödüllendirilir.',
                color: AppColors.primaryMint,
              ),
              const SizedBox(height: 12),
              _buildFormulaComponentRow(
                context,
                icon: Icons.factory,
                title: 'NOVA İşleme Düzeyi (%20 Ağırlık)',
                score: _scoreResult!.novaScore,
                description: _scoreResult!.novaVerdict,
                color: AppColors.cautionGold,
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Text(
                  '📐 Formül: (Katkı × 0.40) + (Besin × 0.40) + (NOVA × 0.20)',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(height: 16),
            ],
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
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                '${score.round()} / 100',
                style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold),
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
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: TextStyle(color: textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }

  bool get _isIncomplete {
    if (widget.ingredientsOcrText != null) return false;
    if (_scoreResult != null && _scoreResult!.isDataIncomplete) return true;
    if (_snapshotResponse == null) return true;
    if (_snapshotResponse!.isDataIncomplete || _snapshotResponse!.organicScore < 0) return true;
    final summary = _snapshotResponse!.aiSummary.toLowerCase();
    if (_productName.contains('Barkodlu Ürün') || _brand.contains('Bilinmeyen Marka') || _brand.contains('Doğrulanmamış')) return true;
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
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      final String rawText = recognizedText.text.trim();
      if (rawText.isEmpty || rawText.length < 10) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Fotoğrafta net bir içindekiler metni okunamadı. Lütfen ışığı ayarlayıp tekrar deneyin.'),
              backgroundColor: AppColors.cautionGold,
            ),
          );
        }
        return;
      }

      // Parse ingredients & additives
      _ocrResult = await IngredientParser.parseIngredients(rawText);
      final List<String> risks = _ocrResult!.additives.map((a) => a.riskLevel).toList();

      final lowerText = rawText.toLowerCase();
      final bool hasGlucose = lowerText.contains('glikoz') || lowerText.contains('fruktoz');
      final bool hasPalm = lowerText.contains('palm') || lowerText.contains('margarin');

      _scoreResult = OrganicScoreCalculator.calculate(
        riskLevels: risks,
        sugarGramsPer100g: hasGlucose ? 24.0 : 6.0,
        satFatGramsPer100g: hasPalm ? 12.0 : 3.0,
        sodiumGramsPer100g: 0.3,
        fiberGramsPer100g: 2.0,
        proteinGramsPer100g: 3.0,
        novaGroup: risks.contains('TOXIC') || risks.contains('HIGH') || hasGlucose || hasPalm ? 4 : (risks.isNotEmpty ? 3 : 2),
      );

      // Save to local SQLite offline_ai_snapshots & crowdsourced_queue
      if (widget.barcode != null) {
        final db = await DatabaseHelper().database;
        final int now = DateTime.now().millisecondsSinceEpoch;

        final Map<String, dynamic> snapshotPayload = {
          'organic_score': _scoreResult!.overallScore,
          'nova_group': risks.contains('TOXIC') || risks.contains('HIGH') ? 4 : 3,
          'verdict': _scoreResult!.novaVerdict,
          'summary': '$_brand üreticisine ait $_productName. Gönüllü OCR etiketi ile analiz edildi. İçindekiler: $rawText',
          'warnings': risks.contains('TOXIC') ? ['Zararlı Katkı Maddesi İçerir'] : [],
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

        // Trigger immediate background sync to cloud
        EdgeWorkerSyncService.syncPendingQueue();
      }

      // Reward volunteer user with +24 Hours Ad-Free
      final reward = await SubscriptionService.instance.rewardContribution();

      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(reward.message),
            backgroundColor: AppColors.primaryEmerald,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fotoğraf tarama hatası: $e'), backgroundColor: AppColors.dangerRed),
        );
      }
    }
  }

  Widget _buildEnrichmentCard(BuildContext context) {
    final textPrimary = context.textPrimaryColor;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: AppColors.cautionGold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cautionGold, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: AppColors.cautionGold, size: 24),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'İçerik Doğrulanmadı (Eksik Veri)',
                  style: TextStyle(
                    color: AppColors.cautionGold,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Bu ürünün içindekiler listesi açık veritabanlarında bulunmuyor. Paketin arkasındaki içindekiler etiketini çekerek anında gerçek skorunu öğrenin ve +24 Saat Reklamsız Kullanım kazanın!',
            style: TextStyle(color: textPrimary, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _quickSnapIngredientsAndScore,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.cautionGold,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
              icon: const Icon(Icons.camera_alt_rounded, size: 20),
              label: const Text(
                '📸 İçindekiler Etiketini Tara (+24 Saat Reklamsız)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: TextButton.icon(
              onPressed: () async {
                await CrowdsourceDialog.showProductContributionModal(
                  context,
                  initialBarcode: widget.barcode,
                  prefilledProductName: _productName.contains('Barkodlu Ürün') ? null : _productName,
                  prefilledBrand: _brand.contains('Bilinmeyen Marka') || _brand.contains('Doğrulanmamış') ? null : _brand,
                );
                _analyzeProduct();
              },
              icon: const Icon(Icons.edit_note_rounded, size: 16, color: AppColors.textMuted),
              label: const Text(
                'Detaylı Katkı Formunu Aç',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final surfaceColor = context.surfaceColor;
    final borderColor = context.cardBorderColor;
    final textPrimary = context.textPrimaryColor;
    final textSecondary = context.textSecondaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ürün Analiz Raporu'),
        actions: [
          PopupMenuButton<ThemeMode>(
            icon: const Icon(Icons.palette_outlined, color: AppColors.primaryMint),
            tooltip: 'Tema Seçimi',
            color: surfaceColor,
            onSelected: (ThemeMode mode) {
              ThemeController.instance.setThemeMode(mode);
              setState(() {});
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<ThemeMode>>[
              PopupMenuItem<ThemeMode>(
                value: ThemeMode.system,
                child: Row(
                  children: [
                    Icon(Icons.brightness_auto, color: ThemeController.instance.value == ThemeMode.system ? AppColors.primaryEmerald : textSecondary, size: 20),
                    const SizedBox(width: 10),
                    Text('Cihaz Temasıyla Uyumlu', style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: ThemeController.instance.value == ThemeMode.system ? FontWeight.bold : FontWeight.normal)),
                  ],
                ),
              ),
              PopupMenuItem<ThemeMode>(
                value: ThemeMode.light,
                child: Row(
                  children: [
                    Icon(Icons.light_mode, color: ThemeController.instance.value == ThemeMode.light ? AppColors.primaryEmerald : textSecondary, size: 20),
                    const SizedBox(width: 10),
                    Text('Açık Tema (Light)', style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: ThemeController.instance.value == ThemeMode.light ? FontWeight.bold : FontWeight.normal)),
                  ],
                ),
              ),
              PopupMenuItem<ThemeMode>(
                value: ThemeMode.dark,
                child: Row(
                  children: [
                    Icon(Icons.dark_mode, color: ThemeController.instance.value == ThemeMode.dark ? AppColors.primaryEmerald : textSecondary, size: 20),
                    const SizedBox(width: 10),
                    Text('Koyu Tema (OLED Siyah)', style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: ThemeController.instance.value == ThemeMode.dark ? FontWeight.bold : FontWeight.normal)),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.gavel_outlined, color: AppColors.primaryMint),
            tooltip: 'Taklit & Tağşiş Kara Liste',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TaklitTagsisScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.share, color: AppColors.primaryMint),
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
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryEmerald))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Offline Status Badge
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.bolt, color: AppColors.cautionGold, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _snapshotResponse?.statusBadgeText ?? '⚡ Çevrimdışı Mod: Önceden Senkronize AI Analizi',
                            style: TextStyle(color: textSecondary, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Header Product Title
                  Text(
                    _productName,
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Marka: $_brand',
                    style: TextStyle(color: textSecondary, fontSize: 14),
                  ),
                  const SizedBox(height: 20),

                  // Missing Data / Product Enrichment Banner
                  if (_isIncomplete) _buildEnrichmentCard(context),

                  // 1. OrganicScore Gauge Dial Card (Interactive Tappable Modal Trigger)
                  if (_scoreResult != null) ...[
                    GestureDetector(
                      onTap: () => _showScoreCalculationModal(context),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: borderColor),
                          boxShadow: [
                            BoxShadow(
                              color: _getScoreColor(_scoreResult!.overallScore).withValues(alpha: 0.12),
                              blurRadius: 15,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                // Radial Circular Score Display
                                Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    SizedBox(
                                      width: 100,
                                      height: 100,
                                      child: CircularProgressIndicator(
                                        value: _scoreResult!.overallScore < 0 ? 0.0 : _scoreResult!.overallScore / 100.0,
                                        strokeWidth: 10,
                                        backgroundColor: borderColor,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          _getScoreColor(_scoreResult!.overallScore),
                                        ),
                                      ),
                                    ),
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _scoreResult!.overallScore < 0 ? '?' : '${_scoreResult!.overallScore}',
                                          style: TextStyle(
                                            color: _getScoreColor(_scoreResult!.overallScore),
                                            fontSize: 30,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          _scoreResult!.overallScore < 0 ? 'Belirsiz' : '/ 100',
                                          style: TextStyle(color: textSecondary, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            'OrganicScore',
                                            style: TextStyle(
                                              color: textSecondary,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          const Icon(Icons.info_outline, size: 15, color: AppColors.primaryMint),
                                        ],
                                      ),
                                      Text(
                                        _scoreResult!.ratingCategory,
                                        style: TextStyle(
                                          color: _getScoreColor(_scoreResult!.overallScore),
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        _scoreResult!.novaVerdict,
                                        style: TextStyle(
                                          color: textPrimary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Divider(height: 1, color: borderColor.withValues(alpha: 0.5)),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.touch_app, size: 14, color: AppColors.primaryMint),
                                const SizedBox(width: 6),
                                Text(
                                  'Puan hesaplama detayları için dokunun',
                                  style: TextStyle(color: textSecondary, fontSize: 11, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TransparentScoreCard(
                      scoreResult: _scoreResult!,
                      personalMatch: _personalMatch,
                      activeProfile: _activeProfile,
                      onSensitivityChanged: () {
                        _analyzeProduct();
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 2. Ministry Taklit & Tağşiş High-Priority Red Alert Banner
                  if (_tagsisMatch != null) ...[
                    Builder(
                      builder: (context) {
                        final bool isHazard = _tagsisMatch!.isHealthHazard;
                        final Color alertColor = isHazard ? AppColors.dangerRed : AppColors.cautionGold;

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
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: alertColor.withValues(alpha: isDark ? 0.22 : 0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: alertColor, width: 1.8),
                              boxShadow: [
                                BoxShadow(
                                  color: alertColor.withValues(alpha: 0.12),
                                  blurRadius: 12,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      isHazard ? Icons.dangerous_rounded : Icons.warning_amber_rounded,
                                      color: alertColor,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        isHazard
                                            ? 'SAĞLIĞI TEHLİKEYE DÜŞÜREN GIDA İKAZI!'
                                            : 'TAKLİT VE TAĞŞİŞ HİLESİ İKAZI!',
                                        style: TextStyle(
                                          color: alertColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13.5,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ),
                                    Icon(Icons.arrow_forward_ios, size: 14, color: alertColor),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Bu ürün/marka T.C. Tarım ve Orman Bakanlığı resmi kara listesinde kamuoyuna ilan edilmiştir.',
                                  style: TextStyle(
                                    color: textPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: alertColor.withValues(alpha: isDark ? 0.2 : 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: alertColor.withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    '🚨 Bakanlık Bulgusu: ${_tagsisMatch!.cleanReason}',
                                    style: TextStyle(
                                      color: isDark ? textPrimary : (isHazard ? const Color(0xFF7F1D1D) : const Color(0xFF92400E)),
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    'Bakanlık Raporunu Gör & Paylaş →',
                                    style: TextStyle(
                                      color: alertColor,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],

                  // 3. Boycott & Ethical Status Banner (Theme-Aware Contrast)
                  Builder(
                    builder: (context) {
                      final status = _boycottInfo['status_flag'] ?? 'CLEAR';
                      final isFlagged = status == 'FLAGGED';
                      final isCaution = status == 'CAUTION';

                      final accentColor = isFlagged
                          ? AppColors.dangerRed
                          : (isCaution ? AppColors.cautionGold : AppColors.primaryEmerald);

                      final textColor = isDark
                          ? textPrimary
                          : (isFlagged
                              ? const Color(0xFF991B1B)
                              : (isCaution ? const Color(0xFF92400E) : const Color(0xFF065F46)));

                      final statusTitle = isFlagged
                          ? 'Gazze Boykot Kapsamında (Kırmızı Liste)'
                          : (isCaution
                              ? 'İnceleme Altında / Dolaylı Bağlantı (Sarı Liste)'
                              : 'Boykot Kaydı Yok (Yeşil Liste)');

                      return Container(
                        padding: const EdgeInsets.all(14),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: isDark ? 0.15 : 0.10),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: accentColor.withValues(alpha: isDark ? 0.9 : 0.4)),
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
                                      : (isCaution ? Icons.warning_amber_rounded : Icons.check_circle_rounded),
                                  color: accentColor,
                                  size: 24,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        statusTitle,
                                        style: TextStyle(
                                          color: textColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        _boycottInfo['reason'] ?? '',
                                        style: TextStyle(
                                          color: textColor.withValues(alpha: 0.95),
                                          fontSize: 12,
                                          height: 1.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                InkWell(
                                  onTap: () {
                                    BoycottReportDialog.show(
                                      context,
                                      barcode: widget.barcode ?? '',
                                      productName: _productName,
                                      brandName: _brand,
                                      currentStatus: status,
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.rate_review_outlined,
                                          size: 14,
                                          color: textColor,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Hatalı Durum Bildir / Katkı Sağla',
                                          style: TextStyle(
                                            color: textColor,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            decoration: TextDecoration.underline,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  // 3. Family Multi-Profile High-Priority Red Alert Banner
                  if (_profileViolations.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.dangerRed.withValues(alpha: isDark ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.dangerRed, width: 2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.report_problem, color: AppColors.dangerRed, size: 24),
                              SizedBox(width: 8),
                              Text(
                                'AİLE PROFİLİ KRİTİK UYARISI!',
                                style: TextStyle(
                                  color: AppColors.dangerRed,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ..._profileViolations.map((v) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Text(
                                  '• ${v.title}: ${v.message}',
                                  style: TextStyle(
                                    color: isDark ? textPrimary : const Color(0xFF991B1B),
                                    fontSize: 13,
                                  ),
                                ),
                              )),
                        ],
                      ),
                    ),
                  ],

                  // 4. İçindekiler & Katkı Maddesi Dipnotları (E-Kodları & Koruyucu Analizi)
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryMint.withValues(alpha: 0.05),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primaryEmerald.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.sticky_note_2_outlined, color: AppColors.primaryEmerald, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'İçindekiler & Katkı Maddesi Dipnotları',
                                    style: TextStyle(
                                      color: textPrimary,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'E-kodları, koruyucular ve katkılar hakkında detaylı açıklamalar',
                                    style: TextStyle(color: textSecondary, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            if (_ocrResult != null && _ocrResult!.additives.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.cautionGold.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.cautionGold),
                                ),
                                child: Text(
                                  '${_ocrResult!.additives.length} Dipnot',
                                  style: const TextStyle(
                                    color: AppColors.cautionGold,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        if (_ocrResult == null || _ocrResult!.additives.isEmpty) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.primaryEmerald.withValues(alpha: isDark ? 0.15 : 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.primaryEmerald.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_outline, color: AppColors.primaryEmerald, size: 22),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    '🌱 Bu üründe yüksek riskli E-kodu veya zararlı sentetik koruyucu tespit edilmemiştir.',
                                    style: TextStyle(
                                      color: isDark ? textPrimary : const Color(0xFF065F46),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          ...List.generate(_ocrResult!.additives.length, (index) {
                            final additive = _ocrResult!.additives[index];
                            final riskColor = _getRiskColor(additive.riskLevel);
                            final String riskText = additive.riskLevel == 'TOXIC'
                                ? '🔴 TOKSİK'
                                : (additive.riskLevel == 'HIGH'
                                    ? '⚠️ YÜKSEK RİSK'
                                    : (additive.riskLevel == 'MODERATE' ? '⚡ ORTA RİSK' : '🍏 DÜŞÜK RİSK'));

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: riskColor.withValues(alpha: 0.3)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      // Footnote Index Badge e.g. [1]
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: riskColor.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '[${index + 1}] ${additive.code}',
                                          style: TextStyle(
                                            color: riskColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          additive.name,
                                          style: TextStyle(
                                            color: textPrimary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: riskColor.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: riskColor, width: 0.8),
                                        ),
                                        child: Text(
                                          riskText,
                                          style: TextStyle(
                                            color: riskColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(Icons.label_outlined, size: 13, color: textSecondary),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Kategori: ${additive.category}',
                                        style: TextStyle(color: textSecondary, fontSize: 11, fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  // Footnote Details Box
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: riskColor.withValues(alpha: isDark ? 0.10 : 0.05),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: riskColor.withValues(alpha: 0.2)),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '📌 Dipnot ${index + 1}: ',
                                          style: TextStyle(
                                            color: riskColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            additive.healthHazards.isNotEmpty
                                                ? additive.healthHazards
                                                : 'Bu katkı maddesi hakkında sağlık uyarısı veya dipnot bilgisi bulunmamaktadır.',
                                            style: TextStyle(
                                              color: textPrimary,
                                              fontSize: 11,
                                              height: 1.4,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                  ),

                  // 5. Gemini AI Summary & Recommendation Card (Red tinted if boycotted or score < 50)
                  if (_snapshotResponse != null)
                    Builder(
                      builder: (context) {
                        final bool isLowScoreOrFlagged = (_boycottInfo['status_flag'] == 'FLAGGED') ||
                            (_scoreResult != null && _scoreResult!.overallScore >= 0 && _scoreResult!.overallScore < 50);

                        final aiCardBg = isLowScoreOrFlagged
                            ? AppColors.dangerRed.withValues(alpha: isDark ? 0.15 : 0.08)
                            : surfaceColor;
                        final aiCardBorder = isLowScoreOrFlagged
                            ? AppColors.dangerRed.withValues(alpha: isDark ? 0.8 : 0.4)
                            : borderColor;
                        final aiHeaderColor = isLowScoreOrFlagged
                            ? AppColors.dangerRed
                            : AppColors.primaryMint;

                        return GestureDetector(
                          onTap: () => _showFullAiSummaryModal(context),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 20),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: aiCardBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: aiCardBorder, width: isLowScoreOrFlagged ? 1.5 : 1.0),
                              boxShadow: [
                                BoxShadow(
                                  color: aiHeaderColor.withValues(alpha: 0.08),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      isLowScoreOrFlagged ? Icons.warning_amber_rounded : Icons.auto_awesome,
                                      color: aiHeaderColor,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'AI Gıda Değerlendirmesi',
                                        style: TextStyle(
                                          color: aiHeaderColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                    Icon(Icons.open_in_full, size: 16, color: aiHeaderColor),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  _snapshotResponse!.aiSummary,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isLowScoreOrFlagged
                                        ? (isDark ? textPrimary : const Color(0xFF991B1B))
                                        : textPrimary,
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Tam raporu okumak için dokunun',
                                      style: TextStyle(color: aiHeaderColor, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(Icons.arrow_forward_ios, size: 10, color: aiHeaderColor),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                  // 6. Healthy & Ethical Alternatives (Dynamic Category-Aware Recommendation Engine)
                  Builder(
                    builder: (context) {
                      final RecommendationResult recResult = _getCategoryRecommendations();
                      final alts = recResult.alternatives;
                      if (alts.isEmpty) return const SizedBox.shrink();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Celebratory banner if the scanned product is already optimal
                          if (recResult.isAlreadyOptimal)
                            Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: AppColors.primaryEmerald.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.primaryEmerald.withValues(alpha: 0.35)),
                              ),
                              child: Row(
                                children: [
                                  const Text('🌟', style: TextStyle(fontSize: 22)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Zaten Harika Bir Seçim!',
                                          style: TextStyle(
                                            color: AppColors.primaryEmerald,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Bu ürün yüksek besin kalitesine ve boykotsuz temiz bir içeriğe sahip.',
                                          style: TextStyle(
                                            color: textPrimary,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Section Header
                          Row(
                            children: [
                              Icon(
                                recResult.isAlreadyOptimal ? Icons.verified : Icons.eco,
                                color: AppColors.primaryEmerald,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  recResult.isAlreadyOptimal
                                      ? 'Benzer Temiz Tercihler (${recResult.categoryTitle})'
                                      : 'Sağlıklı & Etik Alternatifler (${recResult.categoryTitle})',
                                  style: TextStyle(
                                    color: textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Horizontal Alternative Cards
                          SizedBox(
                            height: 205,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: alts.length,
                              itemBuilder: (context, index) {
                                final alt = alts[index];
                                final scoreColor = _getScoreColor(alt.score);

                                return GestureDetector(
                                  onTap: () => _navigateToAlternativeProduct(alt),
                                  child: Container(
                                    width: 235,
                                    margin: const EdgeInsets.only(right: 12),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: surfaceColor,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: AppColors.primaryEmerald.withValues(alpha: 0.35),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primaryEmerald.withValues(alpha: 0.07),
                                          blurRadius: 10,
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Header: Brand avatar + Brand name + Score pill
                                        Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 12,
                                              backgroundColor: AppColors.primaryEmerald.withValues(alpha: 0.15),
                                              child: const Icon(Icons.eco, color: AppColors.primaryEmerald, size: 14),
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                alt.brand,
                                                style: const TextStyle(
                                                  color: AppColors.primaryEmerald,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: scoreColor.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.star, size: 11, color: scoreColor),
                                                  const SizedBox(width: 2),
                                                  Text(
                                                    '${alt.score}',
                                                    style: TextStyle(
                                                      color: scoreColor,
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),

                                        // Product Name
                                        Text(
                                          alt.name,
                                          style: TextStyle(
                                            color: textPrimary,
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 6),

                                        // Badges
                                        Wrap(
                                          spacing: 4,
                                          runSpacing: 4,
                                          children: alt.badges.take(2).map((b) => Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                              borderRadius: BorderRadius.circular(5),
                                              border: Border.all(
                                                color: AppColors.primaryEmerald.withValues(alpha: 0.25),
                                              ),
                                            ),
                                            child: Text(
                                              b,
                                              style: TextStyle(
                                                color: textPrimary,
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          )).toList(),
                                        ),
                                        const SizedBox(height: 6),

                                        // Reason
                                        Expanded(
                                          child: Text(
                                            alt.reason,
                                            style: TextStyle(color: textSecondary, fontSize: 10.5, height: 1.25),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),

                                        // Action Button
                                        SizedBox(
                                          width: double.infinity,
                                          height: 28,
                                          child: ElevatedButton(
                                            onPressed: () => _navigateToAlternativeProduct(alt),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppColors.primaryEmerald,
                                              foregroundColor: Colors.white,
                                              padding: EdgeInsets.zero,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                            ),
                                            child: const Text(
                                              'Raporu İncele ➔',
                                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                            ),
                                          ),
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

                  const SizedBox(height: 24),
                  // Crowdsourced Report Trigger Button
                  Center(
                    child: TextButton.icon(
                      onPressed: () async {
                        await CrowdsourceDialog.showProductContributionModal(
                          context,
                          initialBarcode: widget.barcode,
                          prefilledProductName: _productName.contains('Barkodlu Ürün') ? null : _productName,
                          prefilledBrand: _brand.contains('Bilinmeyen Marka') ? null : _brand,
                        );
                        _analyzeProduct();
                      },
                      icon: Icon(Icons.edit_note, color: textSecondary),
                      label: Text(
                        'Marka Sahipliği veya Ürün Bilgisini Düzenle (Topluluk Katkısı)',
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
    final isDark = context.isDarkMode;
    final surfaceColor = context.surfaceColor;
    final textPrimary = context.textPrimaryColor;
    final textSecondary = context.textSecondaryColor;
    final borderColor = context.cardBorderColor;

    final bool isLowScoreOrFlagged = (_boycottInfo['status_flag'] == 'FLAGGED') ||
        (_scoreResult != null && _scoreResult!.overallScore >= 0 && _scoreResult!.overallScore < 50);

    final headerColor = isLowScoreOrFlagged ? AppColors.dangerRed : AppColors.primaryMint;

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
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(
                    isLowScoreOrFlagged ? Icons.warning_amber_rounded : Icons.auto_awesome,
                    color: headerColor,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'AI Gıda Değerlendirmesi Raporu',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
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
                    // Product Header Badge
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: headerColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: headerColor.withValues(alpha: 0.3)),
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
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Marka: ${_snapshotResponse!.brand}',
                                  style: TextStyle(color: textSecondary, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primaryEmerald.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${_snapshotResponse!.organicScore}/100',
                              style: const TextStyle(
                                color: AppColors.primaryEmerald,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    Text(
                      'Tam Biyokimya & İçindekiler Metni',
                      style: TextStyle(
                        color: headerColor,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: borderColor),
                      ),
                      child: Text(
                        _snapshotResponse!.aiSummary.replaceAll(RegExp(r'\.\.\.$'), '.'),
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 14,
                          height: 1.6,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),

                    if (_snapshotResponse!.warnings.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      Text(
                        'Öne Çıkan Sağlık Uvarıları & İkazlar',
                        style: TextStyle(
                          color: AppColors.dangerRed,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._snapshotResponse!.warnings.map((w) => Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.dangerRed.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.dangerRed.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.warning, color: AppColors.dangerRed, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    w,
                                    style: TextStyle(
                                      color: isDark ? textPrimary : const Color(0xFF991B1B),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )),
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
