import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/islamic_bookshelf_models.dart';
import '../screens/islamic_book_reader_screen.dart';
import '../screens/mushaf_screen.dart';

/// Külliyat Rafı (Tek Raflı, Arkaplansız, Minimalist Tahrir Klasik Sırt Rafı)
/// - Kart arkaplanı, büyük başlık, filtreler ve 1. raf kaldırıldı.
/// - Başlık: Sol tarafta "Külliyat", sağ tarafta sadece minimal "Düzenle" butonu.
/// - Raf yüksekliği %20, kitap kalınlıkları %10 azaltıldı; kitap kapaklarında/sırtlarında ikon bulunmaz.
/// - Kitapların alt bölümünde okuma ilerleme yüzdesi (%XX) gösterilir.
class TahrirBookshelfSection extends ConsumerWidget {
  final Color? primaryTextColor;
  final Color? secondaryTextColor;
  final Color? cardBg;
  final Color? borderStroke;
  final Color? accentColor;
  final bool? isDark;

  const TahrirBookshelfSection({
    super.key,
    this.primaryTextColor,
    this.secondaryTextColor,
    this.cardBg,
    this.borderStroke,
    this.accentColor,
    this.isDark,
  });

  void _openBook(BuildContext context, WidgetRef ref, IslamicShelfBook book) {
    HapticFeedback.lightImpact();
    if (book.category == IslamicBookCategory.quran &&
        book.sourceKey == 'mushaf') {
      final startPage = book.hasStartedReading ? book.currentPage : 1;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MushafScreen(initialPage: startPage),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => IslamicBookReaderScreen(bookId: book.id),
      ),
    );
  }

  void _openUnifiedManagementSheet(
    BuildContext context,
    bool resolvedDark, {
    String? initialCustomizeBookId,
    int initialSection = 0,
  }) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => KulliyatManagementAndSettingsSheet(
        isDark: resolvedDark,
        initialSection: initialSection,
        initialCustomizeBookId: initialCustomizeBookId,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolvedDark =
        isDark ?? (Theme.of(context).brightness == Brightness.dark);
    final resolvedPrimaryText = primaryTextColor ??
        (resolvedDark ? const Color(0xFFF3EFEA) : const Color(0xFF1E2923));
    final resolvedAccent = accentColor ?? const Color(0xFFD4AF37);

    final allBooks = ref.watch(islamicBookshelfProvider);
    final visibleBooks = allBooks.where((b) => b.isVisible).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Başlık Satırı: Sol "Külliyat", Sağ sadece minimal "Düzenle" butonu
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Külliyat',
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.bold,
                color: resolvedPrimaryText,
              ),
            ),
            TextButton(
              onPressed: () =>
                  _openUnifiedManagementSheet(context, resolvedDark),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                backgroundColor: resolvedAccent.withValues(alpha: 0.10),
                foregroundColor: resolvedAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: resolvedAccent.withValues(alpha: 0.25),
                    width: 0.8,
                  ),
                ),
              ),
              child: Text(
                'Düzenle',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: resolvedAccent,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Tek Klasik Dikey Sırt Rafı (%20 azaltılmış yükseklik, %10 azaltılmış kitap kalınlığı)
        if (visibleBooks.isNotEmpty)
          _TahrirClassicalSpineShelf(
            books: visibleBooks,
            isDark: resolvedDark,
            onTapBook: (b) => _openBook(context, ref, b),
            onLongPressBook: (b) => _openUnifiedManagementSheet(
              context,
              resolvedDark,
              initialSection: 1,
              initialCustomizeBookId: b.id,
            ),
          ),
      ],
    );
  }
}

/// Külliyat Rafı: Klasik Dikey Sırt Rafı
/// - Raf yüksekliği %20 azaltıldı (192 -> 152 px)
/// - Kitap kalınlıkları %10 azaltıldı (44 -> 39.5 px)
/// - Kitap sırtlarında/kapaklarında ikon bulunmaz
/// - Alt bölümde okuma ilerleme yüzdesi (%XX) gösterilir
class _TahrirClassicalSpineShelf extends StatelessWidget {
  final List<IslamicShelfBook> books;
  final bool isDark;
  final ValueChanged<IslamicShelfBook> onTapBook;
  final ValueChanged<IslamicShelfBook> onLongPressBook;

