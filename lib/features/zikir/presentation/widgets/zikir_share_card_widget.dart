import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/utils/quran_word_highlighter.dart';
import '../../domain/share_card_data_helper.dart';

/// Formats available for the share card
enum ZikirShareCardFormat {
  story9x16,
  square1x1,
}

/// Themes available for the spiritual share card (Tahrir-inspired warm & serene palettes)
enum ZikirShareCardTheme {
  fajrDawn, // Tahrir Parşömeni (Varsayılan Sıcak Krem)
  emeraldSufi, // Adaçayı & Zeytin (Ferah Yeşil Parşömen)
  turquoiseDome, // Fildişi Sahife (Kırık Beyaz & Antik Altın)
  roseAmber, // Şafak Gülzârı (Sıcak Gül Kurusu)
  midnightGold, // Huzur Zümrüdü (Dingin Koyu Zümrüt)
  royalAmethyst, // Gece Mürekkebi (Minimalist Koyu Antrasit)
}

/// Typography presets
enum ZikirShareTypographyStyle {
  modernOutfit,
  classicAmiri,
  royalCinzel,
}

/// Minimalist frame/accent presets
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
  final Color primaryTextColor;
  final Color secondaryTextColor;
  final Color borderColor;
  final Color badgeBg;
  final Color badgeBorder;
  final Color watermarkColor;
  final Color cardBg;
  final bool isLight;

  const ZikirShareThemeData({
    required this.id,
    required this.nameTr,
    required this.nameEn,
    required this.gradientColors,
    required this.accentColor,
    required this.arabicColor,
    required this.primaryTextColor,
    required this.secondaryTextColor,
    required this.borderColor,
    required this.badgeBg,
    required this.badgeBorder,
    required this.watermarkColor,
    required this.cardBg,
    this.isLight = true,
  });

  /// 1. Tahrir Parşömeni (Varsayılan — Tahrir projesindeki sıcak krem parşömen ve kiremit vurgu)
  static const ZikirShareThemeData fajrDawn = ZikirShareThemeData(
    id: 'parchment',
    nameTr: 'Parşömen',
    nameEn: 'Parchment',
    gradientColors: [
      Color(0xFFF7EEDB),
      Color(0xFFF3E6CE),
    ],
    accentColor: Color(0xFFA64B2A),
    arabicColor: Color(0xFF2D2016),
    primaryTextColor: Color(0xFF382A1E),
    secondaryTextColor: Color(0xFF6B5848),
    borderColor: Color(0xFFDFD1B8),
    badgeBg: Color(0xFFEFE2C8),
    badgeBorder: Color(0xFFD5C3A3),
    watermarkColor: Color(0xFF6B5848),
    cardBg: Color(0xFFFDF8EE),
    isLight: true,
  );

  /// 2. Adaçayı & Zeytin (Ferah, samimi açık yeşil parşömen)
  static const ZikirShareThemeData emeraldSufi = ZikirShareThemeData(
    id: 'emerald',
    nameTr: 'Adaçayı',
    nameEn: 'Sage Olive',
    gradientColors: [
      Color(0xFFF0F5F1),
      Color(0xFFE5EEE7),
    ],
    accentColor: Color(0xFF2E6F52),
    arabicColor: Color(0xFF18281F),
    primaryTextColor: Color(0xFF1E2F26),
    secondaryTextColor: Color(0xFF52665B),
    borderColor: Color(0xFFCFDCD2),
    badgeBg: Color(0xFFE2ECE5),
    badgeBorder: Color(0xFFBDD0C2),
    watermarkColor: Color(0xFF52665B),
    cardBg: Color(0xFFF7FAF8),
    isLight: true,
  );

  /// 3. Fildişi Sahife (Temiz kitap kağıdı ve antik altın)
  static const ZikirShareThemeData turquoiseDome = ZikirShareThemeData(
    id: 'ivory',
    nameTr: 'Fildişi',
    nameEn: 'Ivory Page',
    gradientColors: [
      Color(0xFFFAF8F3),
      Color(0xFFF2ECE1),
    ],
    accentColor: Color(0xFF966B26),
    arabicColor: Color(0xFF211B14),
    primaryTextColor: Color(0xFF282119),
    secondaryTextColor: Color(0xFF6E5F50),
    borderColor: Color(0xFFE3D9C6),
    badgeBg: Color(0xFFEFE8DA),
    badgeBorder: Color(0xFFD8CEB8),
    watermarkColor: Color(0xFF6E5F50),
    cardBg: Color(0xFFFFFFFF),
    isLight: true,
  );

  /// 4. Şafak Gülzârı (Sıcak gül kurusu & toprak tonu)
  static const ZikirShareThemeData roseAmber = ZikirShareThemeData(
    id: 'rose',
    nameTr: 'Gülzâr',
    nameEn: 'Rose Dawn',
    gradientColors: [
      Color(0xFFFBF2EF),
      Color(0xFFF4E5E0),
    ],
    accentColor: Color(0xFFA04637),
    arabicColor: Color(0xFF2C1A17),
    primaryTextColor: Color(0xFF34201C),
    secondaryTextColor: Color(0xFF73544E),
    borderColor: Color(0xFFE6D1CB),
    badgeBg: Color(0xFFF2DFD9),
    badgeBorder: Color(0xFFDCC2BA),
    watermarkColor: Color(0xFF73544E),
    cardBg: Color(0xFFFEF9F7),
    isLight: true,
  );

  /// 5. Huzur Zümrüdü (Dingin koyu zümrüt & altın)
  static const ZikirShareThemeData midnightGold = ZikirShareThemeData(
    id: 'midnight',
    nameTr: 'Zümrüt Gece',
    nameEn: 'Serene Emerald',
    gradientColors: [
      Color(0xFF142822),
      Color(0xFF0E1D18),
    ],
    accentColor: Color(0xFFD4AF37),
    arabicColor: Color(0xFFF7F2E8),
    primaryTextColor: Color(0xFFF4EFE6),
    secondaryTextColor: Color(0xFFA7BDB4),
    borderColor: Color(0xFF2A473D),
    badgeBg: Color(0xFF1B332B),
    badgeBorder: Color(0xFF34594C),
    watermarkColor: Color(0xFFA7BDB4),
    cardBg: Color(0xFF193028),
    isLight: false,
  );

  /// 6. Gece Mürekkebi (Minimalist koyu antrasit)
  static const ZikirShareThemeData royalAmethyst = ZikirShareThemeData(
    id: 'ink',
    nameTr: 'Mürekkep',
    nameEn: 'Night Ink',
    gradientColors: [
      Color(0xFF181A20),
      Color(0xFF121418),
    ],
    accentColor: Color(0xFFD49B54),
    arabicColor: Color(0xFFF5EFE6),
    primaryTextColor: Color(0xFFF2ECE1),
    secondaryTextColor: Color(0xFFA0A5B1),
    borderColor: Color(0xFF2E323C),
    badgeBg: Color(0xFF20232B),
    badgeBorder: Color(0xFF363B47),
    watermarkColor: Color(0xFFA0A5B1),
    cardBg: Color(0xFF1E2128),
    isLight: false,
  );

  static ZikirShareThemeData fromEnum(ZikirShareCardTheme theme) {
    switch (theme) {
      case ZikirShareCardTheme.fajrDawn:
        return fajrDawn;
      case ZikirShareCardTheme.emeraldSufi:
        return emeraldSufi;
      case ZikirShareCardTheme.turquoiseDome:
        return turquoiseDome;
      case ZikirShareCardTheme.roseAmber:
        return roseAmber;
      case ZikirShareCardTheme.midnightGold:
        return midnightGold;
      case ZikirShareCardTheme.royalAmethyst:
        return royalAmethyst;
    }
  }

  /// Varsayılan olarak Tahrir Parşömeni ve açık/samimi temaları seçer
  static ZikirShareCardTheme themeForGoalOrTask({
    String? goalType,
    String? taskType,
    String? category,
    bool isGold = false,
  }) {
    if (isGold) {
      return ZikirShareCardTheme.turquoiseDome;
    }
    final key =
        '${goalType ?? ''} ${taskType ?? ''} ${category ?? ''}'.toLowerCase();
    if (key.contains('kuran') ||
        key.contains('kur\'an') ||
        key.contains('kur’an') ||
        key.contains('hatim') ||
        key.contains('tilavet') ||
        key.contains('ayet') ||
        key.contains('âyet')) {
      return ZikirShareCardTheme.fajrDawn; // Tahrir Parşömeni
    }
    if (key.contains('salavat') ||
        key.contains('salat') ||
        key.contains('gül') ||
        key.contains('rose') ||
        key.contains('dua')) {
      return ZikirShareCardTheme.roseAmber;
    }
    if (key.contains('namaz') || key.contains('vakit')) {
      return ZikirShareCardTheme.emeraldSufi;
    }
    return ZikirShareCardTheme.fajrDawn;
  }
}

