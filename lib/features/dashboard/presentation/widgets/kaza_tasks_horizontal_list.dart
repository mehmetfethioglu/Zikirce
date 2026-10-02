import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/constants/asset_constants.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../namaz_vakitleri/providers/prayer_providers.dart';

class KazaTasksHorizontalList extends ConsumerWidget {
  final Function(String prayerName, int count)? onTaskTap;

  const KazaTasksHorizontalList({
    super.key,
    this.onTaskTap,
  });

  static final List<Map<String, dynamic>> _taskDefinitions = [
    {
      'titleTr': 'Oruç',
      'titleEn': 'Fasting',
      'prayerKey': 'Oruç',
      'asset': '',
      'icon': Icons.nightlight_round,
    },
    {
      'titleTr': 'Sabah',
      'titleEn': 'Fajr',
      'prayerKey': 'Sabah',
      'asset': AppAssets.icNamazSabah,
      'icon': Icons.wb_twilight_rounded,
    },
    {
      'titleTr': 'Öğle',
      'titleEn': 'Dhuhr',
      'prayerKey': 'Öğle',
      'asset': AppAssets.icNamazOgle,
      'icon': Icons.wb_sunny_rounded,
    },
    {
      'titleTr': 'İkindi',
      'titleEn': 'Asr',
      'prayerKey': 'İkindi',
      'asset': AppAssets.icNamazIkindi,
      'icon': Icons.wb_sunny_outlined,
    },
    {
      'titleTr': 'Akşam',
      'titleEn': 'Maghrib',
      'prayerKey': 'Akşam',
      'asset': AppAssets.icNamazAksam,
      'icon': Icons.nights_stay_rounded,
    },
    {
      'titleTr': 'Yatsı',
      'titleEn': 'Isha',
      'prayerKey': 'Yatsı',
      'asset': AppAssets.icNamazYatsi,
      'icon': Icons.bedtime_rounded,
    },
    {
      'titleTr': 'Vitir',
      'titleEn': 'Witr',
      'prayerKey': 'Vitir',
      'asset': AppAssets.icNamazVitir,
      'icon': Icons.star_rounded,
    },
  ];

  String _formatCount(int number) {
    if (number >= 10000) {
      final val = number / 1000.0;
      return '${val.toStringAsFixed(1).replaceAll('.', ',')}k';
    }
    return number.toString();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final kazaListAsync = ref.watch(kazaPrayersStreamProvider);
    final kazaList = kazaListAsync.valueOrNull ?? [];
    final kazaMap = {for (final k in kazaList) k.prayerType: k.totalCount};
    final totalKaza = kazaMap.values.fold<int>(0, (sum, count) => sum + count);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.bismillahTasksTitle,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.bold,
                color: colors.primaryText,
                letterSpacing: -0.2,
              ),
            ),
            if (totalKaza > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: isDark ? 0.18 : 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: colors.accent.withValues(alpha: 0.25),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  l10n.isTurkish ? 'Toplam $totalKaza Kaza' : '$totalKaza Total',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: colors.accent,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 102,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _taskDefinitions.length,
            separatorBuilder: (_, __) => const SizedBox(width: 9),
            itemBuilder: (context, index) {
              final task = _taskDefinitions[index];
              final title = l10n.isTurkish ? task['titleTr']! : task['titleEn']!;
              final prayerKey = task['prayerKey'] as String;
              final count = kazaMap[prayerKey] ?? 0;
              final svgAsset = task['asset'] as String;
              final fallbackIcon = task['icon'] as IconData;

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onTaskTap?.call(prayerKey, count),
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    width: 84,
                    height: 102,
                    decoration: BoxDecoration(
                      color: colors.cardBackground,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: count > 0
                            ? colors.accent.withValues(alpha: isDark ? 0.3 : 0.22)
                            : colors.borderStroke,
                        width: count > 0 ? 1.0 : 0.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Icon badge
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: count > 0
                                ? colors.accent.withValues(alpha: isDark ? 0.18 : 0.1)
                                : colors.secondaryTextAlt.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: svgAsset.isNotEmpty
                              ? SvgPicture.asset(
                                  svgAsset,
                                  width: 18,
                                  height: 18,
                                  colorFilter: ColorFilter.mode(
                                    count > 0 ? colors.accent : colors.secondaryText,
                                    BlendMode.srcIn,
                                  ),
                                  placeholderBuilder: (_) => Icon(
                                    fallbackIcon,
                                    size: 18,
                                    color: count > 0 ? colors.accent : colors.secondaryText,
                                  ),
                                )
                              : Icon(
                                  fallbackIcon,
                                  size: 18,
                                  color: count > 0 ? colors.accent : colors.secondaryText,
                                ),
                        ),

                        // Title
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: colors.primaryText,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),

                        // Theme-Harmonized Count Pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: count > 0
                                ? colors.accent.withValues(alpha: isDark ? 0.2 : 0.12)
                                : (isDark ? const Color(0xFF10B981) : const Color(0xFF059669))
                                    .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(
                              color: count > 0
                                  ? colors.accent.withValues(alpha: 0.3)
                                  : (isDark ? const Color(0xFF10B981) : const Color(0xFF059669))
                                      .withValues(alpha: 0.25),
                              width: 0.6,
                            ),
                          ),
                          child: count > 0
                              ? Text(
                                  _formatCount(count),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: colors.accent,
                                  ),
                                  maxLines: 1,
                                )
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.check_rounded,
                                      size: 10,
                                      color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      '0',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

