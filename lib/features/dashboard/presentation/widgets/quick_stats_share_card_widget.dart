import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zikirce/core/services/islamic_special_days_service.dart';
import 'package:zikirce/features/zikir/presentation/widgets/zikir_share_card_widget.dart';

/// Visual Share Card for Quick Stats & Spiritual Summary (İbadet Karnesi & Özet)
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
    this.theme = ZikirShareCardTheme.emeraldSufi,
    this.specialDayGreeting,
  });

  @override
  Widget build(BuildContext context) {
    final themeData = ZikirShareThemeData.fromEnum(theme);
    final isStory = format == ZikirShareCardFormat.story9x16;
    final activeGreeting = specialDayGreeting ?? IslamicSpecialDaysService.getSpecialDay()?.greetingTr;

    // Fixed base logical coordinates for ultra crisp scaling
    const double baseWidth = 400;
    final double baseHeight = isStory ? (400 * 16 / 9) : 400;
    final double horizontalPadding = isStory ? 24 : 18;
    final double verticalPadding = isStory ? 28 : 16;

    return FittedBox(
      fit: BoxFit.contain,
      alignment: Alignment.center,
      child: SizedBox(
        width: baseWidth,
        height: baseHeight,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(isStory ? 32 : 24),
            gradient: LinearGradient(
              colors: themeData.gradientColors,
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // 1. Classical Pointed Mihrap Arch
              Positioned.fill(
                child: CustomPaint(
                  painter: IslamicArchPainter(
                    archColor: themeData.accentColor.withValues(alpha: 0.12),
                    isStoryFormat: isStory,
                  ),
                ),
              ),

              // 2. Ambient Glow and Sufi Semazen Custom Vector Painting
              Positioned.fill(
                child: CustomPaint(
                  painter: SufiDervishPainter(
                    watermarkColor: themeData.watermarkColor,
                    accentColor: themeData.accentColor.withValues(alpha: 0.15),
                    isStoryFormat: isStory,
                  ),
                ),
              ),

              // 3. Subtle Islamic Geometric Star Arches in Corners
              Positioned.fill(
                child: CustomPaint(
                  painter: IslamicPatternPainter(
                    patternColor: themeData.accentColor.withValues(alpha: 0.08),
                  ),
                ),
              ),

              // 4. Foreground Content Structure
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: verticalPadding,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // --- TOP BAR: Official Zikirce Logo & Tag ---
                    _buildHeader(themeData, isStory),

                    // --- SPECIAL DAY GREETING (Varsa Özel Gün Tebriği) ---
                    if (activeGreeting != null && activeGreeting.trim().isNotEmpty)
                      _buildSpecialDayGreetingBanner(activeGreeting.trim(), themeData, isStory),

                    if (isStory) const SizedBox(height: 14) else const SizedBox(height: 6),

                    // --- CENTER BODY: Summary Title, Ayet & Stats Matrix ---
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          physics: const NeverScrollableScrollPhysics(),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Hero Chart Icon
                              Container(
                                width: isStory ? 56 : 44,
                                height: isStory ? 56 : 44,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.black.withValues(alpha: 0.35),
                                  border: Border.all(
                                    color: themeData.accentColor.withValues(alpha: 0.5),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: themeData.accentColor.withValues(alpha: 0.25),
                                      blurRadius: 16,
                                    ),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.insights_rounded,
                                  color: themeData.accentColor,
                                  size: isStory ? 28 : 22,
                                ),
                              ),

                              SizedBox(height: isStory ? 10 : 4),

                              // Title
                              Text(
                                'İBADET VE ZİKİR ÖZETİ',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(
                                  fontSize: isStory ? 21 : 16,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 1.2,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withValues(alpha: 0.7),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),

                              SizedBox(height: isStory ? 6 : 2),

                              // Sacred Ayet with Source
                              Text(
                                '“Beni anın ki, Ben de sizi anayım.” (Bakara Sûresi, 152)',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(
                                  fontSize: isStory ? 11.5 : 9.5,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontStyle: FontStyle.italic,
                                ),
                              ),

                              SizedBox(height: isStory ? 14 : 8),

                              // Stats Matrix (2 columns x 3 rows)
                              _buildStatsMatrix(themeData, isStory),
                            ],
                          ),
                        ),
                      ),
                    ),

                    if (isStory) const SizedBox(height: 10) else const SizedBox(height: 4),

                    // --- FOOTER ---
                    _buildFooter(themeData, isStory),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ZikirShareThemeData themeData, bool isStory) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Official Zikirce Logo Badge
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: isStory ? 8 : 6,
            vertical: isStory ? 4 : 3,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(isStory ? 12 : 9),
            border: Border.all(
              color: themeData.accentColor.withValues(alpha: 0.45),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: themeData.accentColor.withValues(alpha: 0.2),
                blurRadius: 10,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset(
                  'assets/images/zikirce_logo.png',
                  width: isStory ? 24 : 18,
                  height: isStory ? 24 : 18,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Text('📿', style: TextStyle(fontSize: isStory ? 16 : 13)),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'ZİKİRCE',
                style: GoogleFonts.cinzel(
                  fontSize: isStory ? 11 : 9.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white.withValues(alpha: 0.95),
                  letterSpacing: 1.8,
                ),
              ),
            ],
          ),
        ),

        // Category Tag
        Flexible(
          child: Container(
            margin: const EdgeInsets.only(left: 8),
            padding: EdgeInsets.symmetric(
              horizontal: isStory ? 10 : 7,
              vertical: isStory ? 5 : 3,
            ),
            decoration: BoxDecoration(
              color: themeData.badgeBg.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: themeData.badgeBorder.withValues(alpha: 0.6),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    'İBADET KARNESİ',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: isStory ? 9.5 : 8,
                      fontWeight: FontWeight.w700,
                      color: themeData.accentColor,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  width: 3.5,
                  height: 3.5,
                  decoration: BoxDecoration(
                    color: themeData.accentColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSpecialDayGreetingBanner(String greeting, ZikirShareThemeData themeData, bool isStory) {
    return Container(
      margin: EdgeInsets.only(top: isStory ? 10 : 5),
      padding: EdgeInsets.symmetric(
        horizontal: isStory ? 16 : 12,
        vertical: isStory ? 6 : 4,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            themeData.accentColor.withValues(alpha: 0.15),
            themeData.accentColor.withValues(alpha: 0.35),
            themeData.accentColor.withValues(alpha: 0.15),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: themeData.accentColor.withValues(alpha: 0.65),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: themeData.accentColor.withValues(alpha: 0.25),
            blurRadius: 16,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('✨', style: TextStyle(fontSize: isStory ? 13 : 10)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              greeting.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontSize: isStory ? 11.5 : 9.5,
                fontWeight: FontWeight.w800,
                color: themeData.accentColor,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text('✨', style: TextStyle(fontSize: isStory ? 13 : 10)),
        ],
      ),
    );
  }

  Widget _buildStatsMatrix(ZikirShareThemeData themeData, bool isStory) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isStory ? 14 : 10,
        vertical: isStory ? 12 : 8,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: Today & This Week
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  label: 'BUGÜN ZİKİR',
                  value: todayZikir,
                  icon: Icons.today_rounded,
                  themeData: themeData,
                  isStory: isStory,
                  isHighlight: true,
                ),
              ),
              Container(width: 1, height: isStory ? 36 : 28, color: Colors.white12),
              Expanded(
                child: _buildMetricTile(
                  label: 'BU HAFTA',
                  value: thisWeekZikir,
                  icon: Icons.calendar_view_week_rounded,
                  themeData: themeData,
                  isStory: isStory,
                ),
              ),
            ],
          ),

          Padding(
            padding: EdgeInsets.symmetric(vertical: isStory ? 8 : 4),
            child: const Divider(color: Colors.white10, height: 1),
          ),

          // Row 2: Daily Avg & Total
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  label: 'GÜNLÜK ORTALAMA',
                  value: dailyAvgZikir,
                  icon: Icons.query_builder_rounded,
                  themeData: themeData,
                  isStory: isStory,
                ),
              ),
              Container(width: 1, height: isStory ? 36 : 28, color: Colors.white12),
              Expanded(
                child: _buildMetricTile(
                  label: 'TOPLAM ZİKİR',
                  value: totalZikir,
                  icon: Icons.all_inclusive_rounded,
                  themeData: themeData,
                  isStory: isStory,
                  isHighlight: true,
                ),
              ),
            ],
          ),

          Padding(
            padding: EdgeInsets.symmetric(vertical: isStory ? 8 : 4),
            child: const Divider(color: Colors.white10, height: 1),
          ),

          // Row 3: Quran Reading & Spiritual Rank
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  label: 'KUR\'AN OKUMA',
                  value: '$quranPages Sayfa',
                  icon: Icons.menu_book_rounded,
                  themeData: themeData,
                  isStory: isStory,
                ),
              ),
              Container(width: 1, height: isStory ? 36 : 28, color: Colors.white12),
              Expanded(
                child: _buildMetricTile(
                  label: 'MANEVİ MAKÂM',
                  value: '$rankBadge $rankName',
                  icon: Icons.stars_rounded,
                  themeData: themeData,
                  isStory: isStory,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required IconData icon,
    required ZikirShareThemeData themeData,
    required bool isStory,
    bool isHighlight = false,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isStory ? 8 : 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: isStory ? 10 : 8.5, color: Colors.white38),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isStory ? 8 : 6.8,
                    fontWeight: FontWeight.w600,
                    color: Colors.white54,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isStory ? 2 : 1),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(
              fontSize: isStory ? 14 : 11,
              fontWeight: FontWeight.w700,
              color: isHighlight ? themeData.accentColor : Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(ZikirShareThemeData themeData, bool isStory) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildSpiritualIcon(Icons.volunteer_activism_rounded, themeData, isStory),
            SizedBox(width: isStory ? 18 : 12),
            _buildSpiritualIcon(Icons.menu_book_rounded, themeData, isStory),
            SizedBox(width: isStory ? 18 : 12),
            _buildSpiritualIcon(Icons.nightlight_round, themeData, isStory),
            SizedBox(width: isStory ? 18 : 12),
            _buildSpiritualIcon(Icons.mosque_rounded, themeData, isStory),
          ],
        ),
        SizedBox(height: isStory ? 8 : 4),
        Text(
          '“Kalpler ancak Allah’ı anmakla huzur bulur.” (Ra’d, 28)',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontSize: isStory ? 10 : 8.5,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.75),
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 1.5),
        Text(
          'Zikirce — İslâmî Yaşam ve Zikir Asistanı',
          style: TextStyle(
            fontSize: isStory ? 9 : 7.5,
            color: themeData.accentColor.withValues(alpha: 0.65),
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildSpiritualIcon(IconData icon, ZikirShareThemeData themeData, bool isStory) {
    return Icon(
      icon,
      color: Colors.white.withValues(alpha: 0.5),
      size: isStory ? 16 : 13,
    );
  }
}
