import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../core/services/reading_notification_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../domain/entities/book_entity.dart';
import '../../../../domain/entities/highlight_entity.dart';
import '../../../marginalia/presentation/widgets/quote_studio_sheet.dart';

class HomeIncentiveWidgetsPanel extends ConsumerStatefulWidget {
  final BookEntity? activeBook;
  final int streakDays;
  final int todayMinutesRead;
  final int dailyGoalMinutes;
  final VoidCallback? onQuickFasilStart;

  const HomeIncentiveWidgetsPanel({
    super.key,
    required this.activeBook,
    required this.streakDays,
    required this.todayMinutesRead,
    required this.dailyGoalMinutes,
    this.onQuickFasilStart,
  });

  @override
  ConsumerState<HomeIncentiveWidgetsPanel> createState() =>
      _HomeIncentiveWidgetsPanelState();
}

class _HomeIncentiveWidgetsPanelState
    extends ConsumerState<HomeIncentiveWidgetsPanel> {
  List<HighlightEntity> _userHighlights = const [];
  int _quoteIndex = 0;

  static const List<(String, String, String)> _curatedWisdoms = [
    (
      'Kişi gönlünü akıl ile süsler, aklı ise bilgi ile aydınlatır. Dünya mülkü geçicidir; kalıcı olan adalet ve doğruluk üzerine kurulmuş nizâmdır.',
      'Kutadgu Bilig',
      'Yusuf Has Hacib',
    ),
    (
      'Tarih ilmi, zahirde geçmiş devirlerin haberlerinden ibaret görünse de hakikatte ince bir nazar, tahkik ve varlıkların sebeplerini araştırma ilmidir.',
      'Mukaddime',
      'İbn Haldun',
    ),
    (
      'Muhakkak ki yumuşaklık ve nezaket bulunduğu her şeyi güzelleştirir; çekip alındığı şeyi ise eksiltir.',
      'İslam Âdâb-ı Muaşereti',
      'Abdülfettah Ebû Gudde',
    ),
    (
      'Okumak, zihnin sonsuz vadilerinde yapılan en zarif seyahattir; gözlerin satırlar üzerinde zahmetsizce akması ruhani bir sığınaktır.',
      'Tahrir Risalesi',
      'Tahrir Külliyatı',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadHighlightsAndSyncOsWidget();
  }

  Future<void> _loadHighlightsAndSyncOsWidget() async {
    final repo = ref.read(highlightRepositoryProvider);
    final res = await repo.getAllHighlights();
    final items = res.dataOrNull ?? const [];
    if (mounted) {
      setState(() {
        _userHighlights = items;
      });
    }

    final (quote, sourceTitle, sourceAuthor) = _currentWisdom;
    final bookTitle = widget.activeBook?.title ?? sourceTitle;
    final bookAuthor = widget.activeBook?.author ?? sourceAuthor;
    final progressPct =
        ((widget.activeBook?.progressPercentage ?? 0.0) * 100).round();

    await ref.read(readingNotificationProvider.notifier).syncHomeScreenWidget(
          streakDays: widget.streakDays,
          todayMinutesRead: widget.todayMinutesRead,
          dailyGoalMinutes: widget.dailyGoalMinutes,
          currentBookTitle: bookTitle,
          currentBookAuthor: bookAuthor,
          progressPercent: progressPct,
          dailyQuote: quote,
        );
  }

  (String, String, String) get _currentWisdom {
    if (_userHighlights.isNotEmpty) {
      final h = _userHighlights[_quoteIndex % _userHighlights.length];
      final text = h.userNote != null && h.userNote!.trim().isNotEmpty
          ? '${h.selectedText}\n— Haşiye: ${h.userNote}'
          : h.selectedText;
      return (
        text,
        widget.activeBook?.title ?? 'Derkenar Şerhi (S. ${h.pageNumber})',
        widget.activeBook?.author ?? 'Şahsi Haşiye Defteri',
      );
    }
    return _curatedWisdoms[_quoteIndex % _curatedWisdoms.length];
  }

  void _nextWisdom() {
    setState(() {
      _quoteIndex++;
    });
  }

  void _showHomeWidgetPreviewModal(BuildContext context) {
    final theme = Theme.of(context);
    final (quote, title, author) = _currentWisdom;
    final bookTitle = widget.activeBook?.title ?? title;
    final progressPct =
        ((widget.activeBook?.progressPercentage ?? 0.12) * 100).round();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outline.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '📱 Tahrir Cihaz Ana Ekran Widget’ı',
                style: GoogleFonts.literata(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Telefonunuzun ana ekranına ekleyerek okuma serinizi, aktif kitabınızı ve günün hikmetini uygulamayı açmadan takip edin.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
                ),
              ),
              const SizedBox(height: 16),

              // Cihaz Ana Ekran Widget Canlı Önizlemesi (4x2 OS AppWidget Görünümü)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF161311),
                      Color(0xFF261F1A),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: AppColors.amberGold.withValues(alpha: 0.65),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.28),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Text('📜', style: TextStyle(fontSize: 15)),
                            const SizedBox(width: 6),
                            Text(
                              'TAHRİR MÜTALAA',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                                color: AppColors.amberGold,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.deepOrange.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '🔥 ${widget.streakDays} Gün Seri • ${widget.todayMinutesRead}/${widget.dailyGoalMinutes} dk',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.orangeAccent,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      bookTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.literata(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.warmBone,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '“$quote”',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.literata(
                        fontSize: 11.5,
                        fontStyle: FontStyle.italic,
                        color: AppColors.warmBone.withValues(alpha: 0.78),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (progressPct / 100.0).clamp(0.05, 1.0),
                              minHeight: 5,
                              backgroundColor: Colors.white12,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                AppColors.amberGold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '%$progressPct • Devam Et →',
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.amberGold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              FilledButton.icon(
                icon: const Icon(Icons.add_to_home_screen_rounded, size: 19),
                label: const Text('Telefon Ana Ekranına Şimdi Sabitle'),
                onPressed: () async {
                  final pinned = await ref
                      .read(readingNotificationProvider.notifier)
                      .requestPinHomeScreenWidget();
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          pinned
                              ? '✨ Tahrir Ana Ekran Widget’ı telefonunuza eklendi!'
                              : '📱 Ana ekrana basılı tutup "Widget’lar > Tahrir" seçerek de ekleyebilirsiniz.',
                        ),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (quote, sourceTitle, sourceAuthor) = _currentWisdom;
    final isUserHighlight = _userHighlights.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Günün Derkenar Hikmeti & Hafıza Kartı Widget'ı
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.primary.withValues(alpha: 0.11),
                AppColors.amberGold.withValues(alpha: 0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.32),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text('🖋️', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Text(
                        isUserHighlight
                            ? 'DERKENAR HAFIZA KARTI (ŞERHİNİZ)'
                            : 'GÜNÜN TEFEKKÜR & HİKMET SATIRI',
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: _nextWisdom,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          child: Icon(
                            Icons.refresh_rounded,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => QuoteStudioSheet.show(
                          context,
                          quoteText: quote,
                          bookTitle: sourceTitle,
                          author: sourceAuthor,
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '🎨 Paylaş',
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '“$quote”',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.literata(
                  fontSize: 13,
                  height: 1.45,
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '— $sourceAuthor • $sourceTitle',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // 2. Hızlı Teşvik Aksiyon Çubuğu: 3 Dk Mikro-Fasıl & Telefon Ana Ekran Widget'ı
        Row(
          children: [
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: widget.onQuickFasilStart,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Text('⚡', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '3 Dk Mikro-Fasıl',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              'Hızlı 1 sayfa oku, seriyi koru',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _showHomeWidgetPreviewModal(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.amberGold.withValues(alpha: 0.55),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Text('📱', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ana Ekran Widget’ı',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              'Telefona seri & söz sabitle',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