  const _TahrirClassicalSpineShelf({
    required this.books,
    required this.isDark,
    required this.onTapBook,
    required this.onLongPressBook,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 152, // %20 azaltılmış raf yüksekliği (192 -> 152)
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // Ahşap Raf Tablası
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _WoodenPlankBar(isDark: isDark, height: 20),
          ),
          // Kitap Sırtları ve Pirinç Kitap Destekleri
          Positioned(
            left: 0,
            right: 0,
            bottom: 15,
            top: 0,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const _BrassBookendWidget(isLeft: true),
                  ...books.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final book = entry.value;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1.8),
                      child: _BookSpineWidget(
                        book: book,
                        index: idx,
                        onTap: () => onTapBook(book),
                        onLongPress: () => onLongPressBook(book),
                      ),
                    );
                  }),
                  const _BrassBookendWidget(isLeft: false),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dikey Kitap Sırtı Widget'ı (%20 daha kısa, %10 daha ince, ikonsuz, alt bölümde %XX ilerleme)
class _BookSpineWidget extends StatelessWidget {
  final IslamicShelfBook book;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _BookSpineWidget({
    required this.book,
    required this.index,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final palette = book.palette;
    final pct = book.progressPercent;
    // %20 azaltılmış yükseklik (158 + (i%2)*8 -> 125 + (i%2)*6)
    final spineHeight = 125.0 + (index % 2) * 6.0;
    // %10 azaltılmış kalınlık (44.0 + (i%3)*3.0 -> 39.5 + (i%3)*2.5)
    final spineWidth = 39.5 + (index % 3) * 2.5;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        width: spineWidth,
        height: spineHeight,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              palette.secondaryLeather,
              palette.primaryLeather,
              palette.spineColor,
            ],
            stops: const [0.0, 0.48, 1.0],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(4),
            bottomLeft: Radius.circular(2),
            bottomRight: Radius.circular(2),
          ),
          border: Border.all(
            color: palette.goldAccent.withValues(alpha: 0.45),
            width: 0.85,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.34),
              blurRadius: 5,
              offset: const Offset(2, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            const SizedBox(height: 5),
            // Üst klasik şiraze çift altın çizgisi (İkonsuz)
            Container(
              height: 1.4,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              color: palette.goldAccent.withValues(alpha: 0.72),
            ),
            const SizedBox(height: 2),
            Container(
              height: 0.8,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              color: palette.goldAccent.withValues(alpha: 0.42),
            ),
            const SizedBox(height: 4),

            // Dikey Kitap İsmi
            Expanded(
              child: Center(
                child: RotatedBox(
                  quarterTurns: 3,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      book.shortTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.merriweather(
                        fontSize: 9.6,
                        fontWeight: FontWeight.w700,
                        color: palette.textColor,
                        letterSpacing: 0.15,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Alt klasik altın çizgi + %XX okuma ilerleme göstergesi
            Container(
              height: 1.1,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              color: palette.goldAccent.withValues(alpha: 0.65),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 3.5, horizontal: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.32),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(2),
                  bottomRight: Radius.circular(2),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '%$pct',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 8.6,
                      fontWeight: FontWeight.w800,
                      color: pct > 0
                          ? palette.goldAccent
                          : palette.textColor.withValues(alpha: 0.65),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: book.progressFraction,
                        minHeight: 2.0,
                        backgroundColor: Colors.white.withValues(alpha: 0.12),
                        valueColor:
                            AlwaysStoppedAnimation<Color>(palette.goldAccent),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tahrir Tarzı Klasik Pirinç Kitap Desteği (Bookend) - %20 azaltılmış yükseklik
class _BrassBookendWidget extends StatelessWidget {
  final bool isLeft;

  const _BrassBookendWidget({required this.isLeft});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 11,
      height: 65, // 82 -> 65 (%20 azaltıldı)
      margin: EdgeInsets.only(
        left: isLeft ? 2 : 3,
        right: isLeft ? 3 : 2,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFE6C76E),
            Color(0xFFB5892E),
            Color(0xFF7D5A16),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(isLeft ? 8 : 2),
          topRight: Radius.circular(isLeft ? 2 : 8),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.32),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );
  }
}

/// Tahrir Tarzı 3 Boyutlu Ceviz Ahşap Raf Tablası
class _WoodenPlankBar extends StatelessWidget {
  final bool isDark;
  final double height;

  const _WoodenPlankBar({
    required this.isDark,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? const [
                  Color(0xFF5A3A22),
                  Color(0xFF3E2615),
                  Color(0xFF28170C),
                ]
              : const [
                  Color(0xFF8C5D38),
                  Color(0xFF6B4223),
                  Color(0xFF4A2C15),
                ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: const Color(0xFFD4AF37).withValues(alpha: 0.35),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.50 : 0.24),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          height: 2.0,
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFE5C158).withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

/// "Düzenle" Butonuyla Açılan Birleşik Külliyat Yönetim Paneli:
/// 1) Raf Düzeni (Sıralama & Görünürlük)
/// 2) Cilt & Sırt Rengi Özelleştirme (İkonsuz klasik cilt)
/// 3) Kitap İçi Sayfa & Font Düzeni Ayarları
class KulliyatManagementAndSettingsSheet extends ConsumerStatefulWidget {
  final bool isDark;
  final int initialSection; // 0: Raf Düzeni, 1: Cilt Özelleştirme, 2: Sayfa & Font Düzeni
  final String? initialCustomizeBookId;

  const KulliyatManagementAndSettingsSheet({
    super.key,
    required this.isDark,
    this.initialSection = 0,
    this.initialCustomizeBookId,
  });

  @override
  ConsumerState<KulliyatManagementAndSettingsSheet> createState() =>
      _KulliyatManagementAndSettingsSheetState();
}

class _KulliyatManagementAndSettingsSheetState
    extends ConsumerState<KulliyatManagementAndSettingsSheet> {
  late int _activeSection;
  String? _selectedBookIdForCover;

  @override
  void initState() {
    super.initState();
    _activeSection = widget.initialSection.clamp(0, 2);
    _selectedBookIdForCover = widget.initialCustomizeBookId;
  }

  @override
  Widget build(BuildContext context) {
    final books = ref.watch(islamicBookshelfProvider);
    final notifier = ref.read(islamicBookshelfProvider.notifier);
    final readerSettings = ref.watch(islamicBookReaderSettingsProvider);
    final readerNotifier =
        ref.read(islamicBookReaderSettingsProvider.notifier);

    final bgColor =
        widget.isDark ? const Color(0xFF141B18) : const Color(0xFFFDFBF7);
    final cardColor =
        widget.isDark ? const Color(0xFF1E2823) : const Color(0xFFF4EDE0);
    final textColor =
        widget.isDark ? const Color(0xFFF5F2EB) : const Color(0xFF1E2923);
    final subColor =
        widget.isDark ? const Color(0xFFA5B5AD) : const Color(0xFF5C6B62);
    const goldColor = Color(0xFFD4AF37);

    final selectedBook = books.firstWhere(
      (b) => b.id == (_selectedBookIdForCover ?? books.first.id),
      orElse: () => books.first,
    );

    return DraggableScrollableSheet(
      initialChildSize: 0.84,
      minChildSize: 0.55,
      maxChildSize: 0.94,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: goldColor.withValues(alpha: 0.35),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: subColor.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 16, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Külliyat & Okuma Düzeni',
                            style: GoogleFonts.merriweather(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Raf sıralaması, cilt renkleri ve kitap içi sayfa/font ayarları',
                            style: TextStyle(fontSize: 11.5, color: subColor),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        notifier.resetLayoutKeepProgress();
                      },
                      child: const Text(
                        'Sıfırla',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: goldColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Gruplandırılmış 3 Sekme Seçici (Raf Düzeni | Cilt Rengi | Sayfa & Font)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: goldColor.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Row(
                    children: [
                      _buildTabSegment(
                        index: 0,
                        label: 'Raf Düzeni',
                        textColor: textColor,
                        subColor: subColor,
                        goldColor: goldColor,
                      ),
                      _buildTabSegment(
                        index: 1,
                        label: 'Cilt & Kapak',
                        textColor: textColor,
                        subColor: subColor,
                        goldColor: goldColor,
                      ),
                      _buildTabSegment(
                        index: 2,
                        label: 'Sayfa & Font',
                        textColor: textColor,
                        subColor: subColor,
                        goldColor: goldColor,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Divider(height: 1, color: subColor.withValues(alpha: 0.16)),

              // İçerik Alanı
              Expanded(
                child: _activeSection == 0
                    ? _buildShelfOrderList(
                        books: books,
                        notifier: notifier,
                        scrollController: scrollController,
                        cardColor: cardColor,
                        textColor: textColor,
                        subColor: subColor,
                        goldColor: goldColor,
                      )
                    : _activeSection == 1
                        ? _buildBookCoverCustomizer(
                            books: books,
                            selectedBook: selectedBook,
                            notifier: notifier,
                            scrollController: scrollController,
                            cardColor: cardColor,
                            textColor: textColor,
                            subColor: subColor,
                            goldColor: goldColor,
                          )
                        : _buildReaderSettingsSection(
                            settings: readerSettings,
                            notifier: readerNotifier,
                            scrollController: scrollController,
                            cardColor: cardColor,
                            textColor: textColor,
                            subColor: subColor,
                            goldColor: goldColor,
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabSegment({
    required int index,
    required String label,
    required Color textColor,
    required Color subColor,
    required Color goldColor,
  }) {
    final selected = _activeSection == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _activeSection = index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? goldColor.withValues(alpha: 0.22)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: selected ? goldColor : Colors.transparent,
              width: 1,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: selected ? textColor : subColor,
            ),
          ),
        ),
      ),
    );
  }

  /// 1. Grup: Raf Sıralama, Görünürlük ve İlerleme Özeti
  Widget _buildShelfOrderList({
    required List<IslamicShelfBook> books,
    required IslamicBookshelfNotifier notifier,
    required ScrollController scrollController,
    required Color cardColor,
    required Color textColor,
    required Color subColor,
    required Color goldColor,
  }) {
    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      itemCount: books.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, idx) {
        final book = books[idx];
        final palette = book.palette;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: book.isVisible
                  ? goldColor.withValues(alpha: 0.25)
                  : subColor.withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            children: [
              // İkonsuz klasik cilt sırtı önizleme
              GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedBookIdForCover = book.id;
                    _activeSection = 1;
                  });
                },
                child: Container(
                  width: 16,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [palette.primaryLeather, palette.secondaryLeather],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: palette.goldAccent, width: 0.9),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.shortTitle,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: book.isVisible
                            ? textColor
                            : subColor.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${book.category.label} • ${book.totalPages} Sayfa • %${book.progressPercent} Okundu',
                      style: TextStyle(fontSize: 11, color: subColor),
                    ),
                  ],
                ),
              ),
              // Sıra değiştir (Yukarı / Aşağı)
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.keyboard_arrow_up_rounded,
                  color: subColor,
                  size: 20,
                ),
                onPressed: () => notifier.moveBookOrder(book.id, -1),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: subColor,
                  size: 20,
                ),
                onPressed: () => notifier.moveBookOrder(book.id, 1),
              ),
              // Cilt rengi düzenle
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Cilt Rengi',
                icon: Icon(
                  Icons.palette_outlined,
                  color: goldColor,
                  size: 18,
                ),
                onPressed: () {
                  setState(() {
                    _selectedBookIdForCover = book.id;
                    _activeSection = 1;
                  });
                },
              ),
              // Görünürlük
              Switch.adaptive(
                value: book.isVisible,
                activeThumbColor: goldColor,
                onChanged: (_) => notifier.toggleBookVisibility(book.id),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 2. Grup: Kitap Cilt ve Sırt Rengi Özelleştirme (İkonsuz)
  Widget _buildBookCoverCustomizer({
    required List<IslamicShelfBook> books,
    required IslamicShelfBook selectedBook,
    required IslamicBookshelfNotifier notifier,
    required ScrollController scrollController,
    required Color cardColor,
    required Color textColor,
    required Color subColor,
    required Color goldColor,
  }) {
    final palette = selectedBook.palette;
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        Text(
          'Özelleştirilecek Eseri Seçin',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: books.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, idx) {
              final b = books[idx];
              final isSelected = b.id == selectedBook.id;
              return ChoiceChip(
                label: Text(b.shortTitle),
                selected: isSelected,
                onSelected: (_) {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedBookIdForCover = b.id);
                },
                selectedColor: goldColor.withValues(alpha: 0.24),
                backgroundColor: cardColor,
                labelStyle: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? textColor : subColor,
                ),
                side: BorderSide(
                  color: isSelected
                      ? goldColor
                      : subColor.withValues(alpha: 0.22),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),

        // Canlı Cilt & Sırt Önizlemesi (İkonsuz)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: goldColor.withValues(alpha: 0.28)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 112,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      palette.secondaryLeather,
                      palette.primaryLeather,
                      palette.spineColor,
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: palette.goldAccent, width: 1.0),
                ),
                child: Center(
                  child: RotatedBox(
                    quarterTurns: 3,
                    child: Text(
                      selectedBook.shortTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.merriweather(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: palette.textColor,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selectedBook.title,
                      style: GoogleFonts.merriweather(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      selectedBook.author,
                      style: TextStyle(fontSize: 12, color: subColor),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Cilt Tonu: ${palette.name} • %${selectedBook.progressPercent} Okundu',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: goldColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Text(
          'Klasik Deri & Tezhip Renk Paleti',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: BookCoverPalette.palettes.map((p) {
            final isSelected = p.index == selectedBook.paletteIndex;
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                notifier.customizeBookCover(
                  bookId: selectedBook.id,
                  paletteIndex: p.index,
                  coverStyle: selectedBook.coverStyle,
                );
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: p.primaryLeather,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? p.goldAccent
                        : p.goldAccent.withValues(alpha: 0.3),
                    width: isSelected ? 2.0 : 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: p.goldAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      p.name,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight:
                            isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: p.textColor,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// 3. Grup: Kitap İçi Sayfa ve Font Düzeni Ayarları
  Widget _buildReaderSettingsSection({
    required IslamicBookReaderSettings settings,
    required IslamicBookReaderSettingsNotifier notifier,
    required ScrollController scrollController,
    required Color cardColor,
    required Color textColor,
    required Color subColor,
    required Color goldColor,
  }) {
    const themes = [
      (0, 'Tahrir Parşömeni', Color(0xFFFBF3E2), Color(0xFF2B1E16)),
      (1, 'Klasik Sahife', Color(0xFFF8F9FA), Color(0xFF1E242B)),
      (2, 'Safir Gece', Color(0xFF0D1B2A), Color(0xFFE5ECF4)),
      (3, 'Zümrüt Huzur', Color(0xFF0C201B), Color(0xFFE6F2EE)),
      (4, 'Tam Siyah', Color(0xFF000000), Color(0xFFE8E6E3)),
    ];

    const fonts = [
      'Merriweather',
      'Lora',
      'Crimson Pro',
      'Plus Jakarta Sans',
    ];

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        Text(
          'Sayfa Kağıt & Gece Teması',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 54,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: themes.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, idx) {
              final t = themes[idx];
              final isSelected = settings.themeIndex == t.$1;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  notifier.updateSettings(settings.copyWith(themeIndex: t.$1));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: t.$3,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? goldColor
                          : subColor.withValues(alpha: 0.3),
                      width: isSelected ? 2.2 : 1.0,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    t.$2,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: t.$4,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),

        Text(
          'Yazı Tipi (Tipografi)',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: fonts.map((f) {
            final selected = settings.fontFamily == f;
            return ChoiceChip(
              label: Text(f),
              selected: selected,
              onSelected: (_) {
                HapticFeedback.selectionClick();
                notifier.updateSettings(settings.copyWith(fontFamily: f));
              },
              selectedColor: goldColor.withValues(alpha: 0.22),
              backgroundColor: cardColor,
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? textColor : subColor,
              ),
              side: BorderSide(
                color: selected ? goldColor : subColor.withValues(alpha: 0.22),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        // Türkçe Metin Puntoları ve Satır Aralığı
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: goldColor.withValues(alpha: 0.22)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Metin Boyutu (${settings.turkishFontSize.toStringAsFixed(1)} pt)',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => notifier.updateSettings(
                          settings.copyWith(
                            turkishFontSize:
                                (settings.turkishFontSize - 1.0).clamp(13.0, 26.0),
                          ),
                        ),
                        icon: Icon(Icons.remove_circle_outline, color: textColor),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => notifier.updateSettings(
                          settings.copyWith(
                            turkishFontSize:
                                (settings.turkishFontSize + 1.0).clamp(13.0, 26.0),
                          ),
                        ),
                        icon: Icon(Icons.add_circle_outline, color: textColor),
                      ),
                    ],
                  ),
                ],
              ),
              Divider(height: 12, color: subColor.withValues(alpha: 0.15)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Arapça Hat Boyutu (${settings.arabicFontSize.toStringAsFixed(0)} pt)',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => notifier.updateSettings(
                          settings.copyWith(
                            arabicFontSize:
                                (settings.arabicFontSize - 1.5).clamp(18.0, 38.0),
                          ),
                        ),
                        icon: Icon(Icons.remove_circle_outline, color: textColor),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => notifier.updateSettings(
                          settings.copyWith(
                            arabicFontSize:
                                (settings.arabicFontSize + 1.5).clamp(18.0, 38.0),
                          ),
                        ),
                        icon: Icon(Icons.add_circle_outline, color: textColor),
                      ),
                    ],
                  ),
                ],
              ),
              Divider(height: 12, color: subColor.withValues(alpha: 0.15)),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Akıcı Kitap Sayfası Düzeni',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                subtitle: Text(
                  'Metinleri çerçevesiz klasik kitap sayfası olarak göster',
                  style: TextStyle(fontSize: 11, color: subColor),
                ),
                value: settings.isFlowingBookLayout,
                activeThumbColor: goldColor,
                onChanged: (v) => notifier.updateSettings(
                  settings.copyWith(isFlowingBookLayout: v),
                ),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Arapça Lafızları Göster',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                value: settings.showArabicText,
                activeThumbColor: goldColor,
                onChanged: (v) => notifier.updateSettings(
                  settings.copyWith(showArabicText: v),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
