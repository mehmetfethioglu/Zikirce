import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../hatim/providers/hatim_providers.dart';
import '../../providers/quick_access_cards_provider.dart';
import '../../../gamification/providers/gamification_providers.dart';

class QuickAccessManagementSheet extends ConsumerWidget {
  const QuickAccessManagementSheet({super.key});

  static Future<void> show(BuildContext context) {
    HapticService.tapClick();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const QuickAccessManagementSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardState = ref.watch(quickAccessCardsProvider);
    final hatimsAsync = ref.watch(hatimListStreamProvider);
    final activeMukabeleAsync = ref.watch(activeMukabeleHatimProvider);
    final customBadgesAsync = ref.watch(customBadgesProvider);
    final customBadges = customBadgesAsync.valueOrNull ?? [];

    final sheetBg = isDark ? const Color(0xFF181B20) : const Color(0xFFF9FBF9);
    final cardBg = isDark ? const Color(0xFF22262E) : Colors.white;
    final primaryTextColor = isDark ? const Color(0xFFE8DDD0) : const Color(0xFF1E2B27);
    final secondaryTextColor = isDark ? const Color(0xFFA89888) : const Color(0xFF506861);
    final emeraldGreen = isDark ? const Color(0xFF34D399) : const Color(0xFF0F766E);
    final goldAccent = isDark ? const Color(0xFFFFD56B) : const Color(0xFFB57D15);

    // Build the list of all manageable cards
    final List<({String id, String title, String icon, bool isHatim})> allCards = [];

    // 1. Mukabele
    final mukabele = activeMukabeleAsync.valueOrNull;
    if (mukabele != null && !mukabele.isCompleted) {
      allCards.add((id: 'mukabele_hatim', title: 'Mukabele: ${mukabele.title}', icon: '🕌', isHatim: true));
    } else {
      allCards.add((id: 'mukabele_hatim', title: 'Mukabele Hatmi Başlat', icon: '🕌', isHatim: false));
    }

    // 2. Active Personal Hatims
    final hatims = hatimsAsync.valueOrNull ?? [];
    final activeHatims = hatims.where((h) => !h.isCompleted && h.completedPages < 604).toList();
    if (activeHatims.isNotEmpty) {
      for (final h in activeHatims) {
        allCards.add((id: 'hatim_${h.id}', title: 'Hatim: ${h.title}', icon: '👤', isHatim: true));
      }
    } else {
      allCards.add((id: 'hatim_empty', title: 'Yeni Hatim Başlat', icon: '👤', isHatim: false));
    }

    // 3. System Cards
    allCards.add((id: 'card_dynamic_surah', title: 'Günün Sûresi (Dinamik)', icon: '📖', isHatim: false));
    allCards.add((id: 'card_shortcut', title: 'Hızlı Kısayol Kartı', icon: '✨', isHatim: false));
    allCards.add((id: 'card_streak_waqiah', title: 'Vâkıa Sûresi (40 Okuma)', icon: '🌿', isHatim: false));
    allCards.add((id: 'card_streak_mulk', title: 'Mülk Sûresi (40 Okuma)', icon: '🌌', isHatim: false));
    allCards.add((id: 'card_streak_naba', title: 'Nebe Sûresi (40 Okuma)', icon: '🌅', isHatim: false));
    allCards.add((id: 'card_streak_yasin', title: 'Yâsîn Sûresi (40 Okuma)', icon: '💚', isHatim: false));
    allCards.add((id: 'card_streak_fetih', title: 'Fetih Sûresi (40 Okuma)', icon: '🗡️', isHatim: false));
    allCards.add((id: 'card_streak_rahman', title: 'Rahmân Sûresi (40 Okuma)', icon: '🌸', isHatim: false));
    allCards.add((id: 'card_streak_kehf', title: 'Kehf Sûresi (40 Okuma)', icon: '⛰️', isHatim: false));

    // 4. Custom Quran Badges (Kullanıcının Özel Rozetleri)
    for (final b in customBadges) {
      allCards.add((
        id: 'custom_badge_${b.id}',
        title: '${b.title} (${b.scopeDisplayName})',
        icon: b.iconEmoji,
        isHatim: false,
      ));
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
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
          children: [
            // Handle Bar
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Container(
                width: 44,
                height: 4.5,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: emeraldGreen.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Text('⚙️', style: TextStyle(fontSize: 20)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hızlı Erişim Kartlarını Yönet',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: primaryTextColor,
                          ),
                        ),
                        Text(
                          'Kartları başa tutturun veya şeritten gizleyin',
                          style: TextStyle(fontSize: 12, color: secondaryTextColor),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: secondaryTextColor),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // List of Manageable Cards
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                physics: const BouncingScrollPhysics(),
                itemCount: allCards.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final card = allCards[index];
                  final isPinned = cardState.isPinned(card.id);
                  final isHidden = cardState.isHidden(card.id);

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isPinned
                            ? goldAccent.withValues(alpha: 0.6)
                            : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06)),
                        width: isPinned ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Icon
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white10 : const Color(0xFFF1F5F2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(card.icon, style: const TextStyle(fontSize: 18)),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Title & Status
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                card.title,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isHidden ? secondaryTextColor : primaryTextColor,
                                  decoration: isHidden ? TextDecoration.lineThrough : null,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  if (isPinned) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: goldAccent.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '📌 Başa Tutturuldu',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: goldAccent,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  Text(
                                    isHidden ? 'Gizlendi' : 'Şeritte Görünür',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isHidden ? const Color(0xFFDC2626) : emeraldGreen,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Action 1: Pin Button
                        IconButton(
                          icon: Icon(
                            isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                            color: isPinned ? goldAccent : secondaryTextColor,
                            size: 22,
                          ),
                          tooltip: isPinned ? 'Baştan Çıkar' : 'Başa Tuttur',
                          onPressed: () {
                            HapticService.selectionClick();
                            ref.read(quickAccessCardsProvider.notifier).togglePin(card.id);
                          },
                        ),

                        // Action 2: Hide / Show Eye Button
                        IconButton(
                          icon: Icon(
                            isHidden ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                            color: isHidden ? const Color(0xFFDC2626) : emeraldGreen,
                            size: 22,
                          ),
                          tooltip: isHidden ? 'Şeritte Göster' : 'Şeritten Gizle',
                          onPressed: () {
                            HapticService.tapClick();
                            if (isHidden) {
                              ref.read(quickAccessCardsProvider.notifier).showCard(card.id);
                            } else {
                              ref.read(quickAccessCardsProvider.notifier).hideCard(card.id);
                            }
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Bottom Reset Button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    side: BorderSide(color: isDark ? Colors.white24 : Colors.black26),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text(
                    'Varsayılan Sıralama ve Görünüme Sıfırla',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () async {
                    HapticService.selectionClick();
                    await ref.read(quickAccessCardsProvider.notifier).resetToDefault();
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Kart sıralaması ve görünümü varsayılana sıfırlandı.'),
                          behavior: SnackBarBehavior.floating,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
