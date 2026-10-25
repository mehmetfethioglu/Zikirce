import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kütüphane rafındaki kitap kategorileri
enum IslamicBookCategory {
  quran,
  meal,
  tafseer,
  hadith,
  risale,
}

extension IslamicBookCategoryExt on IslamicBookCategory {
  String get label {
    switch (this) {
      case IslamicBookCategory.quran:
        return 'Kur’ân-ı Kerîm';
      case IslamicBookCategory.meal:
        return 'Meâller';
      case IslamicBookCategory.tafseer:
        return 'Tefsirler';
      case IslamicBookCategory.hadith:
        return 'Kütüb-i Sitte & Hadis';
      case IslamicBookCategory.risale:
        return 'Risale-i Nur Külliyatı';
    }
  }
}

/// Klasik İslâmî Cilt ve Tezhip Renk Paleti
class BookCoverPalette {
  final int index;
  final String name;
  final Color primaryLeather;
  final Color secondaryLeather;
  final Color goldAccent;
  final Color spineColor;
  final Color textColor;

  const BookCoverPalette({
    required this.index,
    required this.name,
    required this.primaryLeather,
    required this.secondaryLeather,
    required this.goldAccent,
    required this.spineColor,
    this.textColor = const Color(0xFFFDF8EE),
  });

  static const List<BookCoverPalette> palettes = [
    BookCoverPalette(
      index: 0,
      name: 'Hünkâr Zümrüdü',
      primaryLeather: Color(0xFF123F30),
      secondaryLeather: Color(0xFF0A241B),
      goldAccent: Color(0xFFD4AF37),
      spineColor: Color(0xFF0E3226),
    ),
    BookCoverPalette(
      index: 1,
      name: 'Osmanlı Yakutu',
      primaryLeather: Color(0xFF4E141C),
      secondaryLeather: Color(0xFF2B090E),
      goldAccent: Color(0xFFE5C158),
      spineColor: Color(0xFF3B0E15),
    ),
    BookCoverPalette(
      index: 2,
      name: 'Semerkand Lâciverdi',
      primaryLeather: Color(0xFF162944),
      secondaryLeather: Color(0xFF0C1728),
      goldAccent: Color(0xFFDFB85C),
      spineColor: Color(0xFF102036),
    ),
    BookCoverPalette(
      index: 3,
      name: 'Kâbe Kisvesi',
      primaryLeather: Color(0xFF1C1C20),
      secondaryLeather: Color(0xFF0F0F12),
      goldAccent: Color(0xFFD4AF37),
      spineColor: Color(0xFF141417),
    ),
    BookCoverPalette(
      index: 4,
      name: 'Endülüs Kehribarı',
      primaryLeather: Color(0xFF523214),
      secondaryLeather: Color(0xFF301C0A),
      goldAccent: Color(0xFFF0C96B),
      spineColor: Color(0xFF3F250E),
    ),
    BookCoverPalette(
      index: 5,
      name: 'Uhud Turkuazı',
      primaryLeather: Color(0xFF134047),
      secondaryLeather: Color(0xFF0A2327),
      goldAccent: Color(0xFFD6B45A),
      spineColor: Color(0xFF0E3136),
    ),
    BookCoverPalette(
      index: 6,
      name: 'Buhara Mürdümü',
      primaryLeather: Color(0xFF3B1A3D),
      secondaryLeather: Color(0xFF200D22),
      goldAccent: Color(0xFFE2BE62),
      spineColor: Color(0xFF2C122E),
    ),
    BookCoverPalette(
      index: 7,
      name: 'Tahrir Deri Kahvesi',
      primaryLeather: Color(0xFF4A3321),
      secondaryLeather: Color(0xFF2A1C11),
      goldAccent: Color(0xFFE6C675),
      spineColor: Color(0xFF382618),
    ),
  ];

  static BookCoverPalette byIndex(int idx) {
    return palettes[idx.clamp(0, palettes.length - 1)];
  }
}

/// Külliyat rafındaki tek bir kitabın modeli
class IslamicShelfBook {
  final String id;
  final String title;
  final String shortTitle;
  final String author;
  final String subtitle;
  final IslamicBookCategory category;
  final int shelfNumber;
  final int sortOrder;
  final bool isVisible;

  /// Okuma ilerlemesi (1..totalPages)
  final int currentPage;
  final int totalPages;
  final bool hasStartedReading;

  /// Cilt/Sırt özelleştirme alanları (İkonsuz klasik cilt)
  final int paletteIndex;
  final int coverStyle; // 0: Osmanlı Şemse, 1: Kemerli Mihrap, 2: Minimalist Tahrir, 3: Hendese
  final String emblem;

  /// Bağlı veri kaynağı (mushaf, meal sourceId, tafseer sourceId, hadith veya risale sourceKey)
  final String sourceKey;

  const IslamicShelfBook({
    required this.id,
    required this.title,
    required this.shortTitle,
    required this.author,
    required this.subtitle,
    required this.category,
    this.shelfNumber = 2,
    required this.sortOrder,
    this.isVisible = true,
    this.currentPage = 1,
    required this.totalPages,
    this.hasStartedReading = false,
    required this.paletteIndex,
    this.coverStyle = 0,
    this.emblem = '',
    required this.sourceKey,
  });

