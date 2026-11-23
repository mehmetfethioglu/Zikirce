import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/services/changelog_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../crowdsource/presentation/crowdsource_dialog.dart';
import '../../family_profiles/domain/family_profile_engine.dart';
import '../../family_profiles/presentation/family_profiles_screen.dart';
import '../../monetization/domain/subscription_service.dart';
import '../../monetization/presentation/paywall_screen.dart';
import '../../network/domain/edge_worker_sync_service.dart';
import '../../network/domain/offline_fallback_manager.dart';
import '../../product/presentation/product_result_screen.dart';
import '../../profile/domain/user_profile_service.dart';
import '../../taklit_tagsis/domain/taklit_tagsis_service.dart';
import '../../taklit_tagsis/presentation/taklit_tagsis_screen.dart';

class ShowcaseProduct {
  final String barcode;
  final String name;
  final String brand;
  final int score;
  final String category;
  final int novaGroup;
  final String boycottStatus;
  final String description;
  final List<String> badges;

  ShowcaseProduct({
    required this.barcode,
    required this.name,
    required this.brand,
    required this.score,
    required this.category,
    required this.novaGroup,
    required this.boycottStatus,
    required this.description,
    required this.badges,
  });
}

class ScannerScreen extends StatefulWidget {
  final bool embeddedInHub;
  final VoidCallback? onOpenArenaTab;
  final VoidCallback? onOpenCharacterTab;

  const ScannerScreen({
    super.key,
    this.embeddedInHub = false,
    this.onOpenArenaTab,
    this.onOpenCharacterTab,
  });

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  FamilyProfile? _activeProfile;
  final TextEditingController _manualBarcodeController =
      TextEditingController();

  List<ShowcaseProduct> _showcaseProducts = [];
  int _selectedFilterIndex = 0; // 0: Temiz (80+), 1: NOVA 1 Doğal, 2: Tüm Ürünler, 3: Riskli (<50)
  bool _isOcrProcessing = false;
  Map<String, int> _dbStats = const {
    'products': 0,
    'e_numbers': 0,
    'taklit_tagsis': 0,
    'boycott_brands': 0,
  };

