import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../providers/prayer_providers.dart';
import '../../../../core/database/app_database.dart';

class KazaManagerSheet extends ConsumerWidget {
  const KazaManagerSheet({super.key});

  static const List<String> prayerTypes = [
    'Oruç',
    'Sabah',
    'Öğle',
    'İkindi',
    'Akşam',
    'Yatsı',
    'Vitir',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final kazaListAsync = ref.watch(kazaPrayersStreamProvider);
    final kazaNotifier = ref.read(kazaNotifierProvider);
    final summary = ref.watch(kazaSummaryProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        bottom: true,
        child: Column(
          children: [
          const SizedBox(height: 12),
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: colors.secondaryTextAlt.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kaza Namazı Ayarları',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: colors.primaryText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Kaza borçlarınızı düzenleyin ve takip edin',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.secondaryTextAlt,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close_rounded, color: colors.secondaryTextAlt),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Quick Summary Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: colors.pageBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.borderStroke),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text(
                        '${summary.totalCompleted}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Kılınan Kaza',
                        style: TextStyle(fontSize: 11, color: colors.secondaryTextAlt),
                      ),
                    ],
                  ),
                  Container(width: 1, height: 32, color: colors.borderStroke),
                  Column(
                    children: [
                      Text(
                        '${summary.totalRemaining}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A237E),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Kalan Kaza',
                        style: TextStyle(fontSize: 11, color: colors.secondaryTextAlt),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Prayer Type Items
          Expanded(
            child: kazaListAsync.when(
              data: (list) {
                final Map<String, KazaPrayer> map = {
                  for (final item in list) item.prayerType: item,
                };

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  physics: const BouncingScrollPhysics(),
                  itemCount: prayerTypes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, idx) {
                    final pName = prayerTypes[idx];
                    final kaza = map[pName];
                    final count = kaza?.totalCount ?? 0;

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: colors.cardBackground,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colors.borderStroke),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: colors.accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              _getPrayerIcon(pName),
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  pName,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: colors.primaryText,
                                  ),
                                ),
                                Text(
                                  pName == 'Oruç' ? '$count gün kaza borcu' : '$count kaza borcu',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colors.secondaryTextAlt,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Decrement
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline_rounded, size: 24),
                            color: colors.secondaryTextAlt,
                            onPressed: count > 0
                                ? () => kazaNotifier.adjustKaza(pName, -1)
                                : null,
                          ),
                          // Count badge
                          InkWell(
                            onTap: () => _showEditDialog(context, pName, count, kazaNotifier),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              constraints: const BoxConstraints(minWidth: 44),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: colors.pageBackground,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: colors.borderStroke),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '$count',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: colors.primaryText,
                                ),
                              ),
                            ),
                          ),
                          // Increment
                          IconButton(
                            icon: Icon(Icons.add_circle_rounded, size: 24, color: colors.accent),
                            onPressed: () => kazaNotifier.adjustKaza(pName, 1),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Hata: $e')),
            ),
          ),
        ],
      ),
    ),
  );
}

  static String _getPrayerIcon(String name) {
    switch (name) {
      case 'Oruç':
        return '🌙';
      case 'Sabah':
        return '🌅';
      case 'Öğle':
        return '☀️';
      case 'İkindi':
        return '⛅';
      case 'Akşam':
        return '🌆';
      case 'Yatsı':
        return '🌃';
      case 'Vitir':
        return '✨';
      default:
        return '🕌';
    }
  }

  void _showEditDialog(BuildContext context, String prayerName, int current, KazaNotifier notifier) {
    final controller = TextEditingController(text: current.toString());
    final isOruc = prayerName == 'Oruç';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isOruc ? 'Oruç Kazası (Gün)' : '$prayerName Kaza Sayısı'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            labelText: isOruc ? 'Kaza Gün Sayısı' : 'Kaza Adedi',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = int.tryParse(controller.text);
              if (val != null) {
                notifier.setKazaCount(prayerName, val);
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }
}
