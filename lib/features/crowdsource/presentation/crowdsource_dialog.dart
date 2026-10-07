import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/theme/app_theme.dart';
import 'package:share_plus/share_plus.dart';
import '../../monetization/domain/subscription_service.dart';
import '../../network/domain/edge_worker_sync_service.dart';
import '../../network/domain/open_food_facts_service.dart';

class CrowdsourceDialog {
  /// Simple Ownership & Alternative Report Dialog
  static void show(BuildContext context, {required String barcode}) {
    final TextEditingController payloadController = TextEditingController();
    String reportType = 'OWNERSHIP_UPDATE';

    final surfaceColor = context.surfaceColor;
    final textPrimary = context.textPrimaryColor;
    final textSecondary = context.textSecondaryColor;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: surfaceColor,
          title: Text('Topluluk Etik & Alternatif Bildirimi', style: TextStyle(color: textPrimary, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<String>(
                value: reportType,
                dropdownColor: surfaceColor,
                isExpanded: true,
                style: TextStyle(color: textPrimary),
                items: [
                  DropdownMenuItem(
                    value: 'OWNERSHIP_UPDATE',
                    child: Text('Marka / Şirket Sahipliği Güncellemesi', style: TextStyle(color: textPrimary)),
                  ),
                  DropdownMenuItem(
                    value: 'ALTERNATIVE_SUGGESTION',
                    child: Text('Sağlıklı Yerel Alternatif Önerisi', style: TextStyle(color: textPrimary)),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) setDialogState(() => reportType = val);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: payloadController,
                maxLines: 3,
                style: TextStyle(color: textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: reportType == 'OWNERSHIP_UPDATE'
                      ? 'Görüş veya kanıt belirtin (ör: Çatı şirket satıldı, güncel üretici X)'
                      : 'Alternatif ürün adı, markası ve sağlıklı yönü',
                  hintStyle: TextStyle(color: textSecondary, fontSize: 12),
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('İptal', style: TextStyle(color: textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryEmerald, foregroundColor: Colors.white),
              onPressed: () async {
                if (payloadController.text.isNotEmpty) {
                  final Database db = await DatabaseHelper().database;
                  await db.insert('crowdsourced_queue', {
                    'type': reportType,
                    'barcode': barcode,
                    'payload_json': jsonEncode({'details': payloadController.text.trim()}),
                    'status': 'PENDING',
                  });

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('⚡ Bildiriminiz çevrimdışı kuyruğa eklendi. İnternete bağlanıldığında doğrulanacaktır.'),
                        backgroundColor: AppColors.primaryEmerald,
                      ),
                    );
                  }
                }
              },
              child: const Text('Gönder'),
            ),
          ],
        ),
      ),
    );
  }

  /// Checks if a barcode is already registered in SQLite or OFF API and returns product info
  static Future<Map<String, dynamic>?> _lookupBarcodeAndCheckExistence(String barcode) async {
    if (barcode.trim().isEmpty) return null;
    final code = barcode.trim();

    try {
      // 1. Search local SQLite database
      final Database db = await DatabaseHelper().database;
      final results = await db.query(
        'offline_ai_snapshots',
        where: 'barcode = ?',
        whereArgs: [code],
        limit: 1,
      );

      if (results.isNotEmpty) {
        final row = results.first;
        final name = row['product_name'] as String? ?? '';
        final brand = row['brand'] as String? ?? '';
        final summaryJson = row['ai_summary_json'] as String? ?? '';
        String ingredients = '';

        if (summaryJson.isNotEmpty) {
          try {
            final map = jsonDecode(summaryJson);
            final summaryText = map['summary'] as String? ?? '';
            if (summaryText.contains('İçindekiler:')) {
              final parts = summaryText.split('İçindekiler:');
              if (parts.length > 1) {
                ingredients = parts[1].trim();
              }
            }
          } catch (_) {}
        }

        return {
          'exists': true,
          'product_name': name,
          'brand': brand,
          'ingredients': ingredients,
          'source': 'Yerel Veritabanı',
        };
      }

      // 2. Search Open Food Facts API
      final res = await OpenFoodFactsService.fetchProductByBarcode(code);
      if (res != null) {
        String ingredients = '';
        if (res.aiSummary.contains('İçindekiler:')) {
          final parts = res.aiSummary.split('İçindekiler:');
          if (parts.length > 1) {
            ingredients = parts[1].trim();
          }
        }
        return {
          'exists': true,
          'product_name': res.productName,
          'brand': res.brand,
          'ingredients': ingredients,
          'source': 'Bulut API Veritabanı',
        };
      }
    } catch (_) {}

    return {'exists': false};
  }

  /// Full Product Contribution Modal with Keyboard Padding & Clean Inset
  static Future<void> showProductContributionModal(
    BuildContext context, {
    String? initialBarcode,
    String? prefilledProductName,
    String? prefilledBrand,
  }) async {
    final TextEditingController barcodeController = TextEditingController(text: initialBarcode ?? '');
    final TextEditingController nameController = TextEditingController(text: prefilledProductName ?? '');
    final TextEditingController brandController = TextEditingController(text: prefilledBrand ?? '');
    final TextEditingController ingredientsController = TextEditingController();

    bool hasBarcodePhoto = (initialBarcode != null && initialBarcode.isNotEmpty);
    bool hasPackagingPhoto = (prefilledProductName != null && prefilledProductName.isNotEmpty);
    bool hasIngredientsPhoto = false;

    // Check if initialBarcode already exists in DB
    if (initialBarcode != null && initialBarcode.isNotEmpty) {
      _lookupBarcodeAndCheckExistence(initialBarcode).then((data) {
        if (data != null && data['exists'] == true) {
          if (nameController.text.isEmpty) nameController.text = data['product_name'] ?? '';
          if (brandController.text.isEmpty) brandController.text = data['brand'] ?? '';
          if (ingredientsController.text.isEmpty) ingredientsController.text = data['ingredients'] ?? '';
        }
      });
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final surfaceColor = context.surfaceColor;
          final textPrimary = context.textPrimaryColor;
          final textSecondary = context.textSecondaryColor;
          final borderColor = context.cardBorderColor;
          final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

          return AnimatedPadding(
            padding: EdgeInsets.only(bottom: keyboardHeight),
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.88,
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
                        const Icon(Icons.add_a_photo, color: AppColors.primaryMint, size: 24),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Topluluk Veri Katkısı & Ürün Ekle',
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
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '🛡️ Veri Temizliği İlkesi: Ürününüzün sisteme kaydolması için Barkod, Ambalaj Önü ve İçindekiler etiketinin 3\'ünün de kamerayla çekilmesi zorunludur.',
                            style: TextStyle(color: textSecondary, fontSize: 12, height: 1.4),
                          ),
                          const SizedBox(height: 16),

                          // Section 1: Photo Capture Widgets
                          Text(
                            '1. Ürün Fotoğrafları & Taramalar (Zorunlu 3 Adım)',
                            style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              // Slot 1: Barcode Scan
                              Expanded(
                                child: _buildPhotoTile(
                                  context,
                                  title: 'Barkod Çek',
                                  icon: Icons.qr_code_scanner,
                                  isCaptured: hasBarcodePhoto,
                                  onTap: () {
                                    _openCameraForBarcode(
                                      context,
                                      barcodeController: barcodeController,
                                      nameController: nameController,
                                      brandController: brandController,
                                      ingredientsController: ingredientsController,
                                      onSuccess: () {
                                        setModalState(() => hasBarcodePhoto = true);
                                      },
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Slot 2: Packaging Photo & ML Kit OCR
                              Expanded(
                                child: _buildPhotoTile(
                                  context,
                                  title: 'Ambalaj Önü Çek',
                                  icon: Icons.shopping_bag_outlined,
                                  isCaptured: hasPackagingPhoto,
                                  onTap: () async {
                                    await _capturePhotoAndPerformOcr(
                                      context,
                                      mode: 'PACKAGING',
                                      nameController: nameController,
                                      brandController: brandController,
                                      ingredientsController: ingredientsController,
                                      onSuccess: () {
                                        setModalState(() => hasPackagingPhoto = true);
                                      },
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Slot 3: Ingredients Photo & ML Kit OCR
                              Expanded(
                                child: _buildPhotoTile(
                                  context,
                                  title: 'İçindekiler Çek',
                                  icon: Icons.receipt_long_outlined,
                                  isCaptured: hasIngredientsPhoto,
                                  onTap: () async {
                                    await _capturePhotoAndPerformOcr(
                                      context,
                                      mode: 'INGREDIENTS',
                                      nameController: nameController,
                                      brandController: brandController,
                                      ingredientsController: ingredientsController,
                                      onSuccess: () {
                                        setModalState(() => hasIngredientsPhoto = true);
                                      },
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Section 2: Form Details
                          Text(
                            '2. Ürün Detayları (Fotoğraftan / OCR Otomatik Doldurulur)',
                            style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 10),

                          // Barcode Field
                          TextField(
                            controller: barcodeController,
                            keyboardType: TextInputType.number,
                            style: TextStyle(color: textPrimary, fontSize: 14),
                            onChanged: (val) async {
                              if (val.length >= 8) {
                                final existing = await _lookupBarcodeAndCheckExistence(val);
                                if (existing != null && existing['exists'] == true) {
                                  nameController.text = existing['product_name'] ?? '';
                                  brandController.text = existing['brand'] ?? '';
                                  ingredientsController.text = existing['ingredients'] ?? '';
                                  setModalState(() {});
                                }
                              }
                            },
                            decoration: InputDecoration(
                              labelText: 'Barkod Numarası',
                              labelStyle: TextStyle(color: textSecondary, fontSize: 13),
                              hintText: 'Barkod Çek kartıyla veya manuel girin',
                              hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.6), fontSize: 12),
                              prefixIcon: const Icon(Icons.barcode_reader, color: AppColors.primaryEmerald),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Product Name Field
                          TextField(
                            controller: nameController,
                            style: TextStyle(color: textPrimary, fontSize: 14),
                            decoration: InputDecoration(
                              labelText: 'Ürün Adı',
                              labelStyle: TextStyle(color: textSecondary, fontSize: 13),
                              hintText: 'Ambalaj fotoğrafından OCR ile veya elle girin',
                              hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.6), fontSize: 12),
                              prefixIcon: const Icon(Icons.fastfood_outlined, color: AppColors.primaryEmerald),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Brand Field
                          TextField(
                            controller: brandController,
                            style: TextStyle(color: textPrimary, fontSize: 14),
                            decoration: InputDecoration(
                              labelText: 'Marka / Üretici Firma',
                              labelStyle: TextStyle(color: textSecondary, fontSize: 13),
                              hintText: 'Ambalaj fotoğrafından OCR ile veya elle girin',
                              hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.6), fontSize: 12),
                              prefixIcon: const Icon(Icons.storefront_outlined, color: AppColors.primaryEmerald),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Ingredients Text Field
                          TextField(
                            controller: ingredientsController,
                            maxLines: 4,
                            style: TextStyle(color: textPrimary, fontSize: 13),
                            decoration: InputDecoration(
                              labelText: 'İçindekiler Metni',
                              labelStyle: TextStyle(color: textSecondary, fontSize: 13),
                              hintText: 'İçindekiler etiket fotoğrafından OCR ile veya elle girin',
                              hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.6), fontSize: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Submit Button
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryEmerald,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                elevation: 4,
                              ),
                              icon: const Icon(Icons.cloud_upload_outlined, size: 22),
                              label: const Text(
                                'Katkıyı Kaydet & Gönder',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                              onPressed: () async {
                                final barcode = barcodeController.text.trim();
                                final name = nameController.text.trim();
                                final brand = brandController.text.trim();
                                final ingText = ingredientsController.text.trim();

                                // 1. Strict validation: All 3 photo/scans mandatory
                                if (!hasBarcodePhoto || !hasPackagingPhoto || !hasIngredientsPhoto) {
                                  List<String> missing = [];
                                  if (!hasBarcodePhoto) missing.add('Barkod Taraması');
                                  if (!hasPackagingPhoto) missing.add('Ambalaj Fotoğrafı');
                                  if (!hasIngredientsPhoto) missing.add('İçindekiler Fotoğrafı');

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('⚠️ Temiz veri ilkesi gereği tüm taramalar zorunludur! Eksik: ${missing.join(", ")}'),
                                      backgroundColor: AppColors.dangerRed,
                                      duration: const Duration(seconds: 4),
                                    ),
                                  );
                                  return;
                                }

                                // 2. Strict validation: Standard EAN barcode format (8 to 14 numeric digits)
                                final isStandardBarcode = RegExp(r'^\d{8,14}$').hasMatch(barcode);
                                if (!isStandardBarcode) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('⚠️ Standart dışı barkod! Barkod no 8-14 hane arasında sadece rakamlardan oluşmalıdır (Örn: EAN-13).'),
                                      backgroundColor: AppColors.dangerRed,
                                      duration: Duration(seconds: 4),
                                    ),
                                  );
                                  return;
                                }

                                // 3. Strict validation: Text fields cannot be empty
                                if (name.isEmpty || brand.isEmpty || ingText.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('⚠️ Lütfen Ürün Adı, Marka ve İçindekiler alanlarını eksiksiz kontrol edip doldurunuz.'),
                                      backgroundColor: AppColors.dangerRed,
                                      duration: Duration(seconds: 4),
                                    ),
                                  );
                                  return;
                                }

                                try {
                                  final Database db = await DatabaseHelper().database;

                                  // Ensure table schema has no rigid CHECK constraints
                                  await db.execute('''
                                    CREATE TABLE IF NOT EXISTS crowdsourced_queue (
                                      id INTEGER PRIMARY KEY AUTOINCREMENT,
                                      type TEXT NOT NULL,
                                      barcode TEXT NOT NULL,
                                      payload_json TEXT NOT NULL,
                                      status TEXT DEFAULT 'PENDING'
                                    )
                                  ''');

                                  final String finalBarcode = barcode.isNotEmpty ? barcode : 'CROWD_${DateTime.now().millisecondsSinceEpoch}';
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

                                  final int calculatedScore = hasRisks ? 45 : (isPureNatural ? 95 : 85);
                                  final int novaGrp = hasRisks ? 4 : (isPureNatural ? 1 : 2);
                                  final String novaText = novaGrp == 4
                                      ? 'Ultra İşlenmiş Gıda (NOVA 4)'
                                      : (novaGrp == 1 ? 'İşlenmemiş / Organik (NOVA 1)' : 'İşlenmiş Mutfak Malzemesi (NOVA 2)');

                                  await db.insert('crowdsourced_queue', {
                                    'type': 'NEW_PRODUCT_SUBMISSION',
                                    'barcode': finalBarcode,
                                    'payload_json': jsonEncode({
                                      'product_name': name,
                                      'brand': brand,
                                      'ingredients_text': ingText,
                                      'has_barcode_photo': hasBarcodePhoto,
                                      'has_packaging_photo': hasPackagingPhoto,
                                      'has_ingredients_photo': hasIngredientsPhoto,
                                      'submitted_at': DateTime.now().toIso8601String(),
                                    }),
                                    'status': 'PENDING',
                                  });

                                  try {
                                    await db.insert(
                                      'offline_ai_snapshots',
                                      {
                                        'barcode': finalBarcode,
                                        'product_name': name,
                                        'brand': brand,
                                        'ai_summary_json': jsonEncode({
                                          'organic_score': calculatedScore,
                                          'nova_group': novaGrp,
                                          'verdict': novaText,
                                          'summary': '$brand üreticisine ait $name. Katkıda bulun bölümü ile topluluk tarafından eklendi.${ingText.isNotEmpty ? " İçindekiler: $ingText" : ""}',
                                          'warnings': hasRisks ? ['İşlenmiş İçerik / Katkı Maddesi'] : [],
                                          'alternatives': [],
                                        }),
                                        'synced_at': DateTime.now().millisecondsSinceEpoch,
                                      },
                                      conflictAlgorithm: ConflictAlgorithm.replace,
                                    );
                                  } catch (_) {}

                                  // Live Cloud Upload via Edge Worker
                                  try {
                                    final bool cloudSuccess = await EdgeWorkerSyncService.submitProductToCloud(
                                      barcode: finalBarcode,
                                      name: name,
                                      brand: brand,
                                      ingredientsText: ingText,
                                    );

                                    if (cloudSuccess) {
                                      await db.update(
                                        'crowdsourced_queue',
                                        {'status': 'SYNCED'},
                                        where: 'barcode = ?',
                                        whereArgs: [finalBarcode],
                                      );
                                    }
                                  } catch (_) {}

                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    final reward = await SubscriptionService.instance.rewardContribution();
                                    if (context.mounted) {
                                      _showRewardModal(context, reward);
                                    }
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Katkı Kaydedildi: $name ($barcode)'),
                                        backgroundColor: AppColors.primaryEmerald,
                                        duration: const Duration(seconds: 3),
                                      ),
                                    );
                                    Navigator.pop(context);
                                  }
                                }
                              },
                            ),
                          ),
                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Live Barcode Scanner Camera Modal with Database Existence Check
  static void _openCameraForBarcode(
    BuildContext context, {
    required TextEditingController barcodeController,
    required TextEditingController nameController,
    required TextEditingController brandController,
    required TextEditingController ingredientsController,
    required VoidCallback onSuccess,
  }) {
    bool isProcessing = false;
    final surfaceColor = context.surfaceColor;
    final textPrimary = context.textPrimaryColor;
    final textSecondary = context.textSecondaryColor;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: surfaceColor,
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
                color: textSecondary.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Icon(Icons.qr_code_scanner, color: AppColors.primaryEmerald, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Canlı Kamera Barkod Tarayıcı',
                      style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
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
              child: Stack(
                children: [
                  MobileScanner(
                    onDetect: (capture) async {
                      if (isProcessing) return;
                      final List<Barcode> barcodes = capture.barcodes;
                      if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
                        isProcessing = true;
                        final String code = barcodes.first.rawValue!;
                        barcodeController.text = code;

                        final existingData = await _lookupBarcodeAndCheckExistence(code);

                        if (context.mounted) {
                          Navigator.pop(context); // Close camera modal
                          onSuccess();

                          if (existingData != null && existingData['exists'] == true) {
                            final name = existingData['product_name'] as String? ?? '';
                            final brand = existingData['brand'] as String? ?? '';
                            final ingredients = existingData['ingredients'] as String? ?? '';

                            if (name.isNotEmpty) nameController.text = name;
                            if (brand.isNotEmpty) brandController.text = brand;
                            if (ingredients.isNotEmpty) ingredientsController.text = ingredients;

                            // Display warning dialog that product ALREADY exists
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                backgroundColor: context.surfaceColor,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                title: Row(
                                  children: const [
                                    Icon(Icons.warning_amber_rounded, color: AppColors.cautionGold, size: 24),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Ürün Zaten Kayıtlı!',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Barkod: $code', style: TextStyle(color: context.textPrimaryColor, fontWeight: FontWeight.bold, fontSize: 13)),
                                    const SizedBox(height: 4),
                                    Text('Mevcut Ürün: $name\nMarka: $brand', style: TextStyle(color: context.textPrimaryColor, fontSize: 13)),
                                    const SizedBox(height: 12),
                                    Text(
                                      '⚠️ Bu ürün veritabanımızda zaten mevcuttur. Eğer eksik bilgi tamamlayacaksanız formu düzenleyebilirsiniz.',
                                      style: TextStyle(color: context.textSecondaryColor, fontSize: 12, height: 1.4),
                                    ),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Tamam, Formu Düzenle', style: TextStyle(color: AppColors.primaryEmerald, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('✅ Yeni ürün barkodu okundu: $code (Veritabanında bulunamadı, yeni ürün ekleyebilirsiniz).'),
                                backgroundColor: AppColors.primaryEmerald,
                                duration: const Duration(seconds: 3),
                              ),
                            );
                          }
                        }
                      }
                    },
                  ),

                  // Viewfinder Reticle Frame
                  Center(
                    child: Container(
                      width: 280,
                      height: 180,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.primaryEmerald, width: 3),
                        borderRadius: BorderRadius.circular(20),
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

                  Positioned(
                    top: 20,
                    left: 20,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: AppColors.primaryEmerald.withValues(alpha: 0.5)),
                      ),
                      child: const Text(
                        'Ürün barkodunu çerçevenin ortasına getirin',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
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

  /// Real Camera Photo Capture, Google ML Kit OCR & Crop Confirmation Modal
  static Future<void> _capturePhotoAndPerformOcr(
    BuildContext context, {
    required String mode, // 'PACKAGING' or 'INGREDIENTS'
    required TextEditingController nameController,
    required TextEditingController brandController,
    required TextEditingController ingredientsController,
    required VoidCallback onSuccess,
  }) async {
    final ImagePicker picker = ImagePicker();

    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 95,
      );

      if (image == null) return; // User cancelled camera

      final inputImage = InputImage.fromFilePath(image.path);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      final String rawText = recognizedText.text.trim();
      await textRecognizer.close();

      if (rawText.isNotEmpty) {
        String textToUse = rawText;

        // Smart Extraction Filter for Ingredients: Crop starting from "İçindekiler"
        if (mode == 'INGREDIENTS') {
          final RegExp ingredientsPattern = RegExp(
            r'(i̇çi̇ndeki̇ler|içindekiler|icindekiler|ingredients|bileşenler)\s*[:\-\s]?',
            caseSensitive: false,
          );
          final match = ingredientsPattern.firstMatch(rawText);
          if (match != null) {
            textToUse = rawText.substring(match.start).trim();
          }
        }

        if (!context.mounted) return;

        // Show OCR Text Crop & Confirmation Dialog
        final String? confirmedText = await _showOcrTextConfirmationDialog(
          context,
          initialText: textToUse,
          modeTitle: mode == 'PACKAGING' ? 'Ambalaj Metni' : 'İçindekiler Etiket Metni',
        );

        if (confirmedText == null || confirmedText.isEmpty) {
          // User chose "Yeniden Çek"
          if (context.mounted) {
            _capturePhotoAndPerformOcr(
              context,
              mode: mode,
              nameController: nameController,
              brandController: brandController,
              ingredientsController: ingredientsController,
              onSuccess: onSuccess,
            );
          }
          return;
        }

        // Apply confirmed text to form fields
        onSuccess();

        if (mode == 'PACKAGING') {
          final lines = confirmedText.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
          nameController.text = confirmedText.replaceAll('\n', ' ');
          if (lines.isNotEmpty) {
            brandController.text = lines.first;
          }
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('📸 Ambalaj metni onaylandı ve aktarıldı: "${lines.first}"'),
                backgroundColor: AppColors.primaryEmerald,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        } else if (mode == 'INGREDIENTS') {
          ingredientsController.text = confirmedText;
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('📸 İçindekiler metni onaylandı ve aktarıldı (${confirmedText.length} karakter).'),
                backgroundColor: AppColors.primaryEmerald,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Çekilen fotoğraftan okunaklı metin okunamadı. Lütfen etiketi net ve aydınlık ortamda tekrar çekin.'),
              backgroundColor: AppColors.dangerRed,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kamera veya Metin Okuma Hatası: $e'),
            backgroundColor: AppColors.dangerRed,
          ),
        );
      }
    }
  }

  /// OCR Text Crop & Confirmation Dialog
  static Future<String?> _showOcrTextConfirmationDialog(
    BuildContext context, {
    required String initialText,
    required String modeTitle,
  }) async {
    final TextEditingController textController = TextEditingController(text: initialText);
    String? result;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: context.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.crop_rotate, color: AppColors.primaryMint, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'OCR Taraması & Metin Kırpma',
                style: TextStyle(color: context.textPrimaryColor, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$modeTitle fotoğraftan başarıyla okundu. İstemediğiniz dış metinleri (adres, slogan vb.) silebilir veya onaylayabilirsiniz:',
              style: TextStyle(color: context.textSecondaryColor, fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textController,
              maxLines: 6,
              style: TextStyle(color: context.textPrimaryColor, fontSize: 13, height: 1.4),
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primaryEmerald, width: 1.5),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              result = null;
              Navigator.pop(context);
            },
            child: Text('Yeniden Çek', style: TextStyle(color: context.textSecondaryColor)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryEmerald,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Metni Onayla & Aktar', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              result = textController.text.trim();
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );

    return result;
  }

  static Widget _buildPhotoTile(
    BuildContext context, {
    required String title,
    required IconData icon,
    required bool isCaptured,
    required VoidCallback onTap,
  }) {
    final surfaceColor = context.surfaceColor;
    final textPrimary = context.textPrimaryColor;
    final textSecondary = context.textSecondaryColor;
    final borderColor = context.cardBorderColor;

    final activeColor = isCaptured ? AppColors.primaryEmerald : AppColors.primaryMint;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: isCaptured ? AppColors.primaryEmerald.withValues(alpha: 0.12) : surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isCaptured ? AppColors.primaryEmerald : borderColor,
            width: isCaptured ? 1.8 : 1.0,
          ),
        ),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  isCaptured ? Icons.check_circle : icon,
                  color: activeColor,
                  size: 28,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                color: isCaptured ? AppColors.primaryEmerald : textPrimary,
                fontSize: 11,
                fontWeight: isCaptured ? FontWeight.bold : FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              isCaptured ? 'Fotoğraf Alındı' : 'Foto Çek & Oku',
              style: TextStyle(
                color: isCaptured ? AppColors.primaryEmerald : textSecondary,
                fontSize: 9,
                fontWeight: isCaptured ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  static void _showRewardModal(BuildContext context, ContributionRewardResult reward) {
    final surfaceColor = context.surfaceColor;
    final textPrimary = context.textPrimaryColor;
    final textSecondary = context.textSecondaryColor;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              reward.reachedMilestone ? Icons.workspace_premium : Icons.stars,
              color: AppColors.cautionGold,
              size: 28,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                reward.reachedMilestone ? '🎉 TEBRİKLER! HEDİYE KAZANDINIZ' : '⭐ Katkı Ödülü Kazanıldı',
                style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              reward.message,
              style: TextStyle(color: textPrimary, fontSize: 14, height: 1.4),
            ),
            if (reward.generatedGiftCode != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primaryEmerald.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primaryEmerald),
                ),
                child: Column(
                  children: [
                    Text('1 AYLIK PRO HEDİYE KODUNUZ:', style: TextStyle(color: textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    SelectableText(
                      reward.generatedGiftCode!,
                      style: const TextStyle(
                        color: AppColors.primaryEmerald,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryEmerald,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.share, size: 18),
                  label: const Text('Hediyeyi Arkadaşınla Paylaş'),
                  onPressed: () {
                    final String shareMsg = 'Sana OrganicScore uygulamasında 1 Aylık Ücretsiz PRO Üyelik hediyesi gönderdim! 🎁\n\n'
                        'Hediye Kodun: ${reward.generatedGiftCode}\n\n'
                        'Uygulamayı indir ve Ayarlar / Ödeme ekranından "Promosyon Kodu Kullan" diyerek kodunu gir, PRO özellikleri anında kullan!';
                    Share.share(shareMsg);
                  },
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Harika!', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryEmerald)),
          ),
        ],
      ),
    );
  }
}