  double get progressFraction {
    if (!hasStartedReading || totalPages <= 0) return 0.0;
    return (currentPage / totalPages).clamp(0.0, 1.0);
  }

  int get progressPercent {
    if (!hasStartedReading || totalPages <= 0) return 0;
    final pct = ((currentPage / totalPages) * 100).round();
    return pct.clamp(1, 100);
  }

  BookCoverPalette get palette => BookCoverPalette.byIndex(paletteIndex);

  IslamicShelfBook copyWith({
    String? title,
    String? shortTitle,
    String? author,
    String? subtitle,
    IslamicBookCategory? category,
    int? shelfNumber,
    int? sortOrder,
    bool? isVisible,
    int? currentPage,
    int? totalPages,
    bool? hasStartedReading,
    int? paletteIndex,
    int? coverStyle,
    String? emblem,
    String? sourceKey,
  }) {
    return IslamicShelfBook(
      id: id,
      title: title ?? this.title,
      shortTitle: shortTitle ?? this.shortTitle,
      author: author ?? this.author,
      subtitle: subtitle ?? this.subtitle,
      category: category ?? this.category,
      shelfNumber: shelfNumber ?? this.shelfNumber,
      sortOrder: sortOrder ?? this.sortOrder,
      isVisible: isVisible ?? this.isVisible,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      hasStartedReading: hasStartedReading ?? this.hasStartedReading,
      paletteIndex: paletteIndex ?? this.paletteIndex,
      coverStyle: coverStyle ?? this.coverStyle,
      emblem: emblem ?? this.emblem,
      sourceKey: sourceKey ?? this.sourceKey,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'shelfNumber': shelfNumber,
        'sortOrder': sortOrder,
        'isVisible': isVisible,
        'currentPage': currentPage,
        'totalPages': totalPages,
        'hasStartedReading': hasStartedReading,
        'paletteIndex': paletteIndex,
        'coverStyle': coverStyle,
      };
}

/// Kitap Ayraç (Bookmark) Modeli
class BookBookmarkItem {
  final String id;
  final String bookId;
  final int pageNumber;
  final String title;
  final String snippet;
  final DateTime createdAt;

  const BookBookmarkItem({
    required this.id,
    required this.bookId,
    required this.pageNumber,
    required this.title,
    required this.snippet,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'bookId': bookId,
        'pageNumber': pageNumber,
        'title': title,
        'snippet': snippet,
        'createdAt': createdAt.toIso8601String(),
      };

  factory BookBookmarkItem.fromJson(Map<String, dynamic> json) {
    return BookBookmarkItem(
      id: (json['id'] as String?) ?? '',
      bookId: (json['bookId'] as String?) ?? '',
      pageNumber: (json['pageNumber'] as num?)?.toInt() ?? 1,
      title: (json['title'] as String?) ?? '',
      snippet: (json['snippet'] as String?) ?? '',
      createdAt: DateTime.tryParse((json['createdAt'] as String?) ?? '') ??
          DateTime.now(),
    );
  }
}

/// Kitap Vurgulama (Highlight) Modeli
class BookHighlightItem {
  final String id;
  final String bookId;
  final int pageNumber;
  final String selectedText;
  final String referenceLabel;
  final int colorIndex; // 0: Kehribar, 1: Zümrüt, 2: Semerkand Mavi, 3: Yakut
  final DateTime createdAt;

  const BookHighlightItem({
    required this.id,
    required this.bookId,
    required this.pageNumber,
    required this.selectedText,
    required this.referenceLabel,
    this.colorIndex = 0,
    required this.createdAt,
  });

  static Color colorForIndex(int index, {bool isDark = false}) {
    switch (index) {
      case 0: // Kehribar Sarısı
        return isDark
            ? const Color(0xFFD4AF37).withValues(alpha: 0.32)
            : const Color(0xFFF6D365).withValues(alpha: 0.45);
      case 1: // Zümrüt Yeşili
        return isDark
            ? const Color(0xFF2E9E6B).withValues(alpha: 0.34)
            : const Color(0xFF84E1BC).withValues(alpha: 0.45);
      case 2: // Semerkand Mavisi
        return isDark
            ? const Color(0xFF4A90E2).withValues(alpha: 0.34)
            : const Color(0xFF93C5FD).withValues(alpha: 0.45);
      case 3: // Osmanlı Yakutu
        return isDark
            ? const Color(0xFFE05260).withValues(alpha: 0.34)
            : const Color(0xFFFCA5A5).withValues(alpha: 0.45);
      default:
        return const Color(0xFFF6D365).withValues(alpha: 0.45);
    }
  }

