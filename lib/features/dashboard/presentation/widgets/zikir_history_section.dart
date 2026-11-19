import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../providers/dashboard_providers.dart';

class ZikirHistorySection extends ConsumerWidget {
  const ZikirHistorySection({super.key});

  void _showHistoryDetailModal(
    BuildContext context,
    DynamicZikirHistoryItem item,
  ) {
    final colors = context.colors;
    final l10n = context.l10n;

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colors.bottomSheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            bottom: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.borderStroke,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: colors.primaryText,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: colors.totalBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        item.count,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: colors.accent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  item.date,
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.secondaryTextAlt,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.isTurkish
                      ? 'Bu zikir kaydı yerel veritabanında ve bulut yedeklemesinde güvenle saklanmaktadır.'
                      : 'This dhikr record is safely stored in local database and cloud backup.',
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.4,
                    color: colors.primaryText,
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = context.l10n;
    final historyListAsync = ref.watch(zikirHistoryListProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.history_rounded,
              size: 20,
              color: colors.accent,
            ),
            const SizedBox(width: 8),
            Text(
              l10n.bismillahHistoryTitle,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: colors.primaryText,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        historyListAsync.when(
          data: (items) {
            if (items.isEmpty) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 20,
                ),
                decoration: BoxDecoration(
                  color: colors.cardBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.borderStroke),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.history_toggle_off_rounded,
                        size: 32,
                        color: colors.secondaryTextAlt,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.isTurkish
                            ? 'Henüz zikir geçmişi bulunmuyor.\nZikir çektikçe burada otomatik listelenecektir.'
                            : 'No dhikr history yet.\nYour dhikrs will be automatically listed here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: colors.secondaryTextAlt,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Column(
              children: items.map((item) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    onTap: () => _showHistoryDetailModal(context, item),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: colors.cardBackground,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colors.borderStroke),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: colors.primaryText,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  item.date,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: colors.secondaryTextAlt,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  l10n.isTurkish
                                      ? 'Detaylar için dokunun ->'
                                      : 'Tap for details ->',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    color: colors.secondaryTextAlt.withValues(
                                      alpha: 0.6,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: colors.totalBg,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              item.count,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: colors.accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}
