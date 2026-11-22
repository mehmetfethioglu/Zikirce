import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../../core/services/prayer_times_service.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../domain/qibla_math.dart';
import '../../providers/prayer_providers.dart';
import '../screens/qibla_compass_screen.dart';

/// Namaz Vakitleri ekranındaki sıfır sensör maliyetli, şehir tabanlı 3B Kıble Bulucu kartı.
class QiblaFinderCard extends ConsumerWidget {
  final VoidCallback? onTap;

  const QiblaFinderCard({super.key, this.onTap});

  static String formatKm(double km, {required bool isTurkish}) {
    final rounded = km.round();
    final str = rounded.toString();
    final sep = isTurkish ? '.' : ',';
    final buf = StringBuffer();
    for (var i = 0; i < str.length; i++) {
      final revIdx = str.length - i;
      if (i > 0 && revIdx % 3 == 0) {
        buf.write(sep);
      }
      buf.write(str[i]);
    }
    return '${buf.toString()} km';
  }

  void _openQibla(BuildContext context) {
    if (onTap != null) {
      onTap!();
      return;
    }
    HapticService.selectionClick();
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      router.push('/qibla');
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const QiblaCompassScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = context.l10n;
    final isTr = l10n.isTurkish;
    final city = ref.watch(selectedCityProvider);

    final coords = PrayerTimesService.cityCoordinates[city] ??
        PrayerTimesService.cityCoordinates['İstanbul'] ??
        (41.0082, 28.9784);

    final bearing = QiblaMath.calculateQiblaBearing(coords.$1, coords.$2);
    final distanceKm = QiblaMath.calculateDistanceToKaabaKm(coords.$1, coords.$2);
    final cardinal = QiblaMath.cardinalDirectionLabel(bearing, isTurkish: isTr);
    final summaryLine =
        '$city • ${bearing.round()}° $cardinal • ${formatKm(distanceKm, isTurkish: isTr)}';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const Key('qibla_finder_card'),
        onTap: () => _openQibla(context),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                colors.cardBackground,
                colors.accent.withValues(alpha: 0.09),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colors.accent.withValues(alpha: 0.28),
              width: 1,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                offset: const Offset(0, 2),
                blurRadius: 8,
              ),
            ],
          ),
          child: Row(
            children: <Widget>[
              _MiniKaabaBadge(accentColor: colors.accent),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l10n.qibla3DTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: colors.primaryText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.qiblaCardSubtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: colors.secondaryTextAlt,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: colors.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        summaryLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: colors.accentText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: colors.accent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      l10n.qiblaFindAction,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.explore_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniKaabaBadge extends StatelessWidget {
  final Color accentColor;

  const _MiniKaabaBadge({required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: const Color(0xFFD4A574).withValues(alpha: 0.45),
          width: 1,
        ),
      ),
      alignment: Alignment.center,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Icon(
            Icons.explore_outlined,
            size: 38,
            color: accentColor.withValues(alpha: 0.25),
          ),
          // Mini stilize Kâbe küpü
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: const Color(0xFF1B1E23),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: const Color(0xFFD4A574),
                width: 1.2,
              ),
            ),
            child: Column(
              children: <Widget>[
                const SizedBox(height: 4),
                Container(
                  height: 3,
                  width: double.infinity,
                  color: const Color(0xFFE5B84B),
                ),
                const Spacer(),
                Container(
                  width: 5,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF3C65F),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(1.5),
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
}
