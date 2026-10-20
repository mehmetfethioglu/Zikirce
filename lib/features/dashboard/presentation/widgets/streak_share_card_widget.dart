import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zikirce/features/zikir/presentation/widgets/zikir_share_card_widget.dart';

/// Visual Share Card for User Streak (Gün Serisi / İbadet Serisi)
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

                    // --- CENTER BODY: Flame, Streak Count, Rank & Hadith Card ---
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          physics: const NeverScrollableScrollPhysics(),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Hero Fire / Star Circle Icon
                              Container(
                                width: isStory ? 74 : 54,
                                height: isStory ? 74 : 54,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: isGoldCompleted
                                        ? [const Color(0xFFFDE047), const Color(0xFFEAB308)]
                                        : [const Color(0xFFFF8A65), const Color(0xFFFF5722)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (isGoldCompleted ? const Color(0xFFEAB308) : Colors.orange)
                                          .withValues(alpha: 0.4),
                                      blurRadius: 20,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  isGoldCompleted ? '🌟' : '🔥',
                                  style: TextStyle(fontSize: isStory ? 36 : 26),
                                ),
                              ),

                              SizedBox(height: isStory ? 10 : 4),

                              // Streak Number & Title
                              Text(
                                isGoldCompleted
                                    ? 'ALTIN GÜN • $currentStreak GÜNLÜK SERİ'
                                    : '$currentStreak GÜNLÜK İBADET SERİSİ',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(
                                  fontSize: isStory ? 22 : 17,
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

                              SizedBox(height: isStory ? 6 : 3),

                              // Spiritual Rank Pill
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isStory ? 12 : 8,
                                  vertical: isStory ? 4 : 2.5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: themeData.accentColor.withValues(alpha: 0.5),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(rankBadge, style: TextStyle(fontSize: isStory ? 13 : 11)),
                                    const SizedBox(width: 5),
                                    Text(
                                      'Makam: $rankName',
                                      style: TextStyle(
                                        fontSize: isStory ? 11.5 : 10,
                                        fontWeight: FontWeight.bold,
                                        color: themeData.accentColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              SizedBox(height: isStory ? 14 : 8),

                              // Motivational Hadith Card
                              _buildHadithCard(themeData, isStory),

                              SizedBox(height: isStory ? 12 : 6),

                              // Stats Capsule (Active Streak, Best Streak, Total Days)
                              _buildStatsCapsule(themeData, isStory),
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
        // Zikirce Monogram & Logo (High Visibility)
        Container(
          width: isStory ? 44 : 36,
          height: isStory ? 44 : 36,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(isStory ? 12 : 10),
            border: Border.all(
              color: themeData.accentColor.withValues(alpha: 0.7),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: themeData.accentColor.withValues(alpha: 0.35),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Image.asset(
            'assets/images/zikirce_logo.png',
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Text(
              '📿',
              style: TextStyle(fontSize: isStory ? 18 : 15),
            ),
          ),
        ),

        // Category Tag (Purified from Task/Goal wording)
        Flexible(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: EdgeInsets.symmetric(
              horizontal: isStory ? 11 : 8,
              vertical: isStory ? 5 : 3.5,
            ),
            decoration: BoxDecoration(
              color: themeData.badgeBg.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: themeData.badgeBorder.withValues(alpha: 0.7),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    'İBADET SERİSİ',
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
            fontSize: isStory ? 13.5 : 11,
            fontWeight: FontWeight.w800,
            color: Colors.white.withValues(alpha: 0.95),
            letterSpacing: 2.0,
            shadows: [
              Shadow(
                color: themeData.accentColor.withValues(alpha: 0.4),
                blurRadius: 8,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHadithCard(ZikirShareThemeData themeData, bool isStory) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isStory ? 14 : 10,
        vertical: isStory ? 10 : 6,
      ),
      decoration: BoxDecoration(
        color: themeData.cardBg,
        borderRadius: BorderRadius.circular(isStory ? 16 : 12),
        border: Border.all(
          color: themeData.accentColor.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                color: themeData.accentColor,
                size: isStory ? 13 : 11,
              ),
              const SizedBox(width: 5),
              Text(
                'DEVAMLILIK SIRRI',
                style: GoogleFonts.outfit(
                  fontSize: isStory ? 10 : 8.5,
                  fontWeight: FontWeight.w700,
                  color: themeData.accentColor,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(width: 5),
              Icon(
                Icons.auto_awesome_rounded,
                color: themeData.accentColor,
                size: isStory ? 13 : 11,
              ),
            ],
          ),
          SizedBox(height: isStory ? 5 : 3),
          Text(
            '“Amellerin Allah’a en sevimli olanı, az da olsa devamlı olanıdır.”',
            textAlign: TextAlign.center,
            maxLines: isStory ? 3 : 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(
              fontSize: isStory ? 12 : 10,
              fontWeight: FontWeight.w400,
              color: Colors.white.withValues(alpha: 0.95),
              height: 1.35,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '(Buhârî, Rikâk 18)',
            style: TextStyle(
              fontSize: isStory ? 9.5 : 8,
              color: themeData.accentColor.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCapsule(ZikirShareThemeData themeData, bool isStory) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isStory ? 12 : 8,
        vertical: isStory ? 8 : 5,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('AKTİF SERİ', '$currentStreak Gün', themeData, isStory, isHighlight: true),
          Container(width: 1, height: isStory ? 20 : 14, color: Colors.white12),
          _buildStatItem('EN İYİ SERİ', '$bestStreak Gün', themeData, isStory),
          Container(width: 1, height: isStory ? 20 : 14, color: Colors.white12),
          _buildStatItem('TOPLAM GÜN', '$totalDays Gün', themeData, isStory),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    ZikirShareThemeData themeData,
    bool isStory, {
    bool isHighlight = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isStory ? 8 : 7,
            fontWeight: FontWeight.w600,
            color: Colors.white54,
            letterSpacing: 0.4,
          ),
        ),
        SizedBox(height: isStory ? 1.5 : 1),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: isStory ? 13 : 10.5,
            fontWeight: FontWeight.w700,
            color: isHighlight ? themeData.accentColor : Colors.white,
          ),
        ),
      ],
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
          '“Zinciri kırma, her gün bir adım daha yaklaş.”',
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
