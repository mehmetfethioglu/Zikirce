import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../network/domain/boycott_sync_service.dart';

class BoycottReportDialog extends StatefulWidget {
  final String barcode;
  final String productName;
  final String brandName;
  final String currentStatus;

  const BoycottReportDialog({
    super.key,
    required this.barcode,
    required this.productName,
    required this.brandName,
    required this.currentStatus,
  });

  static Future<void> show(
    BuildContext context, {
    required String barcode,
    required String productName,
    required String brandName,
    required String currentStatus,
  }) {
    return showDialog(
      context: context,
      builder: (context) => BoycottReportDialog(
        barcode: barcode,
        productName: productName,
        brandName: brandName,
        currentStatus: currentStatus,
      ),
    );
  }

  @override
  State<BoycottReportDialog> createState() => _BoycottReportDialogState();
}

class _BoycottReportDialogState extends State<BoycottReportDialog> {
  late final TextEditingController _reasonController;
  late String _selectedType;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _reasonController = TextEditingController();
    // Default suggestion based on current status
    _selectedType = (widget.currentStatus == 'FLAGGED' || widget.currentStatus == 'CAUTION')
        ? 'FALSE_POSITIVE'
        : 'NEW_BOYCOTT';
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    final success = await BoycottSyncService.reportBoycottDispute(
      barcode: widget.barcode,
      productName: widget.productName,
      brandName: widget.brandName,
      reportType: _selectedType,
      reason: _reasonController.text.trim().isNotEmpty
          ? _reasonController.text.trim()
          : (_selectedType == 'FALSE_POSITIVE'
              ? 'Kullanıcı bu ürünün Gazze boykotu ile bağı olmadığını bildirdi.'
              : 'Kullanıcı bu markanın boykot listesine eklenmesi gerektiğini bildirdi.'),
    );

    if (!mounted) return;

    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: success ? AppColors.primaryEmerald : AppColors.cautionGold,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            Icon(
              success ? Icons.check_circle_outline : Icons.info_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                success
                    ? 'Bildiriminiz alındı. Gazze hassasiyeti kriterlerine göre incelenecektir.'
                    : 'Bildirim yerel kuyruğa kaydedildi. İnternet bağlandığında iletilecektir.',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final surfaceColor = context.surfaceColor;
    final textPrimary = context.textPrimaryColor;
    final textSecondary = context.textSecondaryColor;

    return AlertDialog(
      backgroundColor: surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: const [
          Icon(Icons.rate_review_outlined, color: AppColors.primaryEmerald, size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Boykot Durumu Bildirimi',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: textSecondary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.productName,
                    style: TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Marka: ${widget.brandName}',
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Bildirim Türü:',
              style: TextStyle(
                color: textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            InkWell(
              onTap: () => setState(() => _selectedType = 'FALSE_POSITIVE'),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _selectedType == 'FALSE_POSITIVE'
                      ? AppColors.primaryEmerald.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _selectedType == 'FALSE_POSITIVE'
                        ? AppColors.primaryEmerald
                        : textSecondary.withValues(alpha: 0.2),
                    width: _selectedType == 'FALSE_POSITIVE' ? 1.5 : 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _selectedType == 'FALSE_POSITIVE'
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: _selectedType == 'FALSE_POSITIVE'
                          ? AppColors.primaryEmerald
                          : textSecondary,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bu ürün boykotlu değil (Yanlış Alarm)',
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Yerli üretici / Gazze ihlali veya işgal bağı bulunmuyor',
                            style: TextStyle(color: textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () => setState(() => _selectedType = 'NEW_BOYCOTT'),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _selectedType == 'NEW_BOYCOTT'
                      ? AppColors.dangerRed.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _selectedType == 'NEW_BOYCOTT'
                        ? AppColors.dangerRed
                        : textSecondary.withValues(alpha: 0.2),
                    width: _selectedType == 'NEW_BOYCOTT' ? 1.5 : 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _selectedType == 'NEW_BOYCOTT'
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: _selectedType == 'NEW_BOYCOTT'
                          ? AppColors.dangerRed
                          : textSecondary,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bu ürün boykotlu olmalı (Eksik Kayıt)',
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'İşgal bölgesi ortaklığı veya askeri destek kanıtı var',
                            style: TextStyle(color: textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reasonController,
              maxLines: 3,
              style: TextStyle(color: textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Açıklama veya kanıt linki (Örn: Bu ürün Eti Lifalif, Türk firmasıdır)...',
                hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.6), fontSize: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: textSecondary.withValues(alpha: 0.2)),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: Text('Vazgeç', style: TextStyle(color: textSecondary)),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submitReport,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryEmerald,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Bildirimi Gönder', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ),
      ],
    );
  }
}
