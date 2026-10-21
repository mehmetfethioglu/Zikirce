import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/share_card_data_helper.dart';

/// Formats available for the share card
enum ZikirShareCardFormat {
  story9x16,
  square1x1,
}

/// Themes available for the spiritual share card
enum ZikirShareCardTheme {
  emeraldSufi,
  midnightGold,
  turquoiseDome,
  roseAmber,
  royalAmethyst,
  fajrDawn,
}

/// Typography presets inspired by YouVersion & Ayah Share Studio
enum ZikirShareTypographyStyle {
  modernOutfit,
  classicAmiri,
  royalCinzel,
}

/// Artistic background pattern layer presets (Mimar Sinan)
enum ZikirSharePatternStyle {
  mihrapSufi,
  seljukStar,
  minimalGlow,
}

class ZikirShareThemeData {
  final String id;
  final String nameTr;
  final String nameEn;
  final List<Color> gradientColors;
  final Color accentColor;
  final Color arabicColor;
  final Color badgeBg;
  final Color badgeBorder;
  final Color watermarkColor;
  final Color cardBg;

  const ZikirShareThemeData({
    required this.id,
    required this.nameTr,
    required this.nameEn,
    required this.gradientColors,
    required this.accentColor,
    required this.arabicColor,
    required this.badgeBg,
    required this.badgeBorder,
    required this.watermarkColor,
    required this.cardBg,
  });

  static const ZikirShareThemeData emeraldSufi = ZikirShareThemeData(
    id: 'emerald',
    nameTr: 'Zikirce Zümrüt',
    nameEn: 'Emerald Sufi',
    gradientColors: [
      Color(0xFF041F17),
      Color(0xFF083327),
      Color(0xFF0E4D3B),
      Color(0xFF186851),
      Color(0xFF26876C),
    ],
    accentColor: Color(0xFFFFD166),
    arabicColor: Color(0xFFFFE599),
    badgeBg: Color(0xFF0A3C2E),
    badgeBorder: Color(0xFF3EA388),
    watermarkColor: Color(0x24FFFFFF),
    cardBg: Color(0x3805241C),
  );

  static const ZikirShareThemeData midnightGold = ZikirShareThemeData(
    id: 'midnight',
    nameTr: 'Gece Seması',
    nameEn: 'Midnight Gold',
    gradientColors: [
      Color(0xFF05080C),
      Color(0xFF0C131B),
      Color(0xFF14202D),
      Color(0xFF1C2C3E),
      Color(0xFF26394E),
    ],
    accentColor: Color(0xFFF3B728),
    arabicColor: Color(0xFFFFDF80),
    badgeBg: Color(0xFF162332),
    badgeBorder: Color(0xFFB57D15),
    watermarkColor: Color(0x28F3B728),
    cardBg: Color(0x400A1017),
  );

  static const ZikirShareThemeData turquoiseDome = ZikirShareThemeData(
    id: 'turquoise',
    nameTr: 'Turkuaz Kubbe',
    nameEn: 'Turquoise Dome',
    gradientColors: [
      Color(0xFF02171E),
      Color(0xFF062C38),
      Color(0xFF0B4659),
      Color(0xFF13647E),
      Color(0xFF1E87A8),
    ],
    accentColor: Color(0xFF70E0D8),
    arabicColor: Color(0xFFE2FCF9),
    badgeBg: Color(0xFF093948),
    badgeBorder: Color(0xFF48CAE4),
    watermarkColor: Color(0x2470E0D8),
    cardBg: Color(0x38041E26),
  );

  static const ZikirShareThemeData roseAmber = ZikirShareThemeData(
    id: 'rose',
    nameTr: 'Gülzâr',
    nameEn: 'Rose Amber',
    gradientColors: [
      Color(0xFF1A0913),
      Color(0xFF2E0F23),
      Color(0xFF4A1637),
      Color(0xFF6B1E4F),
      Color(0xFF8F2969),
    ],
    accentColor: Color(0xFFF4A261),
    arabicColor: Color(0xFFFFDDD2),
    badgeBg: Color(0xFF3D122D),
    badgeBorder: Color(0xFFE07A5F),
    watermarkColor: Color(0x24FFDDD2),
    cardBg: Color(0x38220A19),
  );