  @override
  void initState() {
    super.initState();
    _loadActiveProfile();
    _loadShowcaseProducts();
    _loadDatabaseStats();
    EdgeWorkerSyncService.initAutoSyncListener();
    SubscriptionService.instance.initAdMob();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ChangelogService.checkAndShowOnStartup(context);
    });
    Future.delayed(const Duration(seconds: 3), () async {
      try {
        await TaklitTagsisService.syncLatestList();
        if (mounted) _loadDatabaseStats();
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _manualBarcodeController.dispose();
    EdgeWorkerSyncService.dispose();
    super.dispose();
  }

  Future<void> _loadDatabaseStats() async {
    try {
      final stats = await DatabaseHelper().getDatabaseStats();
      if (mounted) {
        setState(() {
          _dbStats = stats;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadShowcaseProducts() async {
    try {
      final Database db = await DatabaseHelper().database;
      final results = await db.query(
        'offline_ai_snapshots',
        columns: ['barcode', 'product_name', 'brand', 'ai_summary_json'],
        limit: 120,
      );

      final List<ShowcaseProduct> list = [];
      for (final row in results) {
        final summary = jsonDecode(row['ai_summary_json'] as String);
        final String name = row['product_name'] as String? ?? 'Ürün';
        final String brand = row['brand'] as String? ?? '';
        final int score = summary['organic_score'] as int? ?? 50;
        final int nova = summary['nova_group'] as int? ?? 3;
        final boycott = await OfflineFallbackManager.getBoycottStatus(
          productName: name,
          brandName: brand,
        );

        final String boycottStatus = boycott['status_flag'] ?? 'CLEAR';
        if (boycottStatus == 'FLAGGED' || boycottStatus == 'CAUTION') {
          continue;
        }

        String cat = 'Orta';
        if (score >= 80) {
          cat = 'Mükemmel';
        } else if (score >= 60) {
          cat = 'İyi';
        } else if (score < 40) {
          cat = 'Zararlı';
        }

        final String desc = summary['summary'] as String? ??
            summary['verdict'] as String? ??
            'İçerik ve besin profili analiz edilmiş ürün.';

        final List<String> badges = [
          nova == 1
              ? 'NOVA 1 Doğal'
              : (nova == 2
                  ? 'NOVA 2 Temel'
                  : (nova == 4 ? 'NOVA 4 Ultra-İşlenmiş' : 'NOVA $nova')),
          'Boykotsuz',
        ];

        list.add(
          ShowcaseProduct(
            barcode: row['barcode'] as String,
            name: name,
            brand: brand.isNotEmpty ? brand : 'Genel Marka',
            score: score,
            category: cat,
            novaGroup: nova,
            boycottStatus: boycottStatus,
            description: desc,
            badges: badges,
          ),
        );
      }

      list.sort((a, b) => b.score.compareTo(a.score));

      if (mounted) {
        setState(() {
          _showcaseProducts = list;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadActiveProfile() async {
    final profile = await FamilyProfileEngine.getActiveProfile();
    if (mounted) {
      setState(() {
        _activeProfile = profile;
      });
    }
  }

  List<ShowcaseProduct> get _filteredShowcaseProducts {
    switch (_selectedFilterIndex) {
      case 0: // Temiz Seçimler (80+)
        return _showcaseProducts.where((p) => p.score >= 80).toList();
      case 1: // Doğal (NOVA 1)
        return _showcaseProducts.where((p) => p.novaGroup == 1).toList();
      case 3: // Dikkat / Düşük Puan (<50)
        return _showcaseProducts.where((p) => p.score < 50).toList();
      default: // Tümü
        return _showcaseProducts;
    }
  }

  void _openCameraScanner() {
    bool isScanning = true;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.82,
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: context.cardBorderColor),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.textSecondaryColor.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Canlı Barkod Tarayıcı',
                    style: TextStyle(
                      color: context.textPrimaryColor,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: context.textSecondaryColor),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  MobileScanner(
                    onDetect: (capture) {
                      if (!isScanning) return;
                      for (final barcode in capture.barcodes) {
                        if (barcode.rawValue != null) {
                          isScanning = false;
                          Navigator.pop(context);
                          _navigateToScanResult(barcode.rawValue!);
                          break;
                        }
                      }
                    },
                  ),
                  Center(
                    child: Container(
                      width: 240,
                      height: 180,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppColors.primaryEmerald,
                          width: 2.5,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _scanIngredientLabelViaOcr(ImageSource source) async {
    setState(() => _isOcrProcessing = true);
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: 85,
      );
      if (image == null) {
        if (mounted) setState(() => _isOcrProcessing = false);
        return;
      }

      final inputImage = InputImage.fromFilePath(image.path);
      final textRecognizer =
          TextRecognizer(script: TextRecognitionScript.latin);
      final RecognizedText recognizedText =
          await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      if (!mounted) return;
      setState(() => _isOcrProcessing = false);

      final String rawText = recognizedText.text.trim();
      if (rawText.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Fotoğrafta okunabilir içindekiler metni tespit edilemedi. Lütfen etiketi yakından çekin.',
            ),
            backgroundColor: AppColors.dangerRed,
          ),
        );
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProductResultScreen(
            barcode: 'OCR-${DateTime.now().millisecondsSinceEpoch % 100000}',
            ingredientsOcrText: rawText,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isOcrProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Etiket okuma hatası: $e'),
          backgroundColor: AppColors.dangerRed,
        ),
      );
    }
  }

  void _showOcrSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: context.cardBorderColor),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'İçindekiler Etiketi OCR Analizi',
              style: TextStyle(
                color: context.textPrimaryColor,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Barkodu veritabanında olmayan ürünlerin "İçindekiler" kısmını fotoğraflayarak anında Helal, E-Kod ve sağlık analizi yapın.',
              style: TextStyle(
                color: context.textSecondaryColor,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _scanIngredientLabelViaOcr(ImageSource.camera);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryEmerald,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.camera_alt_rounded, size: 19),
                    label: const Text(
                      'Kamerayla Çek',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _scanIngredientLabelViaOcr(ImageSource.gallery);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.textPrimaryColor,
                      side: BorderSide(color: context.cardBorderColor),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.photo_library_outlined, size: 19),
                    label: const Text(
                      'Galeriden Seç',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openProductDetails(String barcode) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductResultScreen(
          barcode: barcode,
          ingredientsOcrText: null,
        ),
      ),
    );
  }

  Future<void> _navigateToScanResult(String barcode) async {
    final bool canScan = await SubscriptionService.instance.canScan();
    if (!canScan) {
      if (mounted) {
        PaywallScreen.show(
          context,
          onScanGranted: () => _navigateToScanResult(barcode),
        );
      }
      return;
    }

    await SubscriptionService.instance.consumeScan();
    await UserProfileService.instance.recordScan(barcode: barcode);
    setState(() {});

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProductResultScreen(
            barcode: barcode,
            ingredientsOcrText: null,
          ),
        ),
      );
    }
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return AppColors.primaryEmerald;
    if (score >= 60) return AppColors.primaryMint;
    if (score >= 40) return AppColors.cautionGold;
    return AppColors.dangerRed;
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = context.textPrimaryColor;
    final textSecondary = context.textSecondaryColor;
    final filteredProducts = _filteredShowcaseProducts;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BioMinimalUi.sectionHeader(
            context,
            overline: 'SAĞLIK ASİSTANI & HELAL REHBERİ',
            title: 'Gıda & İçerik Denetimi',
            trailing: GestureDetector(
              onTap: () async {
                if (widget.onOpenCharacterTab != null) {
                  widget.onOpenCharacterTab!();
                } else {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const FamilyProfilesScreen(),
                    ),
                  );
                  _loadActiveProfile();
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryEmerald.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.primaryEmerald.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.verified_user_rounded,
                      size: 14,
                      color: AppColors.primaryEmerald,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _activeProfile?.profileName ?? 'Filtre Ayarla',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // =========================================================================
          // HERO BARCODE & INGREDIENT OCR SCANNER CARD
          // =========================================================================
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BioMinimalUi.cardDecoration(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryEmerald.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.fact_check_outlined,
                        color: AppColors.primaryEmerald,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Barkod veya İçindekiler Analizi',
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'E-kodları, Helal açısından şüpheli katkıları, NOVA işlenme derecesini ve Bakanlık ifşa kayıtlarını anında sorgulayın.',
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Primary Action Row: Camera Barcode + Camera OCR Label
                Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _openCameraScanner,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryEmerald,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(
                            Icons.qr_code_scanner_rounded,
                            size: 20,
                          ),
                          label: const Text(
                            'Barkod Tara',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 5,
                      child: SizedBox(
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed:
                              _isOcrProcessing ? null : _showOcrSourceSheet,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: textPrimary,
                            side: BorderSide(
                              color: AppColors.primaryEmerald
                                  .withValues(alpha: 0.55),
                              width: 1.4,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: _isOcrProcessing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primaryEmerald,
                                  ),
                                )
                              : const Icon(
                                  Icons.document_scanner_outlined,
                                  size: 18,
                                  color: AppColors.primaryEmerald,
                                ),
                          label: const Text(
                            'Etiket Okut (OCR)',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Inline Barcode Input
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _manualBarcodeController,
                        style: TextStyle(color: textPrimary, fontSize: 13.5),
                        decoration: InputDecoration(
                          hintText: 'Barkod numarası girin (örn. 8690504011200)...',
                          hintStyle: TextStyle(
                            color: textSecondary,
                            fontSize: 12.5,
                          ),
                          filled: true,
                          fillColor: context.subtleSurfaceColor,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 11,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onSubmitted: (val) {
                          if (val.trim().isNotEmpty) {
                            _navigateToScanResult(val.trim());
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () {
                        if (_manualBarcodeController.text.trim().isNotEmpty) {
                          _navigateToScanResult(
                            _manualBarcodeController.text.trim(),
                          );
                        }
                      },
                      style: IconButton.styleFrom(
                        backgroundColor: context.subtleSurfaceColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(
                        Icons.arrow_forward_rounded,
                        color: AppColors.primaryEmerald,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // =========================================================================
          // REAL SQLITE DATABASE COUNTERS & QUICK ACCESS STRIP
          // =========================================================================
          Row(
            children: [
              Expanded(
                child: _buildUtilityPill(
                  context,
                  icon: Icons.inventory_2_outlined,
                  label: _dbStats['products']! > 0
                      ? '${_dbStats['products']} Kayıtlı Ürün'
                      : 'Ürün Kataloğu',
                  onTap: () => _openAllProductsModal(context),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildUtilityPill(
                  context,
                  icon: Icons.gavel_rounded,
                  label: _dbStats['taklit_tagsis']! > 0
                      ? '${_dbStats['taklit_tagsis']} Bakanlık İfşa'
                      : 'Bakanlık İfşa',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TaklitTagsisScreen(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildUtilityPill(
                  context,
                  icon: Icons.add_circle_outline_rounded,
                  label: 'Ürün Bildir',
                  onTap: () =>
                      CrowdsourceDialog.showProductContributionModal(context),
                ),
              ),
            ],
          ),

          const SizedBox(height: 22),

          // =========================================================================
          // CLEAN & HALAL DISCOVERY SECTION WITH REAL FILTERS
          // =========================================================================
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Veritabanı Ürün İncelemesi',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              GestureDetector(
                onTap: () => _openAllProductsModal(context),
                child: const Text(
                  'Tümünü Ara',
                  style: TextStyle(
                    color: AppColors.primaryEmerald,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(0, 'Temiz Seçimler (80+)'),
                const SizedBox(width: 8),
                _buildFilterChip(1, 'Doğal (NOVA 1)'),
                const SizedBox(width: 8),
                _buildFilterChip(2, 'Tüm Ürünler'),
                const SizedBox(width: 8),
                _buildFilterChip(3, 'Düşük Puan / Katkılı (<50)'),
              ],
            ),
          ),
          const SizedBox(height: 12),

          if (filteredProducts.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BioMinimalUi.cardDecoration(context),
              child: Text(
                'Bu filtrede ürün bulunamadı.',
                style: TextStyle(color: textSecondary, fontSize: 13),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredProducts.take(12).length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = filteredProducts[index];
                final scoreColor = _getScoreColor(item.score);

                return GestureDetector(
                  onTap: () => _openProductDetails(item.barcode),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BioMinimalUi.cardDecoration(
                      context,
                      radius: 18,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: scoreColor.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: scoreColor.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '${item.score}',
                              style: TextStyle(
                                color: scoreColor,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    item.brand,
                                    style: TextStyle(
                                      color: textSecondary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: context.subtleSurfaceColor,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      item.badges.first,
                                      style: TextStyle(
                                        color: item.novaGroup <= 2
                                            ? AppColors.primaryEmerald
                                            : AppColors.cautionGold,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                item.name,
                                style: TextStyle(
                                  color: textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.description,
                                style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 11.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: textSecondary,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(int index, String label) {
    final bool selected = _selectedFilterIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilterIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primaryEmerald.withValues(alpha: 0.15)
              : context.subtleSurfaceColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? AppColors.primaryEmerald
                : context.cardBorderColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? AppColors.primaryEmerald
                : context.textSecondaryColor,
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _buildUtilityPill(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
        decoration: BioMinimalUi.cardDecoration(context, radius: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: AppColors.primaryEmerald),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.textPrimaryColor,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openAllProductsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _AllProductsCatalogModal(
          onProductSelected: (barcode) {
            Navigator.pop(context);
            _openProductDetails(barcode);
          },
        );
      },
    );
  }
}

class _AllProductsCatalogModal extends StatefulWidget {
  final Function(String barcode) onProductSelected;

  const _AllProductsCatalogModal({required this.onProductSelected});

  @override
  State<_AllProductsCatalogModal> createState() =>
      _AllProductsCatalogModalState();
}

class _AllProductsCatalogModalState extends State<_AllProductsCatalogModal> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _allProducts = [];
  List<Map<String, dynamic>> _filteredProducts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    try {
      final Database db = await DatabaseHelper().database;
      final results = await db.query(
        'offline_ai_snapshots',
        columns: ['barcode', 'product_name', 'brand', 'ai_summary_json'],
        limit: 300,
      );

      final List<Map<String, dynamic>> list = [];
      for (final row in results) {
        final summary = jsonDecode(row['ai_summary_json'] as String);
        final String name = row['product_name'] as String? ?? 'Ürün';
        final String brand = row['brand'] as String? ?? '';
        final boycott = await OfflineFallbackManager.getBoycottStatus(
          productName: name,
          brandName: brand,
        );
        final String boycottStatus = boycott['status_flag'] ?? 'CLEAR';
        if (boycottStatus == 'FLAGGED' || boycottStatus == 'CAUTION') {
          continue;
        }

        list.add({
          'barcode': row['barcode'],
          'product_name': name,
          'brand': brand,
          'organic_score': summary['organic_score'] ?? 50,
          'verdict': summary['verdict'] ?? 'Analiz Edilmiş Ürün',
        });
      }

      list.sort(
        (a, b) =>
            (b['organic_score'] as int).compareTo(a['organic_score'] as int),
      );

      if (mounted) {
        setState(() {
          _allProducts = list;
          _filteredProducts = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filter(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filteredProducts = _allProducts;
      } else {
        _filteredProducts = _allProducts.where((p) {
          final name = (p['product_name'] as String).toLowerCase();
          final brand = (p['brand'] as String).toLowerCase();
          final barcode = (p['barcode'] as String).toLowerCase();
          return name.contains(q) || brand.contains(q) || barcode.contains(q);
        }).toList();
      }
    });
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return AppColors.primaryEmerald;
    if (score >= 60) return AppColors.primaryMint;
    if (score >= 40) return AppColors.cautionGold;
    return AppColors.dangerRed;
  }

  @override
  Widget build(BuildContext context) {
    final surfaceColor = context.surfaceColor;
    final textPrimary = context.textPrimaryColor;
    final textSecondary = context.textSecondaryColor;
    final borderColor = context.cardBorderColor;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
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
                Expanded(
                  child: Text(
                    'Kayıtlı Ürün Veritabanı (${_allProducts.length})',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 18,
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: _filter,
              style: TextStyle(color: textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Ürün adı, marka veya barkod ara...',
                hintStyle: TextStyle(
                  color: textSecondary.withValues(alpha: 0.7),
                  fontSize: 13,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  color: AppColors.primaryEmerald,
                ),
                isDense: true,
                filled: true,
                fillColor: context.subtleSurfaceColor,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryEmerald,
                    ),
                  )
                : _filteredProducts.isEmpty
                    ? Center(
                        child: Text(
                          'Eşleşen ürün bulunamadı.',
                          style: TextStyle(color: textSecondary),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        itemCount: _filteredProducts.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = _filteredProducts[index];
                          final int score = item['organic_score'] as int;
                          return ListTile(
                            onTap: () => widget.onProductSelected(
                              item['barcode'] as String,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            leading: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: _getScoreColor(score)
                                    .withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  '$score',
                                  style: TextStyle(
                                    color: _getScoreColor(score),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                            title: Text(
                              item['product_name'] as String,
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${item['brand']} • ${item['verdict']}',
                              style: TextStyle(
                                color: textSecondary,
                                fontSize: 11.5,
                              ),
                            ),
                            trailing: Icon(
                              Icons.arrow_forward_ios,
                              size: 13,
                              color: textSecondary,
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
