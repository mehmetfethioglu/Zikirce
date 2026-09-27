import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/haptic_service.dart';
import '../../providers/tilavet_secdesi_provider.dart';
import 'tilavet_secdesi_guide_sheet.dart';

class TilavetSecdesiCard extends ConsumerWidget {
  final void Function(int page)? onNavigateToPage;

  const TilavetSecdesiCard({
    super.key,
    this.onNavigateToPage,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debt = ref.watch(tilavetSecdesiDebtProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final primaryTextColor =
        isDark ? const Color(0xFFE8DDD0) : const Color(0xFF1E2B27);
    final secondaryTextColor =
        isDark ? const Color(0xFFA89888) : const Color(0xFF506861);
    final emeraldGreen =
        isDark ? const Color(0xFF34D399) : const Color(0xFF0F766E);
    final amberColor =
        isDark ? const Color(0xFFFFB300) : const Color(0xFFD97706);

    if (debt > 0) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: isDark
              ? const LinearGradient(
                  colors: [Color(0xFF2A2016), Color(0xFF1F1812)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : const LinearGradient(
                  colors: [Color(0xFFFFF9E6), Color(0xFFFFF0C2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: amberColor.withValues(alpha: 0.5),
            width: 1.3,
          ),
          boxShadow: [
            BoxShadow(
              color: amberColor.withValues(alpha: isDark ? 0.15 : 0.08),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: amberColor.withValues(alpha: 0.2),
                    border: Border.all(color: amberColor, width: 1.2),
                  ),
                  child: const Center(
                    child: Text('🕌', style: TextStyle(fontSize: 20)),
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
                            '$debt Tilâvet Secdesi Borcu',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? const Color(0xFFFFDF7A)
                                  : const Color(0xFF8C5400),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: amberColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Vâcip',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Okuduğunuz âyetlerin secdelerini eda etmeyi unutmayınız.',
                        style: TextStyle(
                          fontSize: 12,
                          color: secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Action Row
            Row(
              children: [
                // Eda Ettim (-1) Button
                Expanded(
                  flex: 3,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: emeraldGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.check_circle_outline_rounded,
                        size: 16),
                    label: const Text(
                      'Eda Ettim (-1)',
                      style: TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      HapticService.targetReached();
                      ref
                          .read(tilavetSecdesiDebtProvider.notifier)
                          .decrementDebt(1);
                    },
                  ),
                ),
                const SizedBox(width: 8),

                // Guide button
                Expanded(
                  flex: 2,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor:
                          isDark ? Colors.white : const Color(0xFF1E2B27),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      side: BorderSide(
                        color: isDark ? Colors.white24 : Colors.black26,
                      ),
                    ),
                    onPressed: () {
                      HapticService.tapClick();
                      TilavetSecdesiGuideSheet.show(
                        context,
                        onNavigateToPage: onNavigateToPage,
                      );
                    },
                    child: const Text(
                      'Nasıl Yapılır?',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // When debt is 0, show a sleek subtle quick-access banner
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1D2128) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticService.tapClick();
            TilavetSecdesiGuideSheet.show(
              context,
              onNavigateToPage: onNavigateToPage,
            );
          },
          borderRadius: BorderRadius.circular(18),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: emeraldGreen.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Text('🕌', style: TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tilâvet Secdesi Rehberi & Takibi',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: primaryTextColor,
                      ),
                    ),
                    Text(
                      'Secde borcunuz bulunmuyor • 14 Âyet ve Yapılışı',
                      style:
                          TextStyle(fontSize: 11.5, color: secondaryTextColor),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: secondaryTextColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
