import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../hatim/providers/hatim_providers.dart';
import '../../providers/quick_access_cards_provider.dart';

enum QuickAccessSheetAction {
  togglePin,
  hideCard,
  deleteHatim,
}

class QuickAccessCardActionSheet extends ConsumerWidget {
  final String cardId;
  final String cardTitle;
  final String cardIcon;
  final bool isHatim;
  final String? hatimId;

  const QuickAccessCardActionSheet({
    super.key,
    required this.cardId,
    required this.cardTitle,
    required this.cardIcon,
    this.isHatim = false,
    this.hatimId,
  });

  static Future<void> show({
    required BuildContext context,
    WidgetRef? ref,
    required String cardId,
    required String cardTitle,
    required String cardIcon,
    bool isHatim = false,
    String? hatimId,
  }) async {
    HapticService.selectionClick();
    final action = await showModalBottomSheet<QuickAccessSheetAction>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QuickAccessCardActionSheet(
        cardId: cardId,
        cardTitle: cardTitle,
        cardIcon: cardIcon,
        isHatim: isHatim,
        hatimId: hatimId,
      ),
    );

    if (!context.mounted || action == null) return;

    if (action == QuickAccessSheetAction.deleteHatim) {
      await _showDeleteConfirmation(
        context: context,
        ref: ref,
        cardId: cardId,
        cardTitle: cardTitle,
        hatimId: hatimId,
      );
    } else if (action == QuickAccessSheetAction.hideCard) {
      HapticService.tapClick();
      if (ref != null) {
        ref.read(quickAccessCardsProvider.notifier).hideCard(cardId);
      } else {
        ProviderScope.containerOf(context, listen: false)
            .read(quickAccessCardsProvider.notifier)
            .hideCard(cardId);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Text('👁️‍🗨️ ', style: TextStyle(fontSize: 18)),
                Expanded(
                  child: Text(
                    '"$cardTitle" gizlendi. "Kartları Yönet"ten geri açabilirsiniz.',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF2D7D76),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  static Future<void> _showDeleteConfirmation({
    required BuildContext context,
    required WidgetRef? ref,
    required String cardId,
    required String cardTitle,
    required String? hatimId,
  }) async {
    if (hatimId == null) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF23262F) : Colors.white;
    final primaryTextColor = isDark ? const Color(0xFFE8DDD0) : const Color(0xFF1E2B27);
    final secondaryTextColor = isDark ? const Color(0xFFA89888) : const Color(0xFF506861);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Text('🗑️ ', style: TextStyle(fontSize: 22)),
            Expanded(
              child: Text(
                'Hatmi Sil',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primaryTextColor,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          '"$cardTitle" hatminiz ve bu hatme ait tüm sayfa ilerlemeleri kalıcı olarak silinsin mi?',
          style: TextStyle(fontSize: 14, color: secondaryTextColor, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Vazgeç',
              style: TextStyle(
                color: isDark ? Colors.white60 : Colors.black54,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sil', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      HapticService.targetReached();
      if (ref != null) {
        await ref.read(hatimNotifierProvider).deleteHatim(hatimId);
        if (cardId != 'mukabele_hatim') {
          ref.read(quickAccessCardsProvider.notifier).hideCard(cardId);
        }
      } else if (context.mounted) {
        final container = ProviderScope.containerOf(context, listen: false);
        await container.read(hatimNotifierProvider).deleteHatim(hatimId);
        if (cardId != 'mukabele_hatim') {
          container.read(quickAccessCardsProvider.notifier).hideCard(cardId);
        }
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Text('🗑️ ', style: TextStyle(fontSize: 18)),
                Expanded(
                  child: Text(
                    '"$cardTitle" başarıyla silindi.',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(quickAccessCardsProvider);
    final isPinned = state.isPinned(cardId);

    final sheetBg = isDark ? const Color(0xFF1E2129) : Colors.white;
    final primaryTextColor = isDark ? const Color(0xFFE8DDD0) : const Color(0xFF1E2B27);
    final secondaryTextColor = isDark ? const Color(0xFFA89888) : const Color(0xFF506861);
    final goldAccent = isDark ? const Color(0xFFFFD56B) : const Color(0xFFB57D15);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 16),

            // Card Header Info
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: goldAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(cardIcon, style: const TextStyle(fontSize: 20)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cardTitle,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: primaryTextColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isHatim ? 'Hatim Kartı İşlemleri' : 'Hızlı Erişim Kartı İşlemleri',
                        style: TextStyle(fontSize: 12, color: secondaryTextColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Pin / Unpin Action
            Material(
              color: Colors.transparent,
              child: ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: goldAccent.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    isPinned ? '📍' : '📌',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
                title: Text(
                  isPinned ? 'Baştan Çıkar' : 'Başa Tuttur',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: primaryTextColor,
                  ),
                ),
                subtitle: Text(
                  isPinned
                    ? 'Bu kartı varsayılan sıralamadaki yerine döndürür.'
                    : 'Bu kartı şeridin en başına sabitler.',
                  style: TextStyle(fontSize: 12, color: secondaryTextColor),
                ),
                onTap: () {
                  HapticService.selectionClick();
                  ref.read(quickAccessCardsProvider.notifier).togglePin(cardId);
                  Navigator.of(context).pop();
                },
              ),
            ),
            const SizedBox(height: 8),

            // Delete / Hide Action
            Material(
              color: Colors.transparent,
              child: ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Text('🗑️', style: TextStyle(fontSize: 18)),
                ),
                title: Text(
                  isHatim ? 'Hatmi Sil' : 'Şeritten Gizle',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFDC2626),
                  ),
                ),
                subtitle: Text(
                  isHatim
                      ? 'Bu hatmi ve tüm ilerlemesini kalıcı olarak siler.'
                      : 'Bu kartı ana sayfadan gizler. "Kartları Yönet"ten tekrar açabilirsiniz.',
                  style: TextStyle(fontSize: 12, color: secondaryTextColor),
                ),
                onTap: () {
                  if (isHatim) {
                    Navigator.of(context).pop(QuickAccessSheetAction.deleteHatim);
                  } else {
                    Navigator.of(context).pop(QuickAccessSheetAction.hideCard);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
