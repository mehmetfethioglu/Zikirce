import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
  });

  @override
  Widget build(BuildContext context) {
    final themeData = ZikirShareThemeData.fromEnum(theme);
    final isStory = format == ZikirShareCardFormat.story9x16;

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
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // 1. Ambient Glow and Sufi Semazen Custom Vector Painting
              Positioned.fill(
                child: CustomPaint(
                  painter: SufiDervishPainter(
                    watermarkColor: themeData.watermarkColor,
                    accentColor: themeData.accentColor.withValues(alpha: 0.15),
                    isStoryFormat: isStory,
                  ),
                ),
              ),

              // 2. Subtle Islamic Geometric Star Arches in Corners
              Positioned.fill(
                child: CustomPaint(
                  painter: IslamicPatternPainter(
                    patternColor: themeData.accentColor.withValues(alpha: 0.08),
                  ),
                ),
              ),

              // 3. Foreground Content Structure
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: verticalPadding,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // --- TOP BAR ---
                    _buildHeader(themeData, isStory),

                    if (isStory) const SizedBox(height: 16) else const SizedBox(height: 6),

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
                                width: isStory ? 58 : 46,
                                height: isStory ? 58 : 46,
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
                                  size: isStory ? 30 : 22,
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

                              // Ayet / Quote Subtitle
                              Text(
                                '“Beni anın ki, Ben de sizi anayım.” (Bakara, 152)',
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
        // Zikirce Monogram Icon
        Container(
          width: isStory ? 34 : 28,
          height: isStory ? 34 : 28,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(isStory ? 10 : 8),
            border: Border.all(
              color: themeData.accentColor.withValues(alpha: 0.4),
              width: 1.2,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            '📿',
            style: TextStyle(fontSize: isStory ? 16 : 13),
          ),
        ),

        // Category Tag
        Flexible(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: EdgeInsets.symmetric(
              horizontal: isStory ? 10 : 7,
              vertical: isStory ? 5 : 3,
            ),
            decoration: BoxDecoration(
              color: themeData.badgeBg.withValues(alpha: 0.8),
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
                      fontSize: isStory ? 10 : 8.5,
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

        // Brand Subtitle
        Text(
          'ZİKİRCE',
          style: GoogleFonts.cinzel(
            fontSize: isStory ? 12 : 10,
            fontWeight: FontWeight.w800,
            color: Colors.white.withValues(alpha: 0.85),
            letterSpacing: 1.8,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsMatrix(ZikirShareThemeData themeData, bool isStory) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isStory ? 14 : 10,
        vertical: isStory ? 12 : 6,
      ),
      decoration: BoxDecoration(
        color: themeData.cardBg,
        borderRadius: BorderRadius.circular(isStory ? 18 : 12),
        border: Border.all(
          color: themeData.accentColor.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: Bugün & Bu Hafta
          Row(
            children: [
              Expanded(
                child: _buildMatrixItem(
                  icon: Icons.calendar_today_rounded,
                  iconColor: const Color(0xFF4ADE80),
                  label: 'BUGÜN ZİKİR',
                  value: todayZikir,
                  themeData: themeData,
                  isStory: isStory,
                ),
              ),
              Container(width: 1, height: isStory ? 36 : 24, color: Colors.white12),
              Expanded(
                child: _buildMatrixItem(
                  icon: Icons.date_range_rounded,
                  iconColor: const Color(0xFF38BDF8),
                  label: 'BU HAFTA',
                  value: thisWeekZikir,
                  themeData: themeData,
                  isStory: isStory,
                ),
              ),
            ],
          ),
          Divider(color: Colors.white12, height: isStory ? 16 : 8),

          // Row 2: Günlük Ortalama & Toplam Zikir
          Row(
            children: [
              Expanded(
                child: _buildMatrixItem(
                  icon: Icons.bar_chart_rounded,
                  iconColor: const Color(0xFFFBBF24),
                  label: 'GÜNLÜK ORTALAMA',
                  value: dailyAvgZikir,
                  themeData: themeData,
                  isStory: isStory,
                ),
              ),
              Container(width: 1, height: isStory ? 36 : 24, color: Colors.white12),
              Expanded(
                child: _buildMatrixItem(
                  icon: Icons.all_inclusive_rounded,
                  iconColor: const Color(0xFFC084FC),
                  label: 'TOPLAM ZİKİR',
                  value: totalZikir,
                  themeData: themeData,
                  isStory: isStory,
                  isHighlight: true,
                ),
              ),
            ],
          ),
          Divider(color: Colors.white12, height: isStory ? 16 : 8),

          // Row 3: Kur'an Okuma & Mertebe
          Row(
            children: [
              Expanded(
                child: _buildMatrixItem(
                  icon: Icons.menu_book_rounded,
                  iconColor: const Color(0xFF2DD4BF),
                  label: 'KUR\'AN OKUMA',
                  value: '$quranPages Sayfa',
                  themeData: themeData,
                  isStory: isStory,
                ),
              ),
              Container(width: 1, height: isStory ? 36 : 24, color: Colors.white12),
              Expanded(
                child: _buildMatrixItem(
                  icon: Icons.shield_rounded,
                  iconColor: themeData.accentColor,
                  label: 'MANEVİ MAKAM',
                  value: '$rankBadge $rankName',
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

  Widget _buildMatrixItem({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required ZikirShareThemeData themeData,
    required bool isStory,
    bool isHighlight = false,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isStory ? 8 : 4),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isStory ? 6 : 4),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: isStory ? 15 : 12),
          ),
          SizedBox(width: isStory ? 8 : 5),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isStory ? 8 : 7,
                    fontWeight: FontWeight.w600,
                    color: Colors.white54,
                    letterSpacing: 0.3,
                  ),
                ),
                SizedBox(height: isStory ? 1 : 0.5),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: isStory ? 13 : 11,
                    fontWeight: FontWeight.w700,
                    color: isHighlight ? themeData.accentColor : Colors.white,
                  ),
                ),
              ],
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
        // Spiritual Icon Row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildSpiritualIcon(Icons.volunteer_activism_rounded, isStory),
            SizedBox(width: isStory ? 18 : 12),
            _buildSpiritualIcon(Icons.menu_book_rounded, isStory),
            SizedBox(width: isStory ? 18 : 12),
            _buildSpiritualIcon(Icons.nightlight_round, isStory),
            SizedBox(width: isStory ? 18 : 12),
            _buildSpiritualIcon(Icons.mosque_rounded, isStory),
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
            color: themeData.accentColor.withValues(alpha: 0.6),
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildSpiritualIcon(IconData icon, bool isStory) {
    return Icon(
      icon,
      color: Colors.white.withValues(alpha: 0.5),
      size: isStory ? 16 : 13,
    );
  }
}