  static const ZikirShareThemeData royalAmethyst = ZikirShareThemeData(
    id: 'amethyst',
    nameTr: 'Sultan Moru',
    nameEn: 'Royal Amethyst',
    gradientColors: [
      Color(0xFF13061F),
      Color(0xFF220A38),
      Color(0xFF39105B),
      Color(0xFF551985),
      Color(0xFF7524B6),
    ],
    accentColor: Color(0xFFFFD166),
    arabicColor: Color(0xFFF3E8FF),
    badgeBg: Color(0xFF2E0C4A),
    badgeBorder: Color(0xFFA855F7),
    watermarkColor: Color(0x28FFD166),
    cardBg: Color(0x40160724),
  );

  static const ZikirShareThemeData fajrDawn = ZikirShareThemeData(
    id: 'fajr',
    nameTr: 'Fecr Vakti',
    nameEn: 'Fajr Dawn',
    gradientColors: [
      Color(0xFF180B05),
      Color(0xFF2B1409),
      Color(0xFF48210F),
      Color(0xFF693016),
      Color(0xFF8F421F),
    ],
    accentColor: Color(0xFFFFB703),
    arabicColor: Color(0xFFFFE8D6),
    badgeBg: Color(0xFF35180B),
    badgeBorder: Color(0xFFFB8500),
    watermarkColor: Color(0x28FFB703),
    cardBg: Color(0x40180B05),
  );

  static ZikirShareThemeData fromEnum(ZikirShareCardTheme theme) {
    switch (theme) {
      case ZikirShareCardTheme.emeraldSufi:
        return emeraldSufi;
      case ZikirShareCardTheme.midnightGold:
        return midnightGold;
      case ZikirShareCardTheme.turquoiseDome:
        return turquoiseDome;
      case ZikirShareCardTheme.roseAmber:
        return roseAmber;
      case ZikirShareCardTheme.royalAmethyst:
        return royalAmethyst;
      case ZikirShareCardTheme.fajrDawn:
        return fajrDawn;
    }
  }

  /// Automatically picks a tailored spiritual theme for each goal or task type
  static ZikirShareCardTheme themeForGoalOrTask({
    String? goalType,
    String? taskType,
    String? category,
    bool isGold = false,
  }) {
    if (isGold || goalType == 'streak' || goalType == 'goldenDay' || goalType == 'golden_day' || goalType == 'devamlilik') {
      return ZikirShareCardTheme.midnightGold;
    }
    final key = '${goalType ?? ''} ${taskType ?? ''} ${category ?? ''}'.toLowerCase();
    if (key.contains('namaz') || key.contains('prayer') || key.contains('vakit')) {
      if (key.contains('kaza')) return ZikirShareCardTheme.roseAmber;
      return ZikirShareCardTheme.turquoiseDome;
    }
    if (key.contains('kuran') || key.contains('kur\'an') || key.contains('kur’an') || key.contains('hatim') || key.contains('tilavet')) {
      return ZikirShareCardTheme.fajrDawn;
    }
    if (key.contains('ezber') || key.contains('hafız') || key.contains('hafiz')) {
      return ZikirShareCardTheme.royalAmethyst;
    }
    if (key.contains('kaza') || key.contains('telafi') || key.contains('salavat') || key.contains('salat') || key.contains('gül') || key.contains('rose')) {
      return ZikirShareCardTheme.roseAmber;
    }
    if (key.contains('istiğfar') || key.contains('istigfar') || key.contains('tevbe') || key.contains('gece')) {
      return ZikirShareCardTheme.royalAmethyst;
    }
    if (key.contains('fecr') || key.contains('sabah') || key.contains('güneş') || key.contains('şükür')) {
      return ZikirShareCardTheme.fajrDawn;
    }
    return ZikirShareCardTheme.emeraldSufi;
  }
}

