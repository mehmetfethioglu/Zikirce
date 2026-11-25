import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import 'tahrir_pro_sheet.dart';

/// Reusable inline card shown in Pro-only tabs/sections when running in Basic mode.
class ProFeatureLockCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;

  const ProFeatureLockCard({
    super.key,
    required this.title,
    required this.description,
    this.icon = Icons.workspace_premium_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.amberGold.withValues(alpha: 0.55),
          width: 1.3,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: AppColors.amberGold.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: AppColors.terracotta,
                size: 28,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.literata(
              fontSize: 17.5,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              height: 1.48,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.74),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.terracotta,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () => TahrirProSheet.show(context),
            icon: const Icon(Icons.lock_open_rounded, size: 19),
            label: Text(
              'Pro Aç • veya 3 Reklamla 24s Ücretsiz Pro',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
