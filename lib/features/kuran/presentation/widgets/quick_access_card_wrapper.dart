import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/quick_access_cards_provider.dart';
import 'quick_access_card_action_sheet.dart';
import 'quick_access_management_sheet.dart';

class QuickAccessCardWrapper extends ConsumerWidget {
  final Widget child;
  final String cardId;
  final String cardTitle;
  final String cardIcon;
  final bool isHatim;
  final String? hatimId;

  const QuickAccessCardWrapper({
    super.key,
    required this.child,
    required this.cardId,
    required this.cardTitle,
    required this.cardIcon,
    this.isHatim = false,
    this.hatimId,
  });

  void _showActionSheet(BuildContext context, WidgetRef ref) {
    QuickAccessCardActionSheet.show(
      context: context,
      ref: ref,
      cardId: cardId,
      cardTitle: cardTitle,
      cardIcon: cardIcon,
      isHatim: isHatim,
      hatimId: hatimId,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(quickAccessCardsProvider);
    final isPinned = state.isPinned(cardId);

    return GestureDetector(
      onLongPress: () => _showActionSheet(context, ref),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          child,

          // Top-Right Controls: Pinned Badge & ••• More Menu Button
          Positioned(
            top: 8,
            right: 8,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isPinned) ...[
                  GestureDetector(
                    onTap: () => _showActionSheet(context, ref),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD56B),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 4,
                            offset: const Offset(0, 1.5),
                          ),
                        ],
                      ),
                      child: const Text(
                        '📌',
                        style: TextStyle(fontSize: 9),
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                ],
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _showActionSheet(context, ref),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.more_horiz_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The end-of-row tile to manage cards
  static Widget buildEndManageTile(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? const Color(0xFFE8DDD0) : const Color(0xFF1E2B27);
    final secondaryTextColor = isDark ? const Color(0xFFA89888) : const Color(0xFF506861);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => QuickAccessManagementSheet.show(context),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 140,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C2028) : const Color(0xFFF3F6F4),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? Colors.white12 : Colors.black12,
              style: BorderStyle.solid,
              width: 1.2,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                ),
                child: const Center(
                  child: Text('⚙️', style: TextStyle(fontSize: 20)),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Kartları Yönet',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: primaryTextColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Text(
                'Gizle / Sabitle',
                style: TextStyle(
                  fontSize: 11,
                  color: secondaryTextColor,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