/// The Main Visual Share Card Widget (Mimar Sinan & Zero Muda Design)
class ZikirShareCardWidget extends StatelessWidget {
  final String zikirName;
  final String? arabicText;
  final String? virtue;
  final String? source;
  final String? specialDayGreeting;
  final String? spiritualNote;
  final String category;
  final int currentCount;
  final int targetCount;
  final int totalCount;
  final int quoteIndex;
  final ZikirShareCardFormat format;
  final ZikirShareCardTheme theme;
  final ZikirShareTypographyStyle typographyStyle;
  final ZikirSharePatternStyle patternStyle;
  final bool showCounterStats;
  final bool showArabicText;
  final String arabicFontFamily;

  const ZikirShareCardWidget({
    super.key,
    required this.zikirName,
    this.arabicText,
    this.virtue,
    this.source,
    this.specialDayGreeting,
    this.spiritualNote,
    this.category = 'Günlük Zikir',
    this.currentCount = 0,
    this.targetCount = 33,
    this.totalCount = 0,
    this.quoteIndex = 0,
    this.format = ZikirShareCardFormat.story9x16,
    this.theme = ZikirShareCardTheme.emeraldSufi,
    this.typographyStyle = ZikirShareTypographyStyle.modernOutfit,
    this.patternStyle = ZikirSharePatternStyle.mihrapSufi,
    this.showCounterStats = true,
    this.showArabicText = true,
    this.arabicFontFamily = 'mushaf',
  });