  static Color badgeColorForIndex(int index) {
    switch (index) {
      case 0:
        return const Color(0xFFD4AF37);
      case 1:
        return const Color(0xFF1F8A5B);
      case 2:
        return const Color(0xFF2B6CB0);
      case 3:
        return const Color(0xFFB83240);
      default:
        return const Color(0xFFD4AF37);
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'bookId': bookId,
        'pageNumber': pageNumber,
        'selectedText': selectedText,
        'referenceLabel': referenceLabel,
        'colorIndex': colorIndex,
        'createdAt': createdAt.toIso8601String(),
      };

  factory BookHighlightItem.fromJson(Map<String, dynamic> json) {
    return BookHighlightItem(
      id: (json['id'] as String?) ?? '',
      bookId: (json['bookId'] as String?) ?? '',
      pageNumber: (json['pageNumber'] as num?)?.toInt() ?? 1,
      selectedText: (json['selectedText'] as String?) ?? '',
      referenceLabel: (json['referenceLabel'] as String?) ?? '',
      colorIndex: (json['colorIndex'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse((json['createdAt'] as String?) ?? '') ??
          DateTime.now(),
    );
  }
}

class IslamicBookAnnotationsState {
  final List<BookBookmarkItem> bookmarks;
  final List<BookHighlightItem> highlights;

  const IslamicBookAnnotationsState({
    this.bookmarks = const [],
    this.highlights = const [],
  });

  bool isBookmarked(String bookId, int pageNumber) {
    return bookmarks.any((b) => b.bookId == bookId && b.pageNumber == pageNumber);
  }

  List<BookBookmarkItem> bookmarksForBook(String bookId) {
    return bookmarks.where((b) => b.bookId == bookId).toList()
      ..sort((a, b) => a.pageNumber.compareTo(b.pageNumber));
  }

  List<BookHighlightItem> highlightsForBook(String bookId) {
    return highlights.where((h) => h.bookId == bookId).toList()
      ..sort((a, b) => a.pageNumber.compareTo(b.pageNumber));
  }

  List<BookHighlightItem> highlightsForPage(String bookId, int pageNumber) {
    return highlights
        .where((h) => h.bookId == bookId && h.pageNumber == pageNumber)
        .toList();
  }
}

class IslamicBookAnnotationsNotifier
    extends StateNotifier<IslamicBookAnnotationsState> {
  static const String _bookmarksKey = 'zikirce_book_bookmarks_v1';
  static const String _highlightsKey = 'zikirce_book_highlights_v1';

  IslamicBookAnnotationsNotifier()
      : super(const IslamicBookAnnotationsState()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawB = prefs.getString(_bookmarksKey);
      final rawH = prefs.getString(_highlightsKey);

      final loadedB = <BookBookmarkItem>[];
      if (rawB != null && rawB.isNotEmpty) {
        final list = jsonDecode(rawB) as List<dynamic>;
        for (final item in list) {
          if (item is Map<String, dynamic>) {
            loadedB.add(BookBookmarkItem.fromJson(item));
          }
        }
      }

      final loadedH = <BookHighlightItem>[];
      if (rawH != null && rawH.isNotEmpty) {
        final list = jsonDecode(rawH) as List<dynamic>;
        for (final item in list) {
          if (item is Map<String, dynamic>) {
            loadedH.add(BookHighlightItem.fromJson(item));
          }
        }
      }

      state = IslamicBookAnnotationsState(
        bookmarks: loadedB,
        highlights: loadedH,
      );
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _bookmarksKey,
        jsonEncode(state.bookmarks.map((e) => e.toJson()).toList()),
      );
      await prefs.setString(
        _highlightsKey,
        jsonEncode(state.highlights.map((e) => e.toJson()).toList()),
      );
    } catch (_) {}
  }

  Future<bool> toggleBookmark({
    required String bookId,
    required int pageNumber,
    required String title,
    required String snippet,
  }) async {
    final exists = state.isBookmarked(bookId, pageNumber);
    if (exists) {
      state = IslamicBookAnnotationsState(
        bookmarks: state.bookmarks
            .where((b) => !(b.bookId == bookId && b.pageNumber == pageNumber))
            .toList(),
        highlights: state.highlights,
      );
      await _save();
      return false;
    } else {
      final item = BookBookmarkItem(
        id: '${bookId}_${pageNumber}_${DateTime.now().millisecondsSinceEpoch}',
        bookId: bookId,
        pageNumber: pageNumber,
        title: title,
        snippet: snippet.length > 140 ? '${snippet.substring(0, 140)}…' : snippet,
        createdAt: DateTime.now(),
      );
      state = IslamicBookAnnotationsState(
        bookmarks: [...state.bookmarks, item],
        highlights: state.highlights,
      );
      await _save();
      return true;
    }
  }

  Future<void> removeBookmark(String id) async {
    state = IslamicBookAnnotationsState(
      bookmarks: state.bookmarks.where((b) => b.id != id).toList(),
      highlights: state.highlights,
    );
    await _save();
  }

  Future<void> addHighlight({
    required String bookId,
    required int pageNumber,
    required String selectedText,
    required String referenceLabel,
    required int colorIndex,
  }) async {
    final cleaned = selectedText.trim();
    if (cleaned.isEmpty) return;
    final item = BookHighlightItem(
      id: '${bookId}_${pageNumber}_${DateTime.now().millisecondsSinceEpoch}',
      bookId: bookId,
      pageNumber: pageNumber,
      selectedText: cleaned,
      referenceLabel: referenceLabel,
      colorIndex: colorIndex,
      createdAt: DateTime.now(),
    );
    state = IslamicBookAnnotationsState(
      bookmarks: state.bookmarks,
      highlights: [...state.highlights, item],
    );
    await _save();
  }

  Future<void> removeHighlight(String id) async {
    state = IslamicBookAnnotationsState(
      bookmarks: state.bookmarks,
      highlights: state.highlights.where((h) => h.id != id).toList(),
    );
    await _save();
  }
}

final islamicBookAnnotationsProvider = StateNotifierProvider<
    IslamicBookAnnotationsNotifier, IslamicBookAnnotationsState>((ref) {
  return IslamicBookAnnotationsNotifier();
});

/// Kitap İçi Font ve Sayfa Düzeni Ayarları Modeli (Tahrir Standardı)
class IslamicBookReaderSettings {
  /// 0: Parşömen (#FBF3E2), 1: Klasik Sahife (#F8F9FA), 2: Safir Gece (#0D1B2A),
  /// 3: Zümrüt (#0C201B), 4: Tam Siyah AMOLED (#000000)
  final int themeIndex;
  final String fontFamily; // 'Merriweather', 'Lora', 'Crimson Pro', 'Plus Jakarta Sans', 'Amiri'
  final double arabicFontSize;
  final double turkishFontSize;
  final double lineHeight;
  final double horizontalMargin; // 14, 22, 32
  final bool justifyText;
  final bool showArabicText;
  final bool isFlowingBookLayout; // true: Akıcı Kitap Sayfası, false: Kart Düzeni

