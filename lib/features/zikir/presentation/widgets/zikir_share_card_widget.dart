import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
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
  final SpiritualQuote? customQuote;
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
    this.customQuote,
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
      explicitQuote: customQuote,
      quoteIndex: quoteIndex,
    );

    final String? resolvedArabic = (customQuote != null)
        ? customQuote!.arabic
        : ((arabicText != null && arabicText!.trim().isNotEmpty)
            ? arabicText
            : resolvedQuote.arabic);

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

                                  // 6b. Opsiyonel Dua Notu
                                  if (spiritualNote != null &&
                                      spiritualNote!.trim().isNotEmpty) ...[
                                    SizedBox(height: isStory ? 12 : 8),
                                    Text(
                                      spiritualNote!.trim(),
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.outfit(
                                        fontSize: isStory ? 12.0 : 11.0,
                                        fontWeight: FontWeight.w500,
                                        fontStyle: FontStyle.italic,
                                        color: themeData.secondaryTextColor,
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

/// Tüm paylaşım kartlarında (Zikir, İstatistik Karnesi, İstikrar Serisi ve Paylaşım Stüdyosu)
/// ortak kullanılan "🎲 Rastgele Değiştir" ve "📖 Ayet / Hadis Seç" kontrol çubuğu.
class ShareQuoteControlBar extends StatelessWidget {
  final SpiritualQuote activeQuote;
  final VoidCallback onRandomize;
  final VoidCallback onOpenPicker;
  final bool isDark;
  final bool compact;

  const ShareQuoteControlBar({
    super.key,
    required this.activeQuote,
    required this.onRandomize,
    required this.onOpenPicker,
    required this.isDark,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isAyet = activeQuote.type == SpiritualQuoteType.ayet;
    final badgeLabel = isAyet ? 'Âyet' : 'Hadis';
    final badgeIcon = isAyet ? '📖' : '📜';

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A232E) : const Color(0xFFF2F4F7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.gold500.withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        children: [
          // Sol: Aktif Ayet/Hadis Kaynak Bilgisi (Tıklanınca da Seçiciyi açar)
          Expanded(
            child: InkWell(
              onTap: onOpenPicker,
              borderRadius: BorderRadius.circular(10),
              child: Row(
                children: [
                  Text(badgeIcon, style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$badgeLabel • ${activeQuote.source}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        if (!compact)
                          Text(
                            activeQuote.text,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Orta: 🎲 Rastgele Değiştir Butonu
          InkWell(
            onTap: onRandomize,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.gold500.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.gold500.withValues(alpha: 0.45),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.shuffle_rounded,
                    size: 14,
                    color: AppColors.gold500,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Rastgele',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.gold400 : const Color(0xFF92400E),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Sağ: 📖 Ayet / Hadis Seç Butonu
          InkWell(
            onTap: onOpenPicker,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.gold500,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.menu_book_rounded,
                    size: 14,
                    color: Colors.black,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Seç',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ayet ve Hadis Seçim Çekmecesi (Arama, Ayet/Hadis Tür Filtresi, Konu Filtresi, Rastgele Seçim ve Özel Giriş)
class SpiritualQuotePickerSheet extends StatefulWidget {
  final SpiritualQuote currentQuote;
  final String initialTopic;
  final List<SpiritualQuote>? extraQuotes;

  const SpiritualQuotePickerSheet({
    super.key,
    required this.currentQuote,
    this.initialTopic = 'all',
    this.extraQuotes,
  });

  static Future<SpiritualQuote?> show({
    required BuildContext context,
    required SpiritualQuote currentQuote,
    String initialTopic = 'all',
    List<SpiritualQuote>? extraQuotes,
  }) {
    return showModalBottomSheet<SpiritualQuote>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SpiritualQuotePickerSheet(
        currentQuote: currentQuote,
        initialTopic: initialTopic,
        extraQuotes: extraQuotes,
      ),
    );
  }

  @override
  State<SpiritualQuotePickerSheet> createState() =>
      _SpiritualQuotePickerSheetState();
}

class _SpiritualQuotePickerSheetState extends State<SpiritualQuotePickerSheet> {
  late String _selectedTopic;
  SpiritualQuoteType? _selectedTypeFilter; // null = Tümü, ayet, hadis
  String _searchQuery = '';
  bool _showCustomInput = false;

  late final TextEditingController _searchController;
  late final TextEditingController _customTextController;
  late final TextEditingController _customSourceController;
  SpiritualQuoteType _customType = SpiritualQuoteType.ayet;

  @override
  void initState() {
    super.initState();
    _selectedTopic = 'all';
    _searchController = TextEditingController();
    _customTextController = TextEditingController();
    _customSourceController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _customTextController.dispose();
    _customSourceController.dispose();
    super.dispose();
  }

  List<SpiritualQuote> _buildFilteredList() {
    final List<SpiritualQuote> allQuotes = <SpiritualQuote>[
      if (widget.extraQuotes != null) ...widget.extraQuotes!,
      ...ShareCardDataHelper.curatedQuotes,
    ];

    // Tekilleştir
    final seen = <SpiritualQuote>{};
    final uniqueQuotes = allQuotes.where((q) => seen.add(q)).toList();

    return uniqueQuotes.where((q) {
      if (_selectedTopic != 'all' && q.topic != _selectedTopic) {
        return false;
      }
      if (_selectedTypeFilter != null && q.type != _selectedTypeFilter) {
        return false;
      }
      if (_searchQuery.trim().isNotEmpty) {
        final query = _searchQuery.trim().toLowerCase();
        final matchesText = q.text.toLowerCase().contains(query);
        final matchesSource = q.source.toLowerCase().contains(query);
        return matchesText || matchesSource;
      }
      return true;
    }).toList();
  }

  void _pickRandomFromFiltered(List<SpiritualQuote> filtered) {
    HapticFeedback.mediumImpact();
    final pool =
        filtered.isNotEmpty ? filtered : ShareCardDataHelper.curatedQuotes;
    final picked = ShareCardDataHelper.nextRandomQuote(
      topic: _selectedTopic,
      avoidQuote: widget.currentQuote,
      filterType: _selectedTypeFilter,
      acrossAllTopics: _selectedTopic == 'all',
    );
    Navigator.of(context).pop(pool.contains(picked) ? picked : pool.first);
  }

  void _submitCustomQuote() {
    final text = _customTextController.text.trim();
    if (text.isEmpty) return;
    final src = _customSourceController.text.trim().isNotEmpty
        ? _customSourceController.text.trim()
        : (_customType == SpiritualQuoteType.ayet
            ? 'Kur’ân-ı Kerîm'
            : 'Hadîs-i Şerîf');
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop(
      SpiritualQuote(
        text: text,
        source: src,
        type: _customType,
        topic: widget.initialTopic == 'all' ? 'zikir' : widget.initialTopic,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filteredQuotes = _buildFilteredList();
    final sheetHeight = MediaQuery.of(context).size.height * 0.82;

    return Container(
      height: sheetHeight,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131920) : const Color(0xFFFDFBF7),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 30,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 4.5,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.menu_book_rounded,
                      color: AppColors.gold500,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Ayet & Hadis Seç',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    // Rastgele Seç Butonu
                    TextButton.icon(
                      onPressed: () => _pickRandomFromFiltered(filteredQuotes),
                      style: TextButton.styleFrom(
                        backgroundColor:
                            AppColors.gold500.withValues(alpha: 0.16),
                        foregroundColor: isDark
                            ? AppColors.gold400
                            : const Color(0xFF92400E),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.casino_rounded, size: 16),
                      label: const Text(
                        'Rastgele Seç',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                      color: isDark ? Colors.white54 : Colors.black54,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Arama Çubuğu + Özel Metin Ekle Butonu
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style: TextStyle(
                      fontSize: 13.5,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Ayet, hadis, sûre veya konu ara...',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        size: 19,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF1A232E)
                          : const Color(0xFFF2ECE1),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _showCustomInput = !_showCustomInput);
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: _showCustomInput
                          ? AppColors.gold500
                          : (isDark
                              ? const Color(0xFF1A232E)
                              : const Color(0xFFF2ECE1)),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.gold500.withValues(alpha: 0.45),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.edit_note_rounded,
                          size: 18,
                          color: _showCustomInput
                              ? Colors.black
                              : AppColors.gold500,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Özel Yaz',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _showCustomInput
                                ? Colors.black
                                : (isDark ? Colors.white : Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Özel Ayet / Hadis Yazma Paneli (Açılırsa)
          if (_showCustomInput)
            Container(
              margin: const EdgeInsets.fromLTRB(20, 10, 20, 4),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1A232E)
                    : const Color(0xFFF5EFE2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.gold500.withValues(alpha: 0.5),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text(
                          '📖 Âyet-i Kerîme',
                          style: TextStyle(fontSize: 11.5),
                        ),
                        selected: _customType == SpiritualQuoteType.ayet,
                        onSelected: (_) => setState(
                          () => _customType = SpiritualQuoteType.ayet,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text(
                          '📜 Hadîs / Hikmetli Söz',
                          style: TextStyle(fontSize: 11.5),
                        ),
                        selected: _customType == SpiritualQuoteType.hadis,
                        onSelected: (_) => setState(
                          () => _customType = SpiritualQuoteType.hadis,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _customTextController,
                    maxLines: 2,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Paylaşım kartında görünecek metni yazın...',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF131920) : Colors.white,
                      contentPadding: const EdgeInsets.all(10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _customSourceController,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Kaynak (Örn: Bakara Sûresi, 286)',
                            filled: true,
                            fillColor: isDark
                                ? const Color(0xFF131920)
                                : Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _submitCustomQuote,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.gold500,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Karta Uygula',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          const SizedBox(height: 10),

          // Tür Filtresi: Tümü | 📖 Ayetler | 📜 Hadisler
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _buildTypeFilterChip(
                  label: 'Tümü (${filteredQuotes.length})',
                  isSelected: _selectedTypeFilter == null,
                  onTap: () => setState(() => _selectedTypeFilter = null),
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildTypeFilterChip(
                  label: '📖 Sadece Ayetler',
                  isSelected: _selectedTypeFilter == SpiritualQuoteType.ayet,
                  onTap: () => setState(
                    () => _selectedTypeFilter = SpiritualQuoteType.ayet,
                  ),
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildTypeFilterChip(
                  label: '📜 Sadece Hadisler',
                  isSelected: _selectedTypeFilter == SpiritualQuoteType.hadis,
                  onTap: () => setState(
                    () => _selectedTypeFilter = SpiritualQuoteType.hadis,
                  ),
                  isDark: isDark,
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Konu Kategorileri Yatay Şeridi
          SizedBox(
            height: 34,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: ShareCardDataHelper.topicCategories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final cat = ShareCardDataHelper.topicCategories[index];
                final isSelected = _selectedTopic == cat['id'];
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedTopic = cat['id']!);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.gold500.withValues(alpha: 0.22)
                          : (isDark
                              ? const Color(0xFF1A232E)
                              : const Color(0xFFF2ECE1)),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.gold500
                            : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          cat['emoji']!,
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          cat['label']!,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: isSelected
                                ? (isDark
                                    ? AppColors.gold400
                                    : const Color(0xFF92400E))
                                : (isDark ? Colors.white70 : Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 10),

          // Ayet & Hadis Listesi
          Expanded(
            child: filteredQuotes.isEmpty
                ? Center(
                    child: Text(
                      'Arama kriterine uygun âyet veya hadis bulunamadı.',
                      style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    itemCount: filteredQuotes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final quote = filteredQuotes[index];
                      final isSelected = quote == widget.currentQuote;
                      final isAyet = quote.type == SpiritualQuoteType.ayet;

                      return InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Navigator.of(context).pop(quote);
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.gold500.withValues(alpha: 0.14)
                                : (isDark
                                    ? const Color(0xFF1A232E)
                                    : Colors.white),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.gold500
                                  : (isDark
                                      ? Colors.white12
                                      : const Color(0xFFE3D9C6)),
                              width: isSelected ? 1.8 : 1.0,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isAyet
                                          ? const Color(0xFF2E6F52)
                                              .withValues(alpha: 0.16)
                                          : AppColors.gold500
                                              .withValues(alpha: 0.16),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      isAyet
                                          ? '📖 Âyet-i Kerîme'
                                          : '📜 Hadîs-i Şerîf',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: isAyet
                                            ? (isDark
                                                ? const Color(0xFF6EE7B7)
                                                : const Color(0xFF2E6F52))
                                            : (isDark
                                                ? AppColors.gold400
                                                : const Color(0xFF92400E)),
                                      ),
                                    ),
                                  ),
                                  if (isSelected)
                                    const Icon(
                                      Icons.check_circle_rounded,
                                      color: AppColors.gold500,
                                      size: 18,
                                    ),
                                ],
                              ),
                              if (quote.arabic != null &&
                                  quote.arabic!.trim().isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    quote.arabic!,
                                    textAlign: TextAlign.right,
                                    textDirection: TextDirection.rtl,
                                    style: TextStyle(
                                      fontFamily: 'AmasyaAbay',
                                      fontSize: 17,
                                      color: isDark
                                          ? const Color(0xFFF5EFE6)
                                          : const Color(0xFF2D2016),
                                      height: 1.6,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                              Text(
                                '“${quote.text}”',
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF382A1E),
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                quote.source,
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? Colors.white60
                                      : const Color(0xFF6B5848),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.gold500
              : (isDark ? const Color(0xFF1A232E) : const Color(0xFFF2ECE1)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected
                ? Colors.black
                : (isDark ? Colors.white70 : Colors.black87),
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