/// Tahrir Estetiğiyle Yenilenen Minimalist & Samimi Paylaşım Kartı
/// - Üstte devasa ZİKİRCE başlığı yok; logo en altta küçük ve zarif imza olarak yer alır.
/// - Metinler iç içe kutulara/çerçevelere hapsedilmez; ferah parşömen üzerinde nefes alır.
/// - Âyet meâli / hikmetli söz en büyük ve en okunaklı ana unsurdur.
/// - İnce yatay çizginin altında sûre ve âyet numarası / kaynak tek seferde, net biçimde yazılır.
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
    this.theme = ZikirShareCardTheme.fajrDawn,
    this.typographyStyle = ZikirShareTypographyStyle.classicAmiri,
    this.patternStyle = ZikirSharePatternStyle.mihrapSufi,
    this.showCounterStats = true,
    this.showArabicText = true,
    this.arabicFontFamily = 'AmasyaAbay',
  });

  double _computeQuoteFontSize(String text, bool isStory, bool hasArabic) {
    final len = text.length;
    if (len <= 60) return isStory ? (hasArabic ? 21.0 : 24.0) : (hasArabic ? 19.0 : 21.5);
    if (len <= 120) return isStory ? (hasArabic ? 19.0 : 21.5) : (hasArabic ? 17.5 : 19.5);
    if (len <= 200) return isStory ? (hasArabic ? 17.5 : 19.5) : (hasArabic ? 16.0 : 17.5);
    if (len <= 320) return isStory ? 15.8 : 14.5;
    return isStory ? 14.2 : 13.2;
  }

  double _computeArabicFontSize(String arabic, bool isStory) {
    final len = arabic.length;
    if (len <= 55) return isStory ? 25.0 : 22.0;
    if (len <= 120) return isStory ? 22.0 : 19.5;
    if (len <= 220) return isStory ? 19.0 : 17.0;
    return isStory ? 16.5 : 15.0;
  }

  TextStyle _resolveQuoteTextStyle({
    required String text,
    required bool isStory,
    required bool hasArabic,
    required Color color,
  }) {
    final fontSize = _computeQuoteFontSize(text, isStory, hasArabic);
    switch (typographyStyle) {
      case ZikirShareTypographyStyle.classicAmiri:
        return GoogleFonts.playfairDisplay(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          color: color,
          height: 1.48,
        );
      case ZikirShareTypographyStyle.royalCinzel:
        return GoogleFonts.merriweather(
          fontSize: fontSize - 0.5,
          fontWeight: FontWeight.w600,
          color: color,
          height: 1.50,
        );
      case ZikirShareTypographyStyle.modernOutfit:
        return GoogleFonts.outfit(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          color: color,
          height: 1.45,
        );
    }
  }

  String _cleanQuotes(String raw) {
    return raw
        .trim()
        .replaceAll(RegExp(r'^[“"«\s]+'), '')
        .replaceAll(RegExp(r'[”"»\s]+$'), '');
  }

  @override
  Widget build(BuildContext context) {
    final themeData = ZikirShareThemeData.fromEnum(theme);
    final isStory = format == ZikirShareCardFormat.story9x16;

    final resolvedQuote = ShareCardDataHelper.resolveQuote(
      zikirName: zikirName,
      category: category,
      rawVirtue: virtue,
      customSource: source,
      customArabic: arabicText,
      quoteIndex: quoteIndex,
    );

    final String? resolvedArabic = (arabicText != null && arabicText!.trim().isNotEmpty)
        ? arabicText
        : resolvedQuote.arabic;

    final String heroQuote = _cleanQuotes(resolvedQuote.text);
    final String rawSource = resolvedQuote.source.trim();
    final String cleanTitle = zikirName.trim();

    // Kaynak / Sûre-Âyet bilgisini tekrarsız oluştur
    final String displaySource = rawSource.isNotEmpty ? rawSource : cleanTitle;
    final bool showDistinctTitle = showCounterStats &&
        cleanTitle.isNotEmpty &&
        cleanTitle.toLowerCase() != displaySource.toLowerCase();

    final bool hasArabic = showArabicText &&
        resolvedArabic != null &&
        resolvedArabic.trim().isNotEmpty;

    final int effectiveCount = totalCount > 0 ? totalCount : currentCount;
    final bool hasCounter = showCounterStats && effectiveCount > 0;

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
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: themeData.gradientColors,
              ),
              borderRadius: BorderRadius.circular(28),
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
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (patternStyle == ZikirSharePatternStyle.seljukStar)
                  IgnorePointer(
                    child: Container(
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: themeData.borderColor.withValues(alpha: 0.65),
                          width: 1.0,
                        ),
                      ),
                    ),
                  ),

                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isStory ? 36.0 : 32.0,
                    vertical: isStory ? 34.0 : 24.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (specialDayGreeting != null &&
                          specialDayGreeting!.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            specialDayGreeting!.trim(),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                              color: themeData.accentColor,
                            ),
                          ),
                        ),

                      // Merkez İçerik Bloğu: Hiçbir zaman metni kesmez, uzun âyetlerde zarifçe ölçeklenir
                      Expanded(
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.center,
                            child: SizedBox(
                              width: canvasWidth - (isStory ? 72.0 : 64.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // 1. Tahrir Stili Sıcak Tırnak İşareti “
                                  Text(
                                    '“',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.playfairDisplay(
                                      fontSize: isStory ? 54 : 44,
                                      fontWeight: FontWeight.w700,
                                      color: themeData.accentColor,
                                      height: 0.75,
                                    ),
                                  ),
                                  SizedBox(height: isStory ? 12 : 8),

                                  // 2. Arapça Hat (Çerçevesiz, ferah, zarif)
                                  if (hasArabic) ...[
                                    Text.rich(
                                      TextSpan(
                                        children: QuranWordHighlighter
                                            .buildHighlightedSpans(
                                          rawText: resolvedArabic.trim(),
                                          baseStyle: TextStyle(
                                            fontFamily: arabicFontFamily,
                                            fontSize: _computeArabicFontSize(
                                                resolvedArabic, isStory),
                                            fontWeight: FontWeight.w500,
                                            color: themeData.arabicColor
                                                .withValues(alpha: 0.94),
                                            height: 1.85,
                                          ),
                                          isDark: theme ==
                                                  ZikirShareCardTheme
                                                      .midnightGold ||
                                              theme ==
                                                  ZikirShareCardTheme
                                                      .royalAmethyst,
                                          enabled: true,
                                          fontFamily: arabicFontFamily,
                                        ),
                                      ),
                                      textAlign: TextAlign.center,
                                      textDirection: TextDirection.rtl,
                                    ),
                                    SizedBox(height: isStory ? 18 : 12),
                                  ],

                                  // 3. ANA İÇERİK: Âyet Meâli / Hikmetli Söz (Tam Metin, Kesilmesiz)
                                  Text(
                                    heroQuote,
                                    textAlign: TextAlign.center,
                                    style: _resolveQuoteTextStyle(
                                      text: heroQuote,
                                      isStory: isStory,
                                      hasArabic: hasArabic,
                                      color: themeData.primaryTextColor,
                                    ),
                                  ),

                                  SizedBox(height: isStory ? 24 : 16),

                                  // 4. Tahrir Stili İnce Yatay Ayırıcı Çizgi
                                  Container(
                                    width: 48,
                                    height: 1.8,
                                    decoration: BoxDecoration(
                                      color: themeData.accentColor
                                          .withValues(alpha: 0.65),
                                      borderRadius: BorderRadius.circular(1),
                                    ),
                                  ),
                                  SizedBox(height: isStory ? 14 : 10),

                                  // 5. Sûre & Âyet Numarası / Kaynak Bilgisi
                                  if (displaySource.isNotEmpty)
                                    Text(
                                      displaySource,
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.outfit(
                                        fontSize: isStory ? 15.5 : 14.0,
                                        fontWeight: FontWeight.w700,
                                        color: themeData.primaryTextColor,
                                        letterSpacing: 0.2,
                                        height: 1.35,
                                      ),
                                    ),

                                  // 6. Zikir Sayacı (Sadece sayaç açıksa)
                                  if (hasCounter) ...[
                                    SizedBox(height: isStory ? 12 : 8),
                                    Text(
                                      '$effectiveCount${showDistinctTitle ? ' • $cleanTitle' : ''}',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.outfit(
                                        fontSize: isStory ? 13.5 : 12.0,
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

                      SizedBox(height: isStory ? 14 : 10),

                      // 7. En Alt: Net ve Belirgin Zikirce Logosu ve İmzası
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Backward-compatible minimalist painters used by dashboard cards
class IslamicArchPainter extends CustomPainter {
  final Color color;
  final Color accentColor;

  IslamicArchPainter({required this.color, required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    // Minimalist Tahrir aesthetic: no heavy mosque silhouette clutter
  }

  @override
  bool shouldRepaint(covariant IslamicArchPainter oldDelegate) => false;
}

class SufiDervishPainter extends CustomPainter {
  final Color accentColor;
  final bool isStory;

  SufiDervishPainter({required this.accentColor, required this.isStory});

  @override
  void paint(Canvas canvas, Size size) {
    // Minimalist Tahrir aesthetic: no dark silhouette clutter
  }

  @override
  bool shouldRepaint(covariant SufiDervishPainter oldDelegate) => false;
}

class IslamicPatternPainter extends CustomPainter {
  final Color color;
  final Color accentColor;
  final ZikirSharePatternStyle patternStyle;

  IslamicPatternPainter({
    required this.color,
    required this.accentColor,
    this.patternStyle = ZikirSharePatternStyle.mihrapSufi,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Minimalist Tahrir aesthetic: clean parchment surface
  }

  @override
  bool shouldRepaint(covariant IslamicPatternPainter oldDelegate) => false;
}