  const IslamicBookReaderSettings({
    this.themeIndex = 0,
    this.fontFamily = 'Merriweather',
    this.arabicFontSize = 24.0,
    this.turkishFontSize = 16.5,
    this.lineHeight = 1.65,
    this.horizontalMargin = 20.0,
    this.justifyText = true,
    this.showArabicText = true,
    this.isFlowingBookLayout = true,
  });

  Color get backgroundColor {
    switch (themeIndex) {
      case 0:
        return const Color(0xFFFBF3E2);
      case 1:
        return const Color(0xFFF8F9FA);
      case 2:
        return const Color(0xFF0D1B2A);
      case 3:
        return const Color(0xFF0C201B);
      case 4:
        return const Color(0xFF000000);
      default:
        return const Color(0xFFFBF3E2);
    }
  }

  Color get cardColor {
    switch (themeIndex) {
      case 0:
        return const Color(0xFFF5E8CE);
      case 1:
        return const Color(0xFFFFFFFF);
      case 2:
        return const Color(0xFF14273D);
      case 3:
        return const Color(0xFF132E27);
      case 4:
        return const Color(0xFF121212);
      default:
        return const Color(0xFFF5E8CE);
    }
  }

  Color get textColor {
    switch (themeIndex) {
      case 0:
        return const Color(0xFF2B1E16);
      case 1:
        return const Color(0xFF1E242B);
      case 2:
        return const Color(0xFFE5ECF4);
      case 3:
        return const Color(0xFFE6F2EE);
      case 4:
        return const Color(0xFFE8E6E3);
      default:
        return const Color(0xFF2B1E16);
    }
  }

  Color get accentColor {
    switch (themeIndex) {
      case 0:
        return const Color(0xFF8C5828);
      case 1:
        return const Color(0xFF1B5E4A);
      case 2:
        return const Color(0xFFD4AF37);
      case 3:
        return const Color(0xFFD4AF37);
      case 4:
        return const Color(0xFFC5A358);
      default:
        return const Color(0xFF8C5828);
    }
  }

  bool get isDarkTheme => themeIndex >= 2;

  IslamicBookReaderSettings copyWith({
    int? themeIndex,
    String? fontFamily,
    double? arabicFontSize,
    double? turkishFontSize,
    double? lineHeight,
    double? horizontalMargin,
    bool? justifyText,
    bool? showArabicText,
    bool? isFlowingBookLayout,
  }) {
    return IslamicBookReaderSettings(
      themeIndex: themeIndex ?? this.themeIndex,
      fontFamily: fontFamily ?? this.fontFamily,
      arabicFontSize: arabicFontSize ?? this.arabicFontSize,
      turkishFontSize: turkishFontSize ?? this.turkishFontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      horizontalMargin: horizontalMargin ?? this.horizontalMargin,
      justifyText: justifyText ?? this.justifyText,
      showArabicText: showArabicText ?? this.showArabicText,
      isFlowingBookLayout: isFlowingBookLayout ?? this.isFlowingBookLayout,
    );
  }

  Map<String, dynamic> toJson() => {
        'themeIndex': themeIndex,
        'fontFamily': fontFamily,
        'arabicFontSize': arabicFontSize,
        'turkishFontSize': turkishFontSize,
        'lineHeight': lineHeight,
        'horizontalMargin': horizontalMargin,
        'justifyText': justifyText,
        'showArabicText': showArabicText,
        'isFlowingBookLayout': isFlowingBookLayout,
      };