  TextStyle _resolveQuoteTextStyle({
    required bool isStory,
  }) {
    final fontSize = isStory ? 12.5 : 10.5;
    switch (typographyStyle) {
      case ZikirShareTypographyStyle.classicAmiri:
        return GoogleFonts.amiri(
          fontSize: fontSize + 1.5,
          fontWeight: FontWeight.w500,
          color: Colors.white.withValues(alpha: 0.96),
          height: 1.4,
          fontStyle: FontStyle.italic,
        );
      case ZikirShareTypographyStyle.royalCinzel:
        return GoogleFonts.cinzel(
          fontSize: fontSize - 0.5,
          fontWeight: FontWeight.w600,
          color: Colors.white.withValues(alpha: 0.95),
          height: 1.35,
        );
      case ZikirShareTypographyStyle.modernOutfit:
        return GoogleFonts.outfit(
          fontSize: isStory ? 12.0 : 10.0,
          fontWeight: FontWeight.w400,
          color: Colors.white.withValues(alpha: 0.95),
          height: 1.35,
          fontStyle: FontStyle.italic,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeData = ZikirShareThemeData.fromEnum(theme);
    final isStory = format == ZikirShareCardFormat.story9x16;

    // Resolve quote & optional Arabic from helper if not explicitly provided
    final resolvedQuote = ShareCardDataHelper.resolveQuote(
      zikirName: zikirName,
      category: category,
      rawVirtue: (quoteIndex == 0) ? virtue : null,
      quoteIndex: quoteIndex,
    );

    final effectiveArabic = (arabicText != null && arabicText!.trim().isNotEmpty && quoteIndex == 0)
        ? arabicText!.trim()
        : (resolvedQuote.arabic ?? arabicText ?? '');

    final effectiveVirtue = (virtue != null && virtue!.trim().isNotEmpty && quoteIndex == 0)
        ? virtue!.trim()
        : resolvedQuote.text;

    final effectiveSource = (source != null && source!.trim().isNotEmpty && quoteIndex == 0)
        ? source!.trim()
        : resolvedQuote.source;

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
              // 1. Classical Pointed Mihrap Arch (shown in mihrapSufi & seljukStar)
              if (patternStyle != ZikirSharePatternStyle.minimalGlow)
                Positioned.fill(
                  child: CustomPaint(
                    painter: IslamicArchPainter(
                      archColor: themeData.accentColor.withValues(
                        alpha: patternStyle == ZikirSharePatternStyle.seljukStar ? 0.22 : 0.12,
                      ),
                      isStoryFormat: isStory,
                    ),
                  ),
                ),

              // 2. Ambient Glow and Sufi Semazen Custom Vector Painting
              if (patternStyle == ZikirSharePatternStyle.mihrapSufi)
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
                    patternColor: themeData.accentColor.withValues(
                      alpha: patternStyle == ZikirSharePatternStyle.seljukStar ? 0.20 : 0.08,
                    ),
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
                    // --- TOP BAR: Brand Header & Category Pill ---
                    _buildHeader(themeData, isStory),

                    // --- SPECIAL DAY GREETING (Varsa Özel Gün Tebriği) ---
                    if (specialDayGreeting != null && specialDayGreeting!.trim().isNotEmpty)
                      _buildSpecialDayGreetingBanner(specialDayGreeting!.trim(), themeData, isStory),

                    if (isStory) const SizedBox(height: 14) else const SizedBox(height: 6),

                    // --- CENTER BODY: Zikir/Goal Name, Arabic Calligraphy & Virtue Card ---
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          physics: const NeverScrollableScrollPhysics(),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Arabic Calligraphy
                              if (showArabicText && effectiveArabic.trim().isNotEmpty) ...[
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    effectiveArabic,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: arabicFontFamily,
                                      fontSize: isStory ? 32 : 24,
                                      color: themeData.arabicColor,
                                      height: 1.3,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black.withValues(alpha: 0.6),
                                          blurRadius: 14,
                                          offset: const Offset(0, 3),
                                        ),
                                        Shadow(
                                          color: themeData.accentColor.withValues(alpha: 0.3),
                                          blurRadius: 20,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(height: isStory ? 8 : 4),
                              ],

                              // Turkish Name (Bold Modern Typography)
                              Text(
                                zikirName.toUpperCase(),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  fontSize: isStory ? 21 : 16.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 1.3,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withValues(alpha: 0.7),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),

                              SizedBox(height: isStory ? 12 : 6),

                              // Virtue / Hadith Glassmorphism Box with Exact Source
                              if (effectiveVirtue.isNotEmpty)
                                _buildVirtueCard(
                                  themeData: themeData,
                                  isStory: isStory,
                                  rawText: effectiveVirtue,
                                  resolvedSource: effectiveSource,
                                  quoteType: resolvedQuote.type,
                                ),

                              // Optional Personal Spiritual Note (Dua / Tefekkür Notu)
                              if (spiritualNote != null && spiritualNote!.trim().isNotEmpty) ...[
                                SizedBox(height: isStory ? 8 : 4),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isStory ? 12 : 8,
                                    vertical: isStory ? 5 : 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.14),
                                    ),
                                  ),
                                  child: Text(
                                    spiritualNote!.trim(),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.outfit(
                                      fontSize: isStory ? 10.5 : 8.5,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white.withValues(alpha: 0.9),
                                    ),
                                  ),
                                ),
                              ],

                              // Counter Statistics Card (Optional)
                              if (showCounterStats) ...[
                                SizedBox(height: isStory ? 10 : 5),
                                _buildCounterCapsule(themeData, isStory),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),

                    if (isStory) const SizedBox(height: 10) else const SizedBox(height: 4),

                    // --- FOOTER: Spiritual Icons & Zikirce Signature ---
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

  /// Top Brand & Category Header
  Widget _buildHeader(ZikirShareThemeData themeData, bool isStory) {
    final cleanCategory = category
        .replaceAll(RegExp(r'(tamamlanan|görev|hedef)', caseSensitive: false), '')
        .trim();
    final displayCategory = cleanCategory.isEmpty ? 'İBADET & ZİKİR' : cleanCategory;

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
                    displayCategory.toUpperCase(),
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

  /// Special Day Greeting Banner (Varsa Özel Gün Tebriği)
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

  /// Glassmorphic Virtue / Hadith Card with Exact Verified Source
  Widget _buildVirtueCard({
    required ZikirShareThemeData themeData,
    required bool isStory,
    required String rawText,
    required String resolvedSource,
    required SpiritualQuoteType quoteType,
  }) {
    String quoteText = rawText;
    if (rawText.contains('(') && (source == null || source!.isEmpty)) {
      final parsed = ShareCardDataHelper.resolveQuote(
        zikirName: zikirName,
        category: category,
        rawVirtue: rawText,
      );
      quoteText = parsed.text;
    }

    final displayText = rawText.contains('(') ? quoteText : rawText;
    final headerTitle = quoteType == SpiritualQuoteType.ayet
        ? 'ÂYET-İ KERÎME & HİKMETİ'
        : 'FAZİLET VE BEREKETİ';

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
          color: themeData.accentColor.withValues(alpha: 0.35),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
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
                headerTitle,
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
          SizedBox(height: isStory ? 6 : 3),
          Text(
            '“$displayText”',
            textAlign: TextAlign.center,
            maxLines: isStory ? 4 : 3,
            overflow: TextOverflow.ellipsis,
            style: _resolveQuoteTextStyle(isStory: isStory),
          ),
          if (resolvedSource.isNotEmpty) ...[
            SizedBox(height: isStory ? 6 : 3),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                resolvedSource.startsWith('(') ? resolvedSource : '($resolvedSource)',
                style: TextStyle(
                  fontSize: isStory ? 9.5 : 8,
                  fontWeight: FontWeight.w600,
                  color: themeData.accentColor,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Modern Counter Capsule & Progress (Purified from Task/Goal/Completion jargon)
  Widget _buildCounterCapsule(ZikirShareThemeData themeData, bool isStory) {
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('BU OTURUM', '$currentCount', themeData, isStory, isHighlight: true),
              Container(width: 1, height: isStory ? 20 : 14, color: Colors.white12),
              _buildStatItem('TOPLAM ZİKİR', '$totalCount', themeData, isStory),
              Container(width: 1, height: isStory ? 20 : 14, color: Colors.white12),
              _buildStatItem('MANEVİ NİYET', '$targetCount', themeData, isStory),
            ],
          ),
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

  /// Footer with Spiritual Icons & App Tagline
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

/// Custom Painter for Classical Pointed Mihrap Arch (Mimar Sinan Design)
class IslamicArchPainter extends CustomPainter {
  final Color archColor;
  final bool isStoryFormat;

  IslamicArchPainter({
    required this.archColor,
    required this.isStoryFormat,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = archColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final outerMargin = isStoryFormat ? 12.0 : 8.0;
    final archTop = isStoryFormat ? 60.0 : 40.0;
    final archBottom = size.height - (isStoryFormat ? 55.0 : 35.0);
    final left = outerMargin;
    final right = size.width - outerMargin;
    final centerX = size.width / 2;

    // Draw Classical Ottoman Pointed Arch (Mihrap Kemer Formu)
    final path = Path();
    path.moveTo(left, archBottom);
    path.lineTo(left, archTop + 60);

    // Left arch shoulder curving to pointed peak
    path.cubicTo(left, archTop + 20, centerX - 40, archTop + 5, centerX, archTop);

    // Right arch shoulder curving to pointed peak
    path.cubicTo(centerX + 40, archTop + 5, right, archTop + 20, right, archTop + 60);
    path.lineTo(right, archBottom);

    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant IslamicArchPainter oldDelegate) {
    return oldDelegate.archColor != archColor || oldDelegate.isStoryFormat != isStoryFormat;
  }
}

/// Custom Painter for Sufi Whirling Dervish (Semazen) Silhouette
class SufiDervishPainter extends CustomPainter {
  final Color watermarkColor;
  final Color accentColor;
  final bool isStoryFormat;

  SufiDervishPainter({
    required this.watermarkColor,
    required this.accentColor,
    required this.isStoryFormat,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = watermarkColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = watermarkColor.withValues(alpha: watermarkColor.a * 0.4)
      ..style = PaintingStyle.fill;

    final glowPaint = Paint()
      ..color = accentColor
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 45);

    final centerX = size.width * 0.55;
    final centerY = isStoryFormat ? size.height * 0.42 : size.height * 0.45;
    final scale = (size.width / 400.0) * (isStoryFormat ? 1.0 : 0.85);

    canvas.drawCircle(Offset(centerX, centerY - 20 * scale), 120 * scale, glowPaint);

    final auraPaint = Paint()
      ..color = watermarkColor.withValues(alpha: watermarkColor.a * 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(Offset(centerX, centerY - 30 * scale), 90 * scale, auraPaint);
    canvas.drawCircle(Offset(centerX, centerY - 30 * scale), 130 * scale, auraPaint);

    canvas.save();
    canvas.translate(centerX, centerY);
    canvas.scale(scale);

    final sikkePath = Path();
    sikkePath.moveTo(-8, -135);
    sikkePath.cubicTo(-14, -130, -18, -100, -15, -85);
    sikkePath.lineTo(15, -85);
    sikkePath.cubicTo(18, -100, 14, -130, 8, -135);
    sikkePath.close();

    canvas.drawPath(sikkePath, fillPaint);
    canvas.drawPath(sikkePath, strokePaint);

    canvas.drawOval(
      Rect.fromCenter(center: const Offset(1, -72), width: 22, height: 26),
      fillPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(1, -72), width: 22, height: 26),
      strokePaint,
    );

    final bodyPath = Path();
    bodyPath.moveTo(4, -60);
    bodyPath.cubicTo(25, -65, 55, -95, 85, -110);
    bodyPath.cubicTo(92, -105, 85, -85, 60, -68);
    bodyPath.cubicTo(35, -55, 20, -45, 12, -35);
    bodyPath.lineTo(24, 0);
    bodyPath.cubicTo(55, 35, 105, 75, 130, 105);
    bodyPath.cubicTo(80, 115, 30, 100, 0, 110);
    bodyPath.cubicTo(-40, 118, -90, 105, -130, 95);
    bodyPath.cubicTo(-100, 65, -50, 30, -22, 0);
    bodyPath.lineTo(-15, -35);
    bodyPath.cubicTo(-30, -45, -65, -30, -95, -10);
    bodyPath.cubicTo(-100, -5, -95, 10, -75, 5);
    bodyPath.cubicTo(-50, -5, -25, -45, -4, -60);
    bodyPath.close();

    canvas.drawPath(bodyPath, fillPaint);
    canvas.drawPath(bodyPath, strokePaint);

    final foldPaint = Paint()
      ..color = watermarkColor.withValues(alpha: watermarkColor.a * 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final fold1 = Path()
      ..moveTo(0, -10)
      ..cubicTo(20, 35, 50, 75, 65, 108);
    canvas.drawPath(fold1, foldPaint);

    final fold2 = Path()
      ..moveTo(-5, -5)
      ..cubicTo(-15, 35, -35, 70, -45, 105);
    canvas.drawPath(fold2, foldPaint);

    final fold3 = Path()
      ..moveTo(10, 5)
      ..cubicTo(45, 45, 80, 75, 105, 100);
    canvas.drawPath(fold3, foldPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SufiDervishPainter oldDelegate) {
    return oldDelegate.watermarkColor != watermarkColor ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.isStoryFormat != isStoryFormat;
  }
}

/// Custom Painter for Geometric Islamic Star & Arch Motifs
class IslamicPatternPainter extends CustomPainter {
  final Color patternColor;

  IslamicPatternPainter({required this.patternColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = patternColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    _drawEightPointStar(canvas, const Offset(36, 36), 18, paint);
    _drawEightPointStar(canvas, Offset(size.width - 36, 36), 18, paint);

    final archPath = Path();
    final topCenterX = size.width / 2;
    archPath.moveTo(topCenterX - 60, 0);
    archPath.cubicTo(topCenterX - 40, 20, topCenterX - 20, 26, topCenterX, 30);
    archPath.cubicTo(topCenterX + 20, 26, topCenterX + 40, 20, topCenterX + 60, 0);
    canvas.drawPath(archPath, paint);
  }

  void _drawEightPointStar(Canvas canvas, Offset center, double radius, Paint paint) {
    final r = radius;
    final path1 = Path()
      ..addRect(Rect.fromCenter(center: center, width: r * 2, height: r * 2));
    canvas.drawPath(path1, paint);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(math.pi / 4);
    canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: r * 2, height: r * 2), paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant IslamicPatternPainter oldDelegate) {
    return oldDelegate.patternColor != patternColor;
  }
}
