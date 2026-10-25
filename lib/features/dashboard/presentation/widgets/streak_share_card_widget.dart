import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zikirce/features/zikir/presentation/widgets/zikir_share_card_widget.dart';

/// Tahrir Estetiğiyle Yenilenen Minimalist İstikrar Serisi Kartı
class StreakShareCardWidget extends StatelessWidget {
  final int currentStreak;
  final int bestStreak;
  final int totalDays;
  final String rankName;
  final String rankBadge;
  final bool isGoldCompleted;
  final ZikirShareCardFormat format;
  final ZikirShareCardTheme theme;

  const StreakShareCardWidget({
    super.key,
    required this.currentStreak,
    this.bestStreak = 0,
    this.totalDays = 0,
    this.rankName = 'Mübtedi',
    this.rankBadge = '🌱',
    this.isGoldCompleted = false,
    this.format = ZikirShareCardFormat.story9x16,
    this.theme = ZikirShareCardTheme.fajrDawn,
  });

  @override
  Widget build(BuildContext context) {
    final themeData = ZikirShareThemeData.fromEnum(theme);
    final isStory = format == ZikirShareCardFormat.story9x16;

    const double canvasWidth = 400.0;
    final double canvasHeight = isStory ? 711.0 : 400.0;

    return AspectRatio(
      aspectRatio: isStory ? (9 / 16) : 1.0,
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: canvasWidth,
          height: canvasHeight,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                colors: themeData.gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: themeData.borderColor,
                width: 1.6,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isStory ? 34 : 28,
                vertical: isStory ? 32 : 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),

                  Text(
                    '“',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: isStory ? 48 : 38,
                      fontWeight: FontWeight.w700,
                      color: themeData.accentColor,
                      height: 0.75,
                    ),
                  ),
                  SizedBox(height: isStory ? 10 : 6),

                  Text(
                    'Allah katında amellerin en sevimlisi, az da olsa devamlı olanıdır.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: isStory ? 20.5 : 17.0,
                      fontWeight: FontWeight.w600,
                      color: themeData.primaryTextColor,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Buhârî, Rikâk, 18',
                    style: GoogleFonts.outfit(
                      fontSize: 13.0,
                      fontWeight: FontWeight.w700,
                      color: themeData.secondaryTextColor,
                    ),
                  ),

                  SizedBox(height: isStory ? 20 : 12),
                  Container(
                    width: 44,
                    height: 1.5,
                    color: themeData.accentColor.withValues(alpha: 0.65),
                  ),
                  SizedBox(height: isStory ? 20 : 12),

                  Text(
                    '$currentStreak GÜN',
                    style: GoogleFonts.outfit(
                      fontSize: isStory ? 36 : 28,
                      fontWeight: FontWeight.w800,
                      color: themeData.accentColor,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Aralıksız İbadet & Zikir İstikrarı',
                    style: GoogleFonts.outfit(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: themeData.primaryTextColor,
                    ),
                  ),
                  if (bestStreak > 0 || totalDays > 0) ...[
                    const SizedBox(height: 6),
                    Text(
                      'En İyi Seri: $bestStreak Gün  •  Toplam: $totalDays Gün',
                      style: GoogleFonts.outfit(
                        fontSize: 12.0,
                        fontWeight: FontWeight.w500,
                        color: themeData.secondaryTextColor,
                      ),
                    ),
                  ],

                  const Spacer(flex: 2),

                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/images/zikirce_logo.png',
                        width: isStory ? 38 : 34,
                        height: isStory ? 38 : 34,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.medium,
                        isAntiAlias: true,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.auto_awesome_rounded,
                          size: isStory ? 28 : 24,
                          color: themeData.accentColor,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Text(
                        'Zikirce',
                        style: GoogleFonts.outfit(
                          fontSize: isStory ? 16.0 : 14.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: themeData.primaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