  factory IslamicBookReaderSettings.fromJson(Map<String, dynamic> json) {
    return IslamicBookReaderSettings(
      themeIndex: (json['themeIndex'] as num?)?.toInt() ?? 0,
      fontFamily: (json['fontFamily'] as String?) ?? 'Merriweather',
      arabicFontSize: (json['arabicFontSize'] as num?)?.toDouble() ?? 24.0,
      turkishFontSize: (json['turkishFontSize'] as num?)?.toDouble() ?? 16.5,
      lineHeight: (json['lineHeight'] as num?)?.toDouble() ?? 1.65,
      horizontalMargin: (json['horizontalMargin'] as num?)?.toDouble() ?? 20.0,
      justifyText: (json['justifyText'] as bool?) ?? true,
      showArabicText: (json['showArabicText'] as bool?) ?? true,
      isFlowingBookLayout: (json['isFlowingBookLayout'] as bool?) ?? true,
    );
  }
}

/// Varsayılan Külliyat Kataloğu (Kur'ân, Meâller, 6.236 Âyetlik Tefsirler, Tam Hacim Kütüb-i Sitte ve Risale-i Nur)
class IslamicBookshelfCatalog {
  static List<IslamicShelfBook> defaultBooks() {
    return const [
      // ==================== KUR'ÂN-I KERÎM & MEÂLLER ====================
      IslamicShelfBook(
        id: 'book_mushaf',
        title: 'Kur’ân-ı Kerîm (Mushaf-ı Şerîf)',
        shortTitle: 'Kur’ân-ı Kerîm',
        author: 'Diyanet Mushafları İnceleme Kurulu',
        subtitle: '604 Sayfa • Medîne & Hâfız Osman Hattı',
        category: IslamicBookCategory.quran,
        sortOrder: 0,
        totalPages: 604,
        paletteIndex: 0, // Hünkâr Zümrüdü
        coverStyle: 0,
        sourceKey: 'mushaf',
      ),
      IslamicShelfBook(
        id: 'book_meal_diyanet',
        title: 'Diyanet Vakfı Kur’ân-ı Kerîm Meâli',
        shortTitle: 'Diyanet Vakfı Meâli',
        author: 'Türkiye Diyanet Vakfı Heyeti',
        subtitle: '114 Sûre • 604 Sayfa • Açıklamalı Türkçe Meâl',
        category: IslamicBookCategory.meal,
        sortOrder: 1,
        totalPages: 604,
        paletteIndex: 4, // Endülüs Kehribarı
        coverStyle: 1,
        sourceKey: 'diyanet_vakfi',
      ),
      IslamicShelfBook(
        id: 'book_meal_elmalili_sade',
        title: 'Elmalılı Hamdi Yazır Meâli',
        shortTitle: 'Elmalılı Meâli',
        author: 'Elmalılı M. Hamdi Yazır',
        subtitle: 'Hak Dîni Kur’ân Dili • 604 Sayfa',
        category: IslamicBookCategory.meal,
        sortOrder: 2,
        totalPages: 604,
        paletteIndex: 7, // Tahrir Deri Kahvesi
        coverStyle: 2,
        sourceKey: 'elmalili_sade',
      ),
      IslamicShelfBook(
        id: 'book_meal_cantay',
        title: 'Kur’ân-ı Hakîm ve Meâl-i Kerîm',
        shortTitle: 'Hasan Basri Çantay',
        author: 'Hasan Basri Çantay',
        subtitle: 'Klasik İzahlı Türkçe Meâl • 604 Sayfa',
        category: IslamicBookCategory.meal,
        sortOrder: 3,
        totalPages: 604,
        paletteIndex: 4,
        coverStyle: 0,
        sourceKey: 'cantay',
      ),

      // ==================== TEFSİRLER (HER ÂYET 1 SAYFA = 6.236 SAYFA) ====================
      IslamicShelfBook(
        id: 'book_tafseer_kuran_yolu',
        title: 'Kur’ân Yolu Türkçe Meâl ve Tefsir',
        shortTitle: 'Kur’ân Yolu Tefsiri',
        author: 'Karaman, Çağrıcı, Dönmez, Gümüş',
        subtitle: 'DİB Yayınları • 6.236 Âyet Tam Külliyat',
        category: IslamicBookCategory.tafseer,
        sortOrder: 4,
        totalPages: 6236,
        paletteIndex: 2, // Semerkand Lâciverdi
        coverStyle: 0,
        sourceKey: 'kuran_yolu',
      ),
      IslamicShelfBook(
        id: 'book_tafseer_maturidi',
        title: 'Te’vîlâtü’l-Kur’ân (Mâtürîdî Tefsiri)',
        shortTitle: 'Te’vîlâtü’l-Kur’ân',
        author: 'İmam Ebû Mansûr el-Mâtürîdî',
        subtitle: 'Ehl-i Sünnet Kelâm Tefsiri • 6.236 Âyet',
        category: IslamicBookCategory.tafseer,
        sortOrder: 5,
        totalPages: 6236,
        paletteIndex: 3,
        coverStyle: 0,
        sourceKey: 'tevilatul_kuran',
      ),
      IslamicShelfBook(
        id: 'book_tafseer_beyzavi',
        title: 'Envârü’t-Tenzîl ve Esrârü’t-Te’vîl',
        shortTitle: 'Beyzâvî Tefsiri',
        author: 'Kâdî Nâsırüddîn el-Beyzâvî',
        subtitle: 'Medrese Başucu Tefsiri • 6.236 Âyet',
        category: IslamicBookCategory.tafseer,
        sortOrder: 6,
        totalPages: 6236,
        paletteIndex: 5,
        coverStyle: 1,
        sourceKey: 'envarut_tenzil',
      ),
      IslamicShelfBook(
        id: 'book_tafseer_razi',
        title: 'Mefâtîhu’l-Gayb (Tefsîr-i Kebîr)',
        shortTitle: 'Tefsîr-i Kebîr (Râzî)',
        author: 'Fahreddîn er-Râzî',
        subtitle: 'Hikmet ve Kelâm Ansiklopedisi • 6.236 Âyet',
        category: IslamicBookCategory.tafseer,
        sortOrder: 7,
        totalPages: 6236,
        paletteIndex: 7,
        coverStyle: 3,
        sourceKey: 'mefatihul_gayb',
      ),
      IslamicShelfBook(
        id: 'book_tafseer_kessaf',
        title: 'el-Keşşâf an Hakâikı’t-Tenzîl',
        shortTitle: 'el-Keşşâf',
        author: 'Cârullah ez-Zemahşerî',
        subtitle: 'Belâgat ve İ’câz Tefsiri • 6.236 Âyet',
        category: IslamicBookCategory.tafseer,
        sortOrder: 8,
        totalPages: 6236,
        paletteIndex: 1,
        coverStyle: 2,
        sourceKey: 'el_kessaf',
      ),

      // ==================== KÜTÜB-İ SİTTE & HADİS KÜLLİYATI (TAM HACİM) ====================
      IslamicShelfBook(
        id: 'book_hadith_buhari',
        title: 'Sahîh-i Buhârî (el-Câmiu’s-Sahîh)',
        shortTitle: 'Sahîh-i Buhârî',
        author: 'İmam Muhammed b. İsmâil el-Buhârî',
        subtitle: 'Kütüb-i Sitte • 97 Kitap • 7.521 Hadis Tam Metin',
        category: IslamicBookCategory.hadith,
        sortOrder: 9,
        totalPages: 7521,
        paletteIndex: 1, // Osmanlı Yakutu
        coverStyle: 3,
        sourceKey: 'buhari',
      ),
      IslamicShelfBook(
        id: 'book_hadith_muslim',
        title: 'Sahîh-i Müslim (el-Câmiu’s-Sahîh)',
        shortTitle: 'Sahîh-i Müslim',
        author: 'İmam Müslim b. el-Haccâc el-Kuşeyrî',
        subtitle: 'Kütüb-i Sitte • 56 Kitap • 7.380 Hadis Tam Metin',
        category: IslamicBookCategory.hadith,
        sortOrder: 10,
        totalPages: 7380,
        paletteIndex: 0,
        coverStyle: 0,
        sourceKey: 'muslim',
      ),
      IslamicShelfBook(
        id: 'book_hadith_tirmizi',
        title: 'Sünen-i Tirmizî (el-Câmiu’s-Sahîh)',
        shortTitle: 'Sünen-i Tirmizî',
        author: 'İmam Ebû Îsâ Muhammed et-Tirmizî',
        subtitle: 'Kütüb-i Sitte • 49 Kitap • 3.769 Hadis Tam Metin',
        category: IslamicBookCategory.hadith,
        sortOrder: 11,
        totalPages: 3769,
        paletteIndex: 1,
        coverStyle: 1,
        sourceKey: 'tirmizi',
      ),
      IslamicShelfBook(
        id: 'book_hadith_ebu_davud',
        title: 'Sünen-i Ebû Dâvûd',
        shortTitle: 'Sünen-i Ebû Dâvûd',
        author: 'İmam Ebû Dâvûd Süleyman es-Sicistânî',
        subtitle: 'Kütüb-i Sitte • 43 Kitap • 5.266 Hadis Tam Metin',
        category: IslamicBookCategory.hadith,
        sortOrder: 12,
        totalPages: 5266,
        paletteIndex: 2,
        coverStyle: 2,
        sourceKey: 'ebu_davud',
      ),
      IslamicShelfBook(
        id: 'book_hadith_nesai',
        title: 'Sünen-i Nesâî (el-Müctebâ)',
        shortTitle: 'Sünen-i Nesâî',
        author: 'İmam Ebû Abdurrahmân Ahmed en-Nesâî',
        subtitle: 'Kütüb-i Sitte • 629 Bab & Hadis Külliyatı',
        category: IslamicBookCategory.hadith,
        sortOrder: 13,
        totalPages: 629,
        paletteIndex: 4,
        coverStyle: 3,
        sourceKey: 'nesai',
      ),
      IslamicShelfBook(
        id: 'book_hadith_ibn_mace',
        title: 'Sünen-i İbn Mâce',
        shortTitle: 'Sünen-i İbn Mâce',
        author: 'İmam Ebû Abdullah Muhammed b. Yezîd İbn Mâce',
        subtitle: 'Kütüb-i Sitte • 37 Kitap • 4.319 Hadis Tam Metin',
        category: IslamicBookCategory.hadith,
        sortOrder: 14,
        totalPages: 4319,
        paletteIndex: 6,
        coverStyle: 0,
        sourceKey: 'ibn_mace',
      ),
      IslamicShelfBook(
        id: 'book_hadith_riyazus_salihin',
        title: 'Riyâzü’s-Sâlihîn & Muvatta Külliyatı',
        shortTitle: 'Riyâzü’s-Sâlihîn',
        author: 'İmam Muhyiddîn en-Nevevî & İmam Mâlik',
        subtitle: '60 Bölüm • 1.600 Hadis-i Şerîf Tam Metin',
        category: IslamicBookCategory.hadith,
        sortOrder: 15,
        totalPages: 1600,
        paletteIndex: 5, // Uhud Turkuazı
        coverStyle: 1,
        sourceKey: 'riyazus_salihin',
      ),

      // ==================== RİSALE-İ NUR KÜLLİYATI (DİB ASIL NÜSHA TAM METİN) ====================
      IslamicShelfBook(
        id: 'book_rn_sozler',
        title: 'Sözler (Risale-i Nur Külliyatı)',
        shortTitle: 'Sözler',
        author: 'Bediüzzaman Said Nursî',
        subtitle: 'DİB Asıl Nüsha Tashihli • 33 Söz • 931 Sayfa Tam Metin',
        category: IslamicBookCategory.risale,
        sortOrder: 16,
        totalPages: 931,
        paletteIndex: 1, // Osmanlı Yakutu
        coverStyle: 0,
        sourceKey: 'rn_sozler',
      ),
      IslamicShelfBook(
        id: 'book_rn_mektubat',
        title: 'Mektubat (Risale-i Nur Külliyatı)',
        shortTitle: 'Mektubat',
        author: 'Bediüzzaman Said Nursî',
        subtitle: 'DİB Asıl Nüsha Tashihli • 33 Mektup • 637 Sayfa Tam Metin',
        category: IslamicBookCategory.risale,
        sortOrder: 17,
        totalPages: 637,
        paletteIndex: 0, // Hünkâr Zümrüdü
        coverStyle: 1,
        sourceKey: 'rn_mektubat',
      ),
      IslamicShelfBook(
        id: 'book_rn_lemalar',
        title: 'Lem’alar (Risale-i Nur Külliyatı)',
        shortTitle: 'Lem’alar',
        author: 'Bediüzzaman Said Nursî',
        subtitle: 'DİB Asıl Nüsha Tashihli • 33 Lem’a • 549 Sayfa Tam Metin',
        category: IslamicBookCategory.risale,
        sortOrder: 18,
        totalPages: 549,
        paletteIndex: 2, // Semerkand Lâciverdi
        coverStyle: 0,
        sourceKey: 'rn_lemalar',
      ),
      IslamicShelfBook(
        id: 'book_rn_sualar',
        title: 'Şuâlar (Risale-i Nur Külliyatı)',
        shortTitle: 'Şuâlar',
        author: 'Bediüzzaman Said Nursî',
        subtitle: 'DİB Asıl Nüsha Tashihli • 15 Şuâ • 685 Sayfa Tam Metin',
        category: IslamicBookCategory.risale,
        sortOrder: 19,
        totalPages: 685,
        paletteIndex: 4, // Endülüs Kehribarı
        coverStyle: 3,
        sourceKey: 'rn_sualar',
      ),
      IslamicShelfBook(
        id: 'book_rn_mesnevi',
        title: 'Mesnevî-i Nûriye (Risale-i Nur)',
        shortTitle: 'Mesnevî-i Nûriye',
        author: 'Bediüzzaman Said Nursî',
        subtitle: 'DİB Asıl Nüsha Tashihli • 285 Sayfa Tam Metin',
        category: IslamicBookCategory.risale,
        sortOrder: 20,
        totalPages: 285,
        paletteIndex: 5, // Uhud Turkuazı
        coverStyle: 1,
        sourceKey: 'rn_mesnevi',
      ),
      IslamicShelfBook(
        id: 'book_rn_isaratul_icaz',
        title: 'İşârâtü’l-İ’câz fî Mazânni’l-Îcâz',
        shortTitle: 'İşârâtü’l-İ’câz',
        author: 'Bediüzzaman Said Nursî',
        subtitle: 'Kur’ân Nazmı ve Belâgat Tefsiri • 308 Sayfa Tam Metin',
        category: IslamicBookCategory.risale,
        sortOrder: 21,
        totalPages: 308,
        paletteIndex: 3, // Kâbe Kisvesi
        coverStyle: 0,
        sourceKey: 'rn_isaratul_icaz',
      ),
      IslamicShelfBook(
        id: 'book_rn_asayi_musa',
        title: 'Asâ-yı Mûsâ (Risale-i Nur Külliyatı)',
        shortTitle: 'Asâ-yı Mûsâ',
        author: 'Bediüzzaman Said Nursî',
        subtitle: 'Meyve Risalesi ve Hüccetü’l-Bâliğa • 270 Sayfa Tam Metin',
        category: IslamicBookCategory.risale,
        sortOrder: 22,
        totalPages: 270,
        paletteIndex: 6, // Buhara Mürdümü
        coverStyle: 2,
        sourceKey: 'rn_asayi_musa',
      ),
    ];
  }
}

/// Külliyat Rafı State Notifier (Raf sıralama, cilt özelleştirme ve % ilerleme kaydı)
class IslamicBookshelfNotifier extends StateNotifier<List<IslamicShelfBook>> {
  static const String _prefsKey = 'zikirce_tahrir_bookshelf_v2';

