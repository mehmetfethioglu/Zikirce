import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
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
import '../../ocr/domain/cloud_vision_ocr_service.dart';
import '../../product/presentation/product_result_screen.dart';
import '../../profile/domain/user_profile_service.dart';
import '../../taklit_tagsis/domain/taklit_tagsis_service.dart';
import '../../taklit_tagsis/presentation/taklit_tagsis_screen.dart';
import 'widgets/scanner_showcase_widgets.dart';

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
  Timer? _tagsisSyncTimer;

  List<ShowcaseProduct> _showcaseProducts = [];
  int _selectedFilterIndex = 0; // 0: Temiz 80+, 1: Doğal, 2: Tümü, 3: Riskli
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
    _tagsisSyncTimer = Timer(const Duration(seconds: 3), () async {
      try {
        await TaklitTagsisService.syncLatestList();
        if (mounted) _loadDatabaseStats();
      } catch (e) {
        debugPrint('ScannerScreen tagsis sync note: $e');
      }
    });
  }

  @override
  void dispose() {
    _tagsisSyncTimer?.cancel();
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
    } catch (e) {
      debugPrint('ScannerScreen._loadDatabaseStats error: $e');
    }
  }

  Future<void> _loadShowcaseProducts() async {
    try {
      final Database db = await DatabaseHelper().database;
      final boycottRows = await db.query('boycott_brands');
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
        final boycott = OfflineFallbackManager.evaluateBoycottStatus(
          productName: name,
          brandName: brand,
          boycottBrands: boycottRows,
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
    } catch (e) {
      debugPrint('ScannerScreen._loadShowcaseProducts error: $e');
    }
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
      case 0: // Temiz 80+
        return _showcaseProducts.where((p) => p.score >= 80).toList();
      case 1: // Doğal (NOVA 1)
        return _showcaseProducts.where((p) => p.novaGroup == 1).toList();
      case 3: // Riskli (<50)
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
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: context.textSecondaryColor.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 10),
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
                          color: context.accentPrimary,
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
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 82,
      );
      if (image == null) {
        if (mounted) setState(() => _isOcrProcessing = false);
        return;
      }

      String rawText = '';
      try {
        final Uint8List bytes = await image.readAsBytes();
        final cloudRes = await CloudVisionOcrService.instance
            .analyzeProductLabelBytes(bytes, mode: 'INGREDIENTS');
        if (cloudRes != null && cloudRes.ingredientsText.isNotEmpty) {
          rawText = cloudRes.ingredientsText.trim();
        }
      } catch (e) {
        debugPrint('ScannerScreen cloud OCR fallback note: $e');
      }

      if (rawText.isEmpty) {
        final inputImage = InputImage.fromFilePath(image.path);
        final textRecognizer =
            TextRecognizer(script: TextRecognitionScript.latin);
        try {
          final RecognizedText recognizedText =
              await textRecognizer.processImage(inputImage);
          rawText = recognizedText.text.trim();
        } finally {
          await textRecognizer.close();
        }
      }

      if (!mounted) return;
      setState(() => _isOcrProcessing = false);

      if (rawText.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Fotoğrafta okunabilir içindekiler metni tespit edilemedi.',
            ),
            backgroundColor: context.accentDanger,
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
          backgroundColor: context.accentDanger,
        ),
      );
    }
  }

  void _showOcrSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: context.cardBorderColor),
        ),
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
                    color: context.textSecondaryColor.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Etiket OCR Analizi',
                style: TextStyle(
                  color: context.textPrimaryColor,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'İçindekiler kısmını fotoğraflayarak anında katkı ve skor analizi yapın.',
                style: TextStyle(
                  color: context.textSecondaryColor,
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _scanIngredientLabelViaOcr(ImageSource.camera);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.accentPrimary,
                        foregroundColor: context.onAccentPrimary,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.camera_alt_rounded, size: 18),
                      label: const Text(
                        'Kamerayla Çek',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
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
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      label: const Text(
                        'Galeriden Seç',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
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
    if (!mounted) return;
    setState(() {});

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

  Color _getScoreColor(BuildContext context, int score) {
    if (score >= 80) return context.accentPrimary;
    if (score >= 60) return context.accentSecondary;
    if (score >= 40) return context.accentWarm;
    return context.accentDanger;
  }

  void _submitManualBarcode() {
    final val = _manualBarcodeController.text.trim();
    if (val.isNotEmpty) {
      _navigateToScanResult(val);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = context.textPrimaryColor;
    final textSecondary = context.textSecondaryColor;
    final filteredProducts = _filteredShowcaseProducts;

    final String catalogLabel = _dbStats['products']! > 0
        ? 'Katalog · ${_dbStats['products']}'
        : 'Katalog';
    final String tagsisLabel = _dbStats['taklit_tagsis']! > 0
        ? 'İfşa · ${_dbStats['taklit_tagsis']}'
        : 'İfşa Listesi';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Clean Minimal Header
          Row(
            children: [
              Expanded(
                child: Text(
                  'Barkod Analiz',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
              GestureDetector(
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
                    color: context.pastelSageTint,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: context.accentPrimary.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.verified_user_outlined,
                        size: 14,
                        color: context.accentPrimary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _activeProfile?.profileName ?? 'Profil',
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 2. Modern Pastel Hero Scan Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.pastelSageTint,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: context.accentPrimary.withValues(alpha: 0.22),
              ),
            ),
            child: Column(
              children: [
                Semantics(
                  button: true,
                  label: 'Kamerayla ürün barkodu tara',
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _openCameraScanner,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.accentPrimary,
                        foregroundColor: context.onAccentPrimary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.qr_code_scanner_rounded, size: 22),
                      label: const Text(
                        'Barkod Tara',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _manualBarcodeController,
                        style: TextStyle(color: textPrimary, fontSize: 13.5),
                        decoration: InputDecoration(
                          hintText: 'Barkod no gir...',
                          hintStyle: TextStyle(
                            color: textSecondary,
                            fontSize: 12.5,
                          ),
                          filled: true,
                          fillColor: context.surfaceColor,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: context.cardBorderColor,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: context.cardBorderColor,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: context.accentPrimary,
                            ),
                          ),
                          suffixIcon: IconButton(
                            onPressed: _submitManualBarcode,
                            icon: Icon(
                              Icons.arrow_forward_rounded,
                              color: context.accentPrimary,
                              size: 20,
                            ),
                          ),
                        ),
                        onSubmitted: (_) => _submitManualBarcode(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Semantics(
                      button: true,
                      label: 'Ürün içindekiler etiketini kamera veya galeriden oku',
                      child: SizedBox(
                        height: 46,
                        child: OutlinedButton.icon(
                          onPressed:
                              _isOcrProcessing ? null : _showOcrSourceSheet,
                          style: OutlinedButton.styleFrom(
                            backgroundColor: context.surfaceColor,
                            foregroundColor: textPrimary,
                            side: BorderSide(color: context.cardBorderColor),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: _isOcrProcessing
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: context.accentLavender,
                                  ),
                                )
                              : Icon(
                                  Icons.document_scanner_outlined,
                                  size: 18,
                                  color: context.accentLavender,
                                ),
                          label: const Text(
                            'OCR',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // 3. Slim Utility Strip
          Row(
            children: [
              Expanded(
                child: ScannerUtilityPill(
                  icon: Icons.inventory_2_outlined,
                  label: catalogLabel,
                  iconColor: context.accentPrimary,
                  iconBgColor: context.pastelSageTint,
                  onTap: () => _openAllProductsModal(context),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ScannerUtilityPill(
                  icon: Icons.gavel_rounded,
                  label: tagsisLabel,
                  iconColor: context.accentDanger,
                  iconBgColor: context.pastelBlushTint,
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
                child: ScannerUtilityPill(
                  icon: Icons.add_circle_outline_rounded,
                  label: 'Ürün Bildir',
                  iconColor: context.accentLavender,
                  iconBgColor: context.pastelLavenderTint,
                  onTap: () =>
                      CrowdsourceDialog.showProductContributionModal(context),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // 4. Simplified Product Discovery Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Öne Çıkan Ürünler',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              GestureDetector(
                onTap: () => _openAllProductsModal(context),
                child: Text(
                  'Tümü',
                  style: TextStyle(
                    color: context.accentPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
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
                ScannerFilterChip(
                  label: 'Temiz 80+',
                  selected: _selectedFilterIndex == 0,
                  onTap: () => setState(() => _selectedFilterIndex = 0),
                ),
                const SizedBox(width: 8),
                ScannerFilterChip(
                  label: 'Doğal',
                  selected: _selectedFilterIndex == 1,
                  onTap: () => setState(() => _selectedFilterIndex = 1),
                ),
                const SizedBox(width: 8),
                ScannerFilterChip(
                  label: 'Tümü',
                  selected: _selectedFilterIndex == 2,
                  onTap: () => setState(() => _selectedFilterIndex = 2),
                ),
                const SizedBox(width: 8),
                ScannerFilterChip(
                  label: 'Riskli',
                  selected: _selectedFilterIndex == 3,
                  onTap: () => setState(() => _selectedFilterIndex = 3),
                ),
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
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = filteredProducts[index];
                final scoreColor = _getScoreColor(context, item.score);
                return ShowcaseProductTile(
                  item: item,
                  scoreColor: scoreColor,
                  onTap: () => _openProductDetails(item.barcode),
                );
              },
            ),
        ],
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
      final boycottRows = await db.query('boycott_brands');
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
        final boycott = OfflineFallbackManager.evaluateBoycottStatus(
          productName: name,
          brandName: brand,
          boycottBrands: boycottRows,
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
    } catch (e) {
      debugPrint('AllProductsCatalogModal._loadProducts error: $e');
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

  Color _getScoreColor(BuildContext context, int score) {
    if (score >= 80) return context.accentPrimary;
    if (score >= 60) return context.accentSecondary;
    if (score >= 40) return context.accentWarm;
    return context.accentDanger;
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
                Expanded(
                  child: Text(
                    'Ürün Kataloğu (${_allProducts.length})',
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
                  color: textSecondary.withValues(alpha: 0.75),
                  fontSize: 13,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: context.accentPrimary,
                ),
                isDense: true,
                filled: true,
                fillColor: context.subtleSurfaceColor,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 11,
                  horizontal: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: context.accentPrimary,
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
                          final scoreColor = _getScoreColor(context, score);
                          return ListTile(
                            onTap: () => widget.onProductSelected(
                              item['barcode'] as String,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: scoreColor.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  '$score',
                                  style: TextStyle(
                                    color: scoreColor,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14.5,
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
                              '${item['brand']} · ${item['verdict']}',
                              style: TextStyle(
                                color: textSecondary,
                                fontSize: 11.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
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
