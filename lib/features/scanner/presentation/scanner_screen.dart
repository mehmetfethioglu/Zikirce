import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/changelog_service.dart';
import '../../crowdsource/presentation/crowdsource_dialog.dart';
import '../../family_profiles/domain/family_profile_engine.dart';
import '../../family_profiles/presentation/family_profiles_screen.dart';
import '../../network/domain/edge_worker_sync_service.dart';
import '../../network/domain/offline_fallback_manager.dart';
import '../../product/presentation/product_result_screen.dart';
import '../../taklit_tagsis/presentation/taklit_tagsis_screen.dart';
import '../../taklit_tagsis/domain/taklit_tagsis_service.dart';
import '../../monetization/domain/subscription_service.dart';
import '../../monetization/presentation/paywall_screen.dart';
import '../../settings/presentation/privacy_policy_dialog.dart';
import '../../profile/presentation/home_profile_card.dart';
import '../../profile/domain/user_profile_service.dart';
import '../../profile/presentation/profile_screen.dart';

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
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  FamilyProfile? _activeProfile;
  final TextEditingController _manualBarcodeController = TextEditingController();

  List<ShowcaseProduct> _showcaseProducts = [];

  @override
  void initState() {
    super.initState();
    _loadActiveProfile();
    _loadShowcaseProducts();
    EdgeWorkerSyncService.initAutoSyncListener();
    SubscriptionService.instance.initAdMob();
    WidgetsBinding.instance.addPostFrameCallback((_) { ChangelogService.checkAndShowOnStartup(context); });
    // Sessiz arka plan kontrolü: Bakanlığın yeni duyuruları otomatik senkronize edilir
    Future.delayed(const Duration(seconds: 3), () async {
      try {
        await TaklitTagsisService.syncLatestList();
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _manualBarcodeController.dispose();
    EdgeWorkerSyncService.dispose();
    super.dispose();
  }

  Future<void> _loadShowcaseProducts() async {
    try {
      final Database db = await DatabaseHelper().database;
      final results = await db.query(
        'offline_ai_snapshots',
        columns: ['barcode', 'product_name', 'brand', 'ai_summary_json'],
        limit: 100,
      );

      List<ShowcaseProduct> list = [];
      for (var row in results) {
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

        // Popüler ve öne çıkanlar arasında boykotlu ürün görünmesin
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
            'Doğal içerik ve dengeli besin profiline sahip temiz gıda.';

        final List<String> badges = [
          nova == 1
              ? '🌱 NOVA 1 Katkısız'
              : (nova == 2 ? '🌱 NOVA 2 Doğal' : '🌱 NOVA $nova'),
          '🇹🇷 Boykotsuz & Yerli',
        ];

        list.add(ShowcaseProduct(
          barcode: row['barcode'] as String,
          name: name,
          brand: brand.isNotEmpty ? brand : 'Doğal Seçim',
          score: score,
          category: cat,
          novaGroup: nova,
          boycottStatus: boycottStatus,
          description: desc,
          badges: badges,
        ));
      }

      // En yüksek skorlu en önce olacak şekilde sırala
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

  void _openCameraScanner() {
    bool isScanning = true;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: context.cardBorderColor),
        ),
        child: Column(
          children: [
            // Modal Handle Bar
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

            // Modal Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Canlı Kamera Barkod Tarayıcı',
                    style: TextStyle(
                      color: context.textPrimaryColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: context.textSecondaryColor),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(),

            // MobileScanner Viewfinder
            Expanded(
              child: Stack(
                children: [
                  MobileScanner(
                    onDetect: (capture) {
                      if (!isScanning) return;
                      final List<Barcode> barcodes = capture.barcodes;
                      for (final barcode in barcodes) {
                        if (barcode.rawValue != null) {
                          isScanning = false;
                          Navigator.pop(context); // Close sheet
                          _navigateToScanResult(barcode.rawValue!);
                          break;
                        }
                      }
                    },
                  ),

                  // Viewfinder Overlay Reticle
                  Center(
                    child: Container(
                      width: 260,
                      height: 200,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.primaryEmerald, width: 3),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryEmerald.withValues(alpha: 0.3),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.qr_code_scanner, color: AppColors.primaryMint, size: 48),
                      ),
                    ),
                  ),

                  // Camera Instructions Badge
                  Positioned(
                    bottom: 24,
                    left: 20,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Text(
                        'Ürün barkodunu çerçevenin ortasına getirin',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 12),
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

  /// Opens product details for browsing (tapped showcase card, chip, or catalog).
  /// Does NOT consume scan quota and does NOT award scan XP or increment scan count.
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

  /// Triggered ONLY for actual barcode scans (physical camera detection or manual query).
  /// Enforces scan quota and awards XP/badges with anti-spam duplicate protection.
  Future<void> _navigateToScanResult(String barcode) async {
    bool canScan = await SubscriptionService.instance.canScan();
    if (!canScan) {
      if (mounted) {
        PaywallScreen.show(context, onScanGranted: () => _navigateToScanResult(barcode));
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
    final surfaceColor = context.surfaceColor;
    final borderColor = context.cardBorderColor;
    final textPrimary = context.textPrimaryColor;
    final textSecondary = context.textSecondaryColor;
    final isDark = context.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        leading: PopupMenuButton<String>(
          icon: const Icon(Icons.menu, color: AppColors.primaryMint),
          tooltip: 'Menü',
          color: surfaceColor,
          onSelected: (String value) async {
            if (value == 'theme_system') {
              ThemeController.instance.setThemeMode(ThemeMode.system);
              setState(() {});
            } else if (value == 'theme_light') {
              ThemeController.instance.setThemeMode(ThemeMode.light);
              setState(() {});
            } else if (value == 'theme_dark') {
              ThemeController.instance.setThemeMode(ThemeMode.dark);
              setState(() {});
            } else if (value == 'family') {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const FamilyProfilesScreen()),
              );
              _loadActiveProfile();
            } else if (value == 'profile') {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
              _loadActiveProfile();
            } else if (value == 'privacy') {
              PrivacyPolicyDialog.show(context);
            }
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
            PopupMenuItem<String>(
              enabled: false,
              child: Text(
                'TEMA SEÇİMİ',
                style: TextStyle(color: textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
            PopupMenuItem<String>(
              value: 'theme_system',
              child: Row(
                children: [
                  Icon(Icons.brightness_auto, color: ThemeController.instance.value == ThemeMode.system ? AppColors.primaryEmerald : textSecondary, size: 18),
                  const SizedBox(width: 10),
                  Text('Cihaz Temasıyla Uyumlu', style: TextStyle(color: textPrimary, fontSize: 13)),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'theme_light',
              child: Row(
                children: [
                  Icon(Icons.light_mode, color: ThemeController.instance.value == ThemeMode.light ? AppColors.primaryEmerald : textSecondary, size: 18),
                  const SizedBox(width: 10),
                  Text('Açık Tema (Light)', style: TextStyle(color: textPrimary, fontSize: 13)),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'theme_dark',
              child: Row(
                children: [
                  Icon(Icons.dark_mode, color: ThemeController.instance.value == ThemeMode.dark ? AppColors.primaryEmerald : textSecondary, size: 18),
                  const SizedBox(width: 10),
                  Text('Koyu Tema (OLED Siyah)', style: TextStyle(color: textPrimary, fontSize: 13)),
                ],
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem<String>(
              value: 'profile',
              child: Row(
                children: [
                  const Icon(Icons.person_outline_rounded, color: AppColors.primaryMint, size: 20),
                  const SizedBox(width: 10),
                  Text('Profilim & Rozetlerim', style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'family',
              child: Row(
                children: [
                  const Icon(Icons.family_restroom, color: AppColors.primaryEmerald, size: 20),
                  const SizedBox(width: 10),
                  Text('Aile Profilleri & Alerjenler', style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'privacy',
              child: Row(
                children: [
                  const Icon(Icons.privacy_tip_outlined, color: AppColors.primaryEmerald, size: 20),
                  const SizedBox(width: 10),
                  Text('Gizlilik Politikası', style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
        title: const Text(
          'OrganicScore',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          FutureBuilder<bool>(
            future: SubscriptionService.instance.isAdFree(),
            builder: (context, snapshot) {
              final bool isAdFree = snapshot.data ?? false;
              return GestureDetector(
                onTap: () => PaywallScreen.show(context, onScanGranted: () => setState(() {})),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  margin: const EdgeInsets.only(right: 14),
                  decoration: BoxDecoration(
                    color: isAdFree
                        ? AppColors.primaryEmerald.withValues(alpha: 0.2)
                        : (context.isDarkMode ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05)),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isAdFree ? AppColors.primaryEmerald : borderColor,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isAdFree ? Icons.shield_rounded : Icons.volunteer_activism_rounded,
                        color: isAdFree ? AppColors.primaryEmerald : AppColors.primaryMint,
                        size: 16,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isAdFree ? 'Reklamsız' : 'Gönüllü',
                        style: TextStyle(
                          color: isAdFree ? AppColors.primaryEmerald : textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Profile, Stats & Active Profile Badge Header Card
            HomeProfileCard(
              activeProfile: _activeProfile,
              onActiveProfileTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const FamilyProfilesScreen()),
                );
                _loadActiveProfile();
              },
              onCardTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfileScreen()),
                );
                _loadActiveProfile();
              },
            ),
            const SizedBox(height: 20),

            // Horizontal Showcase Carousel Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Popüler & Öne Çıkan Ürünler',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                GestureDetector(
                  onTap: () => _openAllProductsModal(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryEmerald.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: const [
                        Text(
                          'Tümünü Gör',
                          style: TextStyle(color: AppColors.primaryMint, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward_ios, size: 10, color: AppColors.primaryMint),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Showcase Carousel Cards (Horizontal Slider)
            SizedBox(
              height: 205,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _showcaseProducts.length,
                itemBuilder: (context, index) {
                  final item = _showcaseProducts[index];
                  final scoreColor = _getScoreColor(item.score);

                  return GestureDetector(
                    onTap: () => _openProductDetails(item.barcode),
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
                                  item.brand,
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
                                      '${item.score}',
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
                            item.name,
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
                            children: item.badges.take(2).map((b) => Container(
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

                          // Description / Reason
                          Expanded(
                            child: Text(
                              item.description,
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
                              onPressed: () => _openProductDetails(item.barcode),
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
            const SizedBox(height: 24),

            // Quick Stats Banner (Interactive Tappable Cards)
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _showSnapshotModal(context),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primaryEmerald.withValues(alpha: 0.5)),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.verified, color: AppColors.primaryEmerald, size: 22),
                          const SizedBox(height: 4),
                          Text('8,000+', style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                          Text('Hazır Veri', style: TextStyle(color: textSecondary, fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () => CrowdsourceDialog.showProductContributionModal(context),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primaryMint.withValues(alpha: 0.7)),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.add_a_photo, color: AppColors.primaryMint, size: 22),
                          const SizedBox(height: 4),
                          Text('Katkıda Bul', style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                          Text('Veri / Foto Ekle', style: TextStyle(color: textSecondary, fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _showBoycottModal(context),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.dangerRed.withValues(alpha: 0.5)),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.flag, color: AppColors.dangerRed, size: 22),
                          const SizedBox(height: 4),
                          Text('Etik', style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                          Text('Boykot Taraması', style: TextStyle(color: textSecondary, fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Prominent Camera Scanner Call To Action Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _openCameraScanner,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryEmerald,
                  foregroundColor: Colors.white,
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.camera_alt, size: 26),
                label: const Text(
                  'Kamerayı Aç & Barkod Tara',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Manual Barcode Input Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Manuel Barkod Sorgulama', style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _manualBarcodeController,
                          style: TextStyle(color: textPrimary, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Barkod No girin veya taratın...',
                            hintStyle: TextStyle(color: textSecondary, fontSize: 13),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: borderColor),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.search, color: AppColors.primaryEmerald),
                        onPressed: () {
                          if (_manualBarcodeController.text.isNotEmpty) {
                            _navigateToScanResult(_manualBarcodeController.text.trim());
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_showcaseProducts.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          Text('Örnek Aramalar:', style: TextStyle(color: textSecondary, fontSize: 12)),
                          const SizedBox(width: 8),
                          ..._showcaseProducts.take(4).map((item) => Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ActionChip(
                              label: Text('${item.name.length > 18 ? "${item.name.substring(0, 18)}..." : item.name} (${item.score})', style: const TextStyle(fontSize: 11)),
                              backgroundColor: borderColor,
                              labelStyle: TextStyle(color: _getScoreColor(item.score)),
                              onPressed: () => _openProductDetails(item.barcode),
                            ),
                          )),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 30),
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

  void _showSnapshotModal(BuildContext context) {
    final surfaceColor = context.surfaceColor;
    final textPrimary = context.textPrimaryColor;
    final textSecondary = context.textSecondaryColor;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.verified, color: AppColors.primaryEmerald, size: 24),
            SizedBox(width: 10),
            Text('8,000+ Hazır Ürün Analizi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Türkiye marketlerinde satılan binlerce popüler gıdanın biyokimyasal analizleri yerel cihaz veritabanına önceden senkronize edilmiştir.',
              style: TextStyle(color: textPrimary, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            Text(
              'İnternetsiz ortamlarda bile 0ms gecikmeyle anında detaylı ürün raporu üretilir.',
              style: TextStyle(color: textSecondary, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat', style: TextStyle(color: AppColors.primaryEmerald)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _openAllProductsModal(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryEmerald,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Ürünleri İncele'),
          ),
        ],
      ),
    );
  }



  void _showBoycottModal(BuildContext context) {
    final surfaceColor = context.surfaceColor;
    final textPrimary = context.textPrimaryColor;
    final textSecondary = context.textSecondaryColor;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.flag, color: AppColors.dangerRed, size: 24),
            SizedBox(width: 10),
            Text('Etik & Boykot Taraması', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ürünlerin ana holding sahipliği, etik ihlal kayıtları ve Tarım Bakanlığı taklit/tağşiş listeleri taranarak anında ekranda uyarı verilir.',
              style: TextStyle(color: textPrimary, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            Text(
              'Yeşil (Clear), Sarı (Caution) veya Kırmızı (Flagged) rozetleri ile güvenli seçim yapabilirsiniz.',
              style: TextStyle(color: textSecondary, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Kapat', style: TextStyle(color: textSecondary)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TaklitTagsisScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.dangerRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.gavel, size: 16),
            label: const Text('Bakanlık Kara Listesi'),
          ),
        ],
      ),
    );
  }
}

class _AllProductsCatalogModal extends StatefulWidget {
  final Function(String barcode) onProductSelected;

  const _AllProductsCatalogModal({required this.onProductSelected});

  @override
  State<_AllProductsCatalogModal> createState() => _AllProductsCatalogModalState();
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

  Future<void> _loadProducts() async {
    try {
      final Database db = await DatabaseHelper().database;
      final results = await db.query(
        'offline_ai_snapshots',
        columns: ['barcode', 'product_name', 'brand', 'ai_summary_json'],
        limit: 300,
      );

      final List<Map<String, dynamic>> list = [];
      for (var row in results) {
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
          'verdict': summary['verdict'] ?? 'İşlenmiş Ürün',
        });
      }

      list.sort((a, b) => (b['organic_score'] as int).compareTo(a['organic_score'] as int));

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
                const Icon(Icons.grid_view, color: AppColors.primaryMint),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Öne Çıkan Ürün Kataloğu',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 18,
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: _filter,
              style: TextStyle(color: textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Ürün adı veya marka ara (Örn: Torku, Peynir)...',
                hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.7), fontSize: 13),
                prefixIcon: const Icon(Icons.search, color: AppColors.primaryMint),
                isDense: true,
                filled: true,
                fillColor: surfaceColor,
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: borderColor),
                ),
              ),
            ),
          ),
          const Divider(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primaryEmerald))
                : _filteredProducts.isEmpty
                    ? Center(
                        child: Text(
                          'Eşleşen ürün bulunamadı.',
                          style: TextStyle(color: textSecondary),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _filteredProducts.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = _filteredProducts[index];
                          final int score = item['organic_score'] as int;
                          return ListTile(
                            onTap: () => widget.onProductSelected(item['barcode'] as String),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            leading: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: _getScoreColor(score).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _getScoreColor(score)),
                              ),
                              child: Center(
                                child: Text(
                                  '$score',
                                  style: TextStyle(
                                    color: _getScoreColor(score),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                            title: Text(
                              item['product_name'] as String,
                              style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              'Marka: ${item['brand']} • ${item['verdict']}',
                              style: TextStyle(color: textSecondary, fontSize: 11),
                            ),
                            trailing: Icon(Icons.arrow_forward_ios, size: 14, color: textSecondary),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
