import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/taklit_tagsis_service.dart';
import 'taklit_tagsis_share_dialog.dart';

class TaklitTagsisDetailSheet extends StatelessWidget {
  final TaklitTagsisBrandGroup brandGroup;

  const TaklitTagsisDetailSheet({
    super.key,
    required this.brandGroup,
  });

  /// Helper to display this sheet as a modal bottom sheet.
  static Future<void> show(BuildContext context, TaklitTagsisBrandGroup brandGroup) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (context) => TaklitTagsisDetailSheet(brandGroup: brandGroup),
    );
  }

  void _shareWarning(BuildContext context) {
    TaklitTagsisShareDialog.show(context, brandGroup);
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final surfaceColor = context.surfaceColor;
    final borderColor = context.cardBorderColor;
    final textPrimary = context.textPrimaryColor;
    final textSecondary = context.textSecondaryColor;

    final Color badgeColor = brandGroup.hasHealthHazard
        ? AppColors.dangerRed
        : AppColors.cautionGold;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: borderColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            children: [
              // Drag Indicator
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: textSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Sheet Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  children: [
                    // Header Row with Emblem & Close Button
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: isDark ? 0.2 : 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: badgeColor.withValues(alpha: 0.4), width: 1.5),
                          ),
                          child: Icon(
                            brandGroup.hasHealthHazard
                                ? Icons.health_and_safety_rounded
                                : Icons.gavel_rounded,
                            color: badgeColor,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                brandGroup.brandName,
                                style: TextStyle(
                                  color: textPrimary,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                brandGroup.companyName,
                                style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded, color: textSecondary),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Risk Badge Banner
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: isDark ? 0.15 : 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            brandGroup.hasHealthHazard
                                ? Icons.dangerous_rounded
                                : Icons.report_problem_rounded,
                            color: badgeColor,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  brandGroup.hasHealthHazard
                                      ? 'SAĞLIĞI TEHLİKEYE DÜŞÜREN GIDA'
                                      : 'TAKLİT VEYA TAĞŞİŞ TESPİTİ',
                                  style: TextStyle(
                                    color: badgeColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12.5,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  brandGroup.hasHealthHazard
                                      ? 'Bakanlıkça halk sağlığına zararlı/yasaklı madde içerdiği resmi olarak duyurulmuştur.'
                                      : 'Tüketiciyi yanıltıcı, içerik eksikliği veya yabancı madde karıştırılması tespiti.',
                                  style: TextStyle(
                                    color: textSecondary,
                                    fontSize: 11.5,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Summary Details Grid
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: surfaceColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: borderColor),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Kategori', style: TextStyle(color: textSecondary, fontSize: 11)),
                                const SizedBox(height: 4),
                                Text(
                                  brandGroup.primaryCategory,
                                  style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: surfaceColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: borderColor),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Son Duyuru', style: TextStyle(color: textSecondary, fontSize: 11)),
                                const SizedBox(height: 4),
                                Text(
                                  _formatDate(brandGroup.latestAnnouncedAt),
                                  style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            children: [
                              Text('Hileli Ürün', style: TextStyle(color: badgeColor, fontSize: 11)),
                              const SizedBox(height: 4),
                              Text(
                                '${brandGroup.productCount} Adet',
                                style: TextStyle(color: badgeColor, fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Section: Products List
                    Row(
                      children: [
                        const Icon(Icons.list_alt_rounded, size: 18, color: AppColors.primaryEmerald),
                        const SizedBox(width: 8),
                        Text(
                          'Bakanlıkça Açıklanan Ürünler ve İhlaller',
                          style: TextStyle(
                            color: textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // List of products under this brand
                    ...brandGroup.products.map((product) {
                      final bool isItemHazard = product.isHealthHazard;
                      final Color itemColor = isItemHazard ? AppColors.dangerRed : AppColors.cautionGold;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: itemColor.withValues(alpha: isDark ? 0.5 : 0.3),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: itemColor.withValues(alpha: 0.04),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    product.productName,
                                    style: TextStyle(
                                      color: textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: itemColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    _formatDate(product.announcedAt),
                                    style: TextStyle(
                                      color: itemColor,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: itemColor.withValues(alpha: isDark ? 0.15 : 0.07),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.biotech_rounded,
                                    size: 16,
                                    color: itemColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Laboratuvar Tespiti: ${product.cleanReason}',
                                      style: TextStyle(
                                        color: isDark ? textPrimary : const Color(0xFF7F1D1D),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
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

                    const SizedBox(height: 12),

                    // Legal Notice Box
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: textSecondary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded, size: 16, color: textSecondary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'T.C. Tarım ve Orman Bakanlığı 5996 sayılı Kanun gereğince kamuoyu duyurusudur. Bu ürünlerin tüketilmesi sağlık ve mevzuat açısından sakıncalıdır.',
                              style: TextStyle(
                                color: textSecondary,
                                fontSize: 11,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Share Warning Action Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: badgeColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () => _shareWarning(context),
                        icon: const Icon(Icons.share_rounded, size: 20),
                        label: const Text(
                          'Resmi Bakanlık İkazını Paylaş',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
