import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/kiler_service.dart';
import '../../domain/receipt_ocr_service.dart';

class ReceiptOcrReviewSheet extends StatefulWidget {
  final List<ReceiptParsedItem> initialItems;

  const ReceiptOcrReviewSheet({
    super.key,
    required this.initialItems,
  });

  static Future<void> scanAndShow(
    BuildContext context, {
    ImageSource source = ImageSource.camera,
  }) async {
    try {
      final items = await ReceiptOcrService.scanReceiptFromSource(source);
      if (!context.mounted) return;

      if (items.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Fişte gıda kalemi seçilemedi. Lütfen fişin net göründüğünden emin olun veya Hızlı Çipleri kullanın.',
            ),
            backgroundColor: AppColors.cautionGold,
          ),
        );
        return;
      }

      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => ReceiptOcrReviewSheet(initialItems: items),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Market fişi okunurken hata oluştu: $e'),
          backgroundColor: AppColors.dangerRed,
        ),
      );
    }
  }

  @override
  State<ReceiptOcrReviewSheet> createState() => _ReceiptOcrReviewSheetState();
}

class _ReceiptOcrReviewSheetState extends State<ReceiptOcrReviewSheet> {
  late List<ReceiptParsedItem> _items;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _items = List<ReceiptParsedItem>.from(widget.initialItems);
  }

  Future<void> _confirmAndSaveSelected() async {
    final selected = _items.where((e) => e.selected).toList();
    if (selected.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      for (final item in selected) {
        await KilerService.instance.addQuickTemplate(item.template);
      }
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '🎉 Market fişinden ${selected.length} ürün Kilerce\'ye eklendi!',
          ),
          backgroundColor: AppColors.primaryEmerald,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kaydetme hatası: $e'),
          backgroundColor: AppColors.dangerRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final surfaceColor = context.surfaceColor;
    final textPrimary = context.textPrimaryColor;
    final textSecondary = context.textSecondaryColor;
    final borderColor = context.cardBorderColor;
    final selectedCount = _items.where((e) => e.selected).length;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryEmerald.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
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
                      'Market Fişi OCR Sonucu',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Fişte tespit edilen ${widget.initialItems.length} ürünü onaylayın',
                      style: TextStyle(color: textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close_rounded, color: textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ListView.separated(
              itemCount: _items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = _items[index];
                final tpl = item.template;
                return CheckboxListTile(
                  value: item.selected,
                  activeColor: AppColors.primaryEmerald,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: borderColor),
                  ),
                  tileColor: Theme.of(context).scaffoldBackgroundColor,
                  onChanged: (val) {
                    setState(() {
                      _items[index] = item.copyWith(selected: val ?? false);
                    });
                  },
                  secondary: Text(
                    tpl.emoji,
                    style: const TextStyle(fontSize: 24),
                  ),
                  title: Text(
                    tpl.name,
                    style: TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    'Fiş satırı: "${item.rawLine}" • ${tpl.defaultZone.emoji} ${tpl.defaultZone.label}',
                    style: TextStyle(color: textSecondary, fontSize: 11.5),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_isSaving || selectedCount == 0)
                  ? null
                  : _confirmAndSaveSelected,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryEmerald,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_circle_rounded),
              label: Text(
                'Seçilen $selectedCount Ürünü Kilere Ekle',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
