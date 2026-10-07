import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_theme.dart';

class SocialShareCard {
  static void showShareModal(
    BuildContext context, {
    required String productName,
    required int organicScore,
    required String verdict,
    required int hazardsCount,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Hikayede Paylaş Kart Önizlemesi',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // 1080x1920 Proportional Instagram Story Preview Canvas Widget
              AspectRatio(
                aspectRatio: 9 / 16,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF0F172A),
                        Color(0xFF1E293B),
                        Color(0xFF064E3B),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.primaryEmerald.withValues(alpha: 0.5), width: 2),
                    boxShadow: const [
                      BoxShadow(color: Colors.black45, blurRadius: 20),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // App Header Brand
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.eco, color: AppColors.primaryMint, size: 24),
                          SizedBox(width: 8),
                          Text(
                            'OrganicScore',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),

                      // Score Circle Badge
                      Column(
                        children: [
                          Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.surface,
                              border: Border.all(
                                color: organicScore >= 70 ? AppColors.primaryEmerald : AppColors.dangerRed,
                                width: 6,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: (organicScore >= 70 ? AppColors.primaryEmerald : AppColors.dangerRed).withValues(alpha: 0.4),
                                  blurRadius: 25,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                '$organicScore',
                                style: TextStyle(
                                  color: organicScore >= 70 ? AppColors.primaryEmerald : AppColors.dangerRed,
                                  fontSize: 44,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            productName,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Karar: $verdict',
                            style: const TextStyle(
                              color: AppColors.primaryMint,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),

                      // Footer Watermark
                      Column(
                        children: [
                          if (hazardsCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.dangerRed.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '⚠️ $hazardsCount Zararlı E-Kodu / Katkı Maddesi',
                                style: const TextStyle(color: AppColors.dangerRed, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          const SizedBox(height: 12),
                          const Text(
                            'OrganicScore App ile Taranmıştır • 100% Çevrimdışı Güvenli',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 10),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryEmerald,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.send),
                label: const Text('Instagram Stories / WhatsApp\'ta Paylaş'),
                onPressed: () {
                  Navigator.pop(context);
                  Share.share(
                    'OrganicScore Analiz Sonucu: $productName ürünü $organicScore / 100 puan aldı ($verdict). Sen de indirmeyi unutma! #OrganicScore',
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