  IslamicBookshelfNotifier() : super(IslamicBookshelfCatalog.defaultBooks()) {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey) ??
          prefs.getString('zikirce_tahrir_bookshelf_v1');
      final lastMushafPage = prefs.getInt('LastReadPage') ?? 1;

      final defaults = IslamicBookshelfCatalog.defaultBooks();
      if (raw == null || raw.isEmpty) {
        if (lastMushafPage > 1) {
          state = defaults.map((b) {
            if (b.id == 'book_mushaf') {
              return b.copyWith(
                currentPage: lastMushafPage.clamp(1, 604),
                hasStartedReading: true,
              );
            }
            return b;
          }).toList();
        }
        return;
      }

      final decoded = jsonDecode(raw) as List<dynamic>;
      final savedMap = <String, Map<String, dynamic>>{};
      for (final item in decoded) {
        if (item is Map<String, dynamic> && item['id'] is String) {
          savedMap[item['id'] as String] = item;
        }
      }

      final merged = defaults.map((def) {
        final s = savedMap[def.id];
        if (s == null) return def;
        int curPage = (s['currentPage'] as num?)?.toInt() ?? def.currentPage;
        bool started =
            (s['hasStartedReading'] as bool?) ?? def.hasStartedReading;
        if (def.id == 'book_mushaf' && lastMushafPage > curPage) {
          curPage = lastMushafPage.clamp(1, 604);
          started = true;
        }
        return def.copyWith(
          shelfNumber: 2,
          sortOrder: (s['sortOrder'] as num?)?.toInt() ?? def.sortOrder,
          isVisible: (s['isVisible'] as bool?) ?? def.isVisible,
          currentPage: curPage.clamp(1, def.totalPages),
          totalPages: def.totalPages,
          hasStartedReading: started,
          paletteIndex:
              (s['paletteIndex'] as num?)?.toInt() ?? def.paletteIndex,
          coverStyle: (s['coverStyle'] as num?)?.toInt() ?? def.coverStyle,
          emblem: '',
        );
      }).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

