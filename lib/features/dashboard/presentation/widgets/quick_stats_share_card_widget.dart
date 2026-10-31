import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zikirce/core/services/islamic_special_days_service.dart';
import 'package:zikirce/features/zikir/domain/share_card_data_helper.dart';
import 'package:zikirce/features/zikir/presentation/widgets/zikir_share_card_widget.dart';

/// Tahrir Estetiğiyle Yenilenen Minimalist İbadet Özeti Kartı
class QuickStatsShareCardWidget extends StatelessWidget {
  final String todayZikir;
  final String thisWeekZikir;
  final String dailyAvgZikir;
  final String totalZikir;
  final String quranPages;
  final String rankName;
  final String rankBadge;
  final ZikirShareCardFormat format;
  final ZikirShareCardTheme theme;
  final String? specialDayGreeting;
  final SpiritualQuote? quote;

  const QuickStatsShareCardWidget({
    super.key,
    required this.todayZikir,
    required this.thisWeekZikir,
    required this.dailyAvgZikir,
    required this.totalZikir,
    this.quranPages = '0',
    this.rankName = 'Mübtedi',
    this.rankBadge = '🌱',
    this.format = ZikirShareCardFormat.story9x16,
    this.theme = ZikirShareCardTheme.fajrDawn,
    this.specialDayGreeting,
    this.quote,
  });

  double _computeQuoteFontSize(String text, bool isStory) {
    final len = text.length;
    if (len <= 70) return isStory ? 21.0 : 17.5;
    if (len <= 130) return isStory ? 18.5 : 15.5;
    return isStory ? 16.0 : 13.8;
  }

  @override
  Widget build(BuildContext context) {
    final themeData = ZikirShareThemeData.fromEnum(theme);
    final isStory = format == ZikirShareCardFormat.story9x16;
    final activeGreeting = specialDayGreeting ??
        IslamicSpecialDaysService.getSpecialDay()?.greetingTr;
    final activeQuote = quote ?? ShareCardDataHelper.curatedQuotes.first;

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
                  if (activeGreeting != null && activeGreeting.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        activeGreeting.trim(),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: themeData.accentColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),

                  Expanded(
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.center,
                        child: SizedBox(
                          width: canvasWidth - (isStory ? 68.0 : 56.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
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
                                activeQuote.text,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: _computeQuoteFontSize(
                                    activeQuote.text,
                                    isStory,
                                  ),
                                  fontWeight: FontWeight.w600,
                                  color: themeData.primaryTextColor,
                                  height: 1.42,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                activeQuote.source,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(
                                  fontSize: 13.0,
                                  fontWeight: FontWeight.w700,
                                  color: themeData.secondaryTextColor,
                                ),
                              ),
                              SizedBox(height: isStory ? 22 : 14),
                              Container(
                                width: 44,
                                height: 1.5,
                                color:
                                    themeData.accentColor.withValues(alpha: 0.65),
                              ),
                              SizedBox(height: isStory ? 22 : 14),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildCleanStat(
                                    value: todayZikir,
                                    label: 'Bugün',
                                    themeData: themeData,
                                    isStory: isStory,
                                  ),
                                  Container(
                                    width: 1,
                                    height: isStory ? 36 : 28,
                                    color: themeData.borderColor,
                                  ),
                                  _buildCleanStat(
                                    value: thisWeekZikir,
                                    label: 'Bu Hafta',
                                    themeData: themeData,
                                    isStory: isStory,
                                  ),
                                  Container(
                                    width: 1,
                                    height: isStory ? 36 : 28,
                                    color: themeData.borderColor,
                                  ),
                                  _buildCleanStat(
                                    value: totalZikir,
                                    label: 'Toplam',
                                    themeData: themeData,
                                    isStory: isStory,
                                  ),
                                ],
                              ),
                              if (quranPages != '0' && quranPages.isNotEmpty) ...[
                                SizedBox(height: isStory ? 16 : 10),
                                Text(
                                  '$quranPages Sayfa Kur’ân-ı Kerîm Tilaveti',
                                  style: GoogleFonts.outfit(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: themeData.accentColor,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

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

  Widget _buildCleanStat({
    required String value,
    required String label,
    required ZikirShareThemeData themeData,
    required bool isStory,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: isStory ? 22 : 18,
            fontWeight: FontWeight.w800,
            color: themeData.primaryTextColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            color: themeData.secondaryTextColor,
          ),
        ),
      ],
    );
  }
}