      state = merged;
    } catch (_) {}
  }

  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(state.map((b) => b.toJson()).toList());
      await prefs.setString(_prefsKey, encoded);
    } catch (_) {}
  }

  /// Kitabın okunan sayfasını ve yüzdesini kaydeder
  Future<void> updateBookProgress(
    String bookId,
    int pageNumber, {
    int? totalPages,
  }) async {
    state = [
      for (final b in state)
        if (b.id == bookId)
          b.copyWith(
            currentPage: pageNumber.clamp(1, totalPages ?? b.totalPages),
            totalPages: totalPages ?? b.totalPages,
            hasStartedReading: true,
          )
        else
          b,
    ];
    await _saveToPrefs();
  }

  /// Mushaf sayfası değiştiğinde Kur'ân-ı Kerîm kitabının yüzdesini senkronize eder
  Future<void> syncMushafPage(int pageNumber) async {
    await updateBookProgress('book_mushaf', pageNumber.clamp(1, 604));
  }

  /// Kitap cilt rengini ve çerçeve stilini günceller (ikonsuz)
  Future<void> customizeBookCover({
    required String bookId,
    required int paletteIndex,
    required int coverStyle,
    String emblem = '',
  }) async {
    state = [
      for (final b in state)
        if (b.id == bookId)
          b.copyWith(
            paletteIndex: paletteIndex,
            coverStyle: coverStyle,
            emblem: '',
          )
        else
          b,
    ];
    await _saveToPrefs();
  }

  /// Kitabın rafta görünürlüğünü açar/kapatır
  Future<void> toggleBookVisibility(String bookId) async {
    state = [
      for (final b in state)
        if (b.id == bookId) b.copyWith(isVisible: !b.isVisible) else b,
    ];
    await _saveToPrefs();
  }

  /// Kitapların raftaki sırasını değiştirir
  Future<void> moveBookOrder(String bookId, int delta) async {
    final idx = state.indexWhere((b) => b.id == bookId);
    if (idx == -1) return;
    final newIdx = idx + delta;
    if (newIdx < 0 || newIdx >= state.length) return;

    final updated = List<IslamicShelfBook>.from(state);
    final item = updated.removeAt(idx);
    updated.insert(newIdx, item);
    for (int i = 0; i < updated.length; i++) {
      updated[i] = updated[i].copyWith(sortOrder: i);
    }

    state = updated;
    await _saveToPrefs();
  }

  /// Raf düzenini ve kapakları varsayılana sıfırlar (okuma yüzdelerini korur)
  Future<void> resetLayoutKeepProgress() async {
    final progressById = {
      for (final b in state) b.id: (b.currentPage, b.hasStartedReading),
    };
    final defaults = IslamicBookshelfCatalog.defaultBooks().map((def) {
      final saved = progressById[def.id];
      if (saved != null) {
        return def.copyWith(
          currentPage: saved.$1.clamp(1, def.totalPages),
          hasStartedReading: saved.$2,
        );
      }
      return def;
    }).toList();
    state = defaults;
    await _saveToPrefs();
  }
}

final islamicBookshelfProvider =
    StateNotifierProvider<IslamicBookshelfNotifier, List<IslamicShelfBook>>(
        (ref) {
  return IslamicBookshelfNotifier();
});

/// Kitap İçi Font ve Sayfa Düzeni Ayarları Notifier
class IslamicBookReaderSettingsNotifier
    extends StateNotifier<IslamicBookReaderSettings> {
  static const String _prefsKey = 'zikirce_book_reader_settings_v1';

  IslamicBookReaderSettingsNotifier()
      : super(const IslamicBookReaderSettings()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        state = IslamicBookReaderSettings.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
      }
    } catch (_) {}
  }

  Future<void> updateSettings(IslamicBookReaderSettings next) async {
    state = next;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(next.toJson()));
    } catch (_) {}
  }
}

final islamicBookReaderSettingsProvider = StateNotifierProvider<
    IslamicBookReaderSettingsNotifier, IslamicBookReaderSettings>((ref) {
  return IslamicBookReaderSettingsNotifier();
});
