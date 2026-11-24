import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../engine/ocr_proofreader_engine.dart';
import '../providers/reader_provider.dart';

/// Microsoft Word "Gözden Geçir (Yazım Denetimi, Değişiklikleri İzle ve Otomatik Düzelt)" Paneli
class OcrReviewSheet extends ConsumerStatefulWidget {
  const OcrReviewSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const FractionallySizedBox(
        heightFactor: 0.68,
        child: OcrReviewSheet(),
      ),
    );
  }

  /// Metin içinden seçilen herhangi bir kelime için hızlı Word tarzı Tashih & Otomatik Düzeltme penceresi
  static Future<void> showQuickWordCorrectionDialog(
    BuildContext context,
    WidgetRef ref,
    String selectedText,
  ) async {
    final cleanWord = selectedText.trim().split(RegExp(r'\s+')).first;
    if (cleanWord.isEmpty) return;

    await showDialog(
      context: context,
      builder: (_) => _QuickWordCorrectionDialog(
        initialWord: cleanWord,
        ref: ref,
      ),
    );
  }

  @override
  ConsumerState<OcrReviewSheet> createState() => _OcrReviewSheetState();
}

class _OcrReviewSheetState extends ConsumerState<OcrReviewSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentPage = ref.watch(readerProvider.select((s) => s.currentPage));
    final isHighlightEnabled = ref.watch(
      readerProvider.select((s) => s.isOcrReviewHighlightEnabled),
    );
    final report = ref.watch(
      readerProvider.select(
        (s) =>
            s.currentReflowData?.ocrReviewReport ??
            const OcrPageReviewReport.empty(),
      ),
    );

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outline.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 16, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.spellcheck_rounded,
                    color: theme.colorScheme.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gözden Geçir & Otomatik OCR Tashihi',
                        style: GoogleFonts.literata(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Sayfa $currentPage • Doğruluk %${report.pageAccuracyPercent.toStringAsFixed(1)} • ${report.autoCorrectedCount} Otomatik Düzeltme',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color:
                              theme.colorScheme.onSurface.withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  ),
                ),
                FilterChip(
                  selected: isHighlightEnabled,
                  label: Text(
                    'Alt Çizgi',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  avatar: const Icon(Icons.format_underlined_rounded, size: 15),
                  onSelected: (_) => ref
                      .read(readerProvider.notifier)
                      .toggleOcrReviewHighlight(),
                ),
              ],
            ),
          ),
          TabBar(
            controller: _tabController,
            labelStyle: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
            tabs: [
              Tab(text: 'Öneriler (${report.suggestionCount})'),
              Tab(text: 'Otomatik (${report.autoCorrectedCount})'),
              const Tab(text: 'Tashih Sözlüğü'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _SuggestionsTabView(
                  onOpenDictionaryTab: () => _tabController.animateTo(2),
                ),
                const _AutoCorrectionsTabView(),
                const _CustomDictionaryTabView(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OcrBookScanCard extends ConsumerWidget {
  const _OcrBookScanCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final hasBook = ref.watch(readerProvider.select((s) => s.currentBook != null));
    final scanState = ref.watch(readerProvider.select((s) => s.bookOcrScan));

    if (!hasBook) return const SizedBox.shrink();

    final progressValue = scanState.totalPages > 0
        ? (scanState.scannedPages / scanState.totalPages).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_fix_normal_rounded,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Kitap Geneli Kusursuz Okuma Taraması',
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (scanState.isScanning)
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: Colors.redAccent,
                  ),
                  icon: const Icon(Icons.stop_circle_outlined, size: 16),
                  label: const Text('İptal'),
                  onPressed: () =>
                      ref.read(readerProvider.notifier).cancelBookOcrScan(),
                )
              else
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                  icon: const Icon(Icons.manage_search_rounded, size: 16),
                  label: Text(
                    'Tüm Kitabı Tara',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: () =>
                      ref.read(readerProvider.notifier).scanEntireBookForOcr(),
                ),
            ],
          ),
          if (scanState.isScanning) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: progressValue),
            ),
            const SizedBox(height: 6),
            Text(
              'Taranıyor: ${scanState.scannedPages} / ${scanState.totalPages} · ${scanState.totalAutoCorrected} otomatik onarım · ${scanState.totalRemainingSuggestions} şüpheli',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ] else if (scanState.scannedPages > 0) ...[
            const SizedBox(height: 8),
            Text(
              '${scanState.scannedPages} sayfa/bölüm tarandı · ${scanState.totalAutoCorrected} otomatik onarım · ${scanState.totalRemainingSuggestions} şüpheli kelime',
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: scanState.totalRemainingSuggestions == 0
                    ? const Color(0xFF10B981)
                    : AppColors.amberGold,
              ),
            ),
            if (scanState.pagesWithIssues.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: scanState.pagesWithIssues.take(16).map((issue) {
                  return Tooltip(
                    message:
                        '${issue.title}: ${issue.previewWords.join(", ")}',
                    child: ActionChip(
                      visualDensity: VisualDensity.compact,
                      label: Text(
                        'S.${issue.pageNumber} (${issue.suggestionCount})',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      onPressed: () {
                        ref
                            .read(readerProvider.notifier)
                            .jumpToPage(issue.pageNumber);
                        Navigator.pop(context);
                      },
                    ),
                  );
                }).toList(),
              ),
            ],
          ] else ...[
            const SizedBox(height: 4),
            Text(
              'Tüm bölüm veya sayfaları önceden tarayıp OCR hatalarını otomatik onarın ve şüpheli sayfalara tek dokunuşla atlayın.',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HighlightedContextSnippet extends StatelessWidget {
  final String snippet;
  final String highlightWord;
  final Color highlightColor;
  final TextStyle baseStyle;

  const _HighlightedContextSnippet({
    required this.snippet,
    required this.highlightWord,
    required this.highlightColor,
    required this.baseStyle,
  });

  @override
  Widget build(BuildContext context) {
    final cleanTarget = highlightWord.trim();
    if (cleanTarget.isEmpty || snippet.isEmpty) {
      return Text(
        '“$snippet”',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: baseStyle,
      );
    }

    final snippetLower = OcrProofreaderEngine.toTurkishLower(snippet);
    final targetLower = OcrProofreaderEngine.toTurkishLower(cleanTarget);
    final idx = snippetLower.indexOf(targetLower);

    if (idx < 0 ||
        snippetLower.length != snippet.length ||
        idx + targetLower.length > snippet.length) {
      return Text(
        '“$snippet”',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: baseStyle,
      );
    }

    return Text.rich(
      TextSpan(
        style: baseStyle,
        children: [
          const TextSpan(text: '“'),
          TextSpan(text: snippet.substring(0, idx)),
          TextSpan(
            text: snippet.substring(idx, idx + targetLower.length),
            style: baseStyle.copyWith(
              fontWeight: FontWeight.w800,
              color: highlightColor,
              backgroundColor: highlightColor.withValues(alpha: 0.14),
            ),
          ),
          TextSpan(text: snippet.substring(idx + targetLower.length)),
          const TextSpan(text: '”'),
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _SuggestionsTabView extends ConsumerWidget {
  final VoidCallback onOpenDictionaryTab;

  const _SuggestionsTabView({required this.onOpenDictionaryTab});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final report = ref.watch(
      readerProvider.select(
        (s) =>
            s.currentReflowData?.ocrReviewReport ??
            const OcrPageReviewReport.empty(),
      ),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      children: [
        const _OcrBookScanCard(),
        const SizedBox(height: 12),
        if (report.suggestions.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.verified_rounded,
                    size: 30,
                    color: Color(0xFF10B981),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Bu Sayfada Şüpheli Kelime Kalmadı',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.literata(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  report.autoCorrectedCount > 0
                      ? 'OCR sonrası ${report.autoCorrectedCount} hatalı kelime ilgili sayfada otomatik olarak düzeltildi. Yapılan değişiklikleri "Otomatik" sekmesinden inceleyebilir veya geri alabilirsiniz.'
                      : 'Sayfadaki tüm kelimeler Türkçe morfoloji ve OCR doğruluk denetiminden başarıyla geçti.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    height: 1.45,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.refresh_rounded, size: 17),
                      label: const Text('Sayfayı Yeniden Tara'),
                      onPressed: () =>
                          ref.read(readerProvider.notifier).recheckCurrentPage(),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.add_task_rounded, size: 17),
                      label: const Text('Özel Kelime Düzeltmesi Ekle'),
                      onPressed: onOpenDictionaryTab,
                    ),
                  ],
                ),
              ],
            ),
          )
        else ...[
          FilledButton.icon(
            icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
            label: Text(
              'Tüm Şüpheli Kelimeleri Otomatik Düzelt (${report.suggestionCount})',
            ),
            onPressed: () async {
              final count = await ref
                  .read(readerProvider.notifier)
                  .applyAllPageOcrSuggestions();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '✨ $count kelime ilgili sayfada otomatik düzeltildi!',
                    ),
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 12),
          for (final item in report.suggestions)
            _SuggestionCard(item: item),
        ],
      ],
    );
  }
}

class _SuggestionCard extends ConsumerWidget {
  final OcrSuggestionItem item;

  const _SuggestionCard({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: AppColors.amberGold.withValues(alpha: 0.45),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    item.suspiciousWord,
                    style: GoogleFonts.literata(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.redAccent,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.issueDescription,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                    ),
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => ref
                      .read(readerProvider.notifier)
                      .ignoreOcrSuggestion(item.suspiciousWord),
                  child: const Text(
                    'Yoksay',
                    style: TextStyle(fontSize: 11.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _HighlightedContextSnippet(
              snippet: item.contextSnippet,
              highlightWord: item.suspiciousWord,
              highlightColor: Colors.redAccent,
              baseStyle: GoogleFonts.literata(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.78),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Önerilen Düzeltmeler (Uygulamak için dokunun):',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...item.suggestions.map(
                  (cand) => ActionChip(
                    avatar: const Icon(
                      Icons.check_circle_outline_rounded,
                      size: 15,
                      color: Color(0xFF10B981),
                    ),
                    label: Text(
                      cand,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onPressed: () => ref
                        .read(readerProvider.notifier)
                        .applyOcrWordCorrection(
                          originalWord: item.suspiciousWord,
                          correctedWord: cand,
                          blockIndex: item.blockIndex,
                          addToAutoCorrectRules: true,
                        ),
                  ),
                ),
                ActionChip(
                  avatar: const Icon(Icons.edit_outlined, size: 15),
                  label: Text(
                    'Elle Yaz...',
                    style: GoogleFonts.inter(fontSize: 11.5),
                  ),
                  onPressed: () =>
                      OcrReviewSheet.showQuickWordCorrectionDialog(
                    context,
                    ref,
                    item.suspiciousWord,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AutoCorrectionsTabView extends ConsumerWidget {
  const _AutoCorrectionsTabView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final report = ref.watch(
      readerProvider.select(
        (s) =>
            s.currentReflowData?.ocrReviewReport ??
            const OcrPageReviewReport.empty(),
      ),
    );

    if (report.autoCorrections.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Bu sayfada henüz otomatik düzeltilen bir OCR kelimesi kaydı bulunmuyor.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      itemCount: report.autoCorrections.length,
      itemBuilder: (ctx, idx) {
        final corr = report.autoCorrections[idx];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: theme.colorScheme.outline.withValues(alpha: 0.4),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      corr.originalWord,
                      style: GoogleFonts.literata(
                        fontSize: 13,
                        color: Colors.redAccent,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(Icons.arrow_forward_rounded, size: 14),
                    ),
                    Expanded(
                      child: Text(
                        corr.correctedWord,
                        style: GoogleFonts.literata(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        corr.ruleCategory,
                        style: GoogleFonts.inter(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                      ),
                      icon: const Icon(Icons.undo_rounded, size: 14),
                      label: const Text(
                        'Geri Al',
                        style: TextStyle(fontSize: 11),
                      ),
                      onPressed: () async {
                        await ref
                            .read(readerProvider.notifier)
                            .revertOcrAutoCorrection(corr);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '↩️ "${corr.correctedWord}" kelimesi "${corr.originalWord}" hâline geri alındı.',
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
                if (corr.contextSnippet.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  _HighlightedContextSnippet(
                    snippet: corr.contextSnippet,
                    highlightWord: corr.correctedWord,
                    highlightColor: const Color(0xFF10B981),
                    baseStyle: GoogleFonts.literata(
                      fontSize: 11.5,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CustomDictionaryTabView extends ConsumerStatefulWidget {
  const _CustomDictionaryTabView();

  @override
  ConsumerState<_CustomDictionaryTabView> createState() =>
      _CustomDictionaryTabViewState();
}

class _CustomDictionaryTabViewState
    extends ConsumerState<_CustomDictionaryTabView> {
  late final TextEditingController _wrongWordController;
  late final TextEditingController _correctWordController;

  @override
  void initState() {
    super.initState();
    _wrongWordController = TextEditingController();
    _correctWordController = TextEditingController();
  }

  @override
  void dispose() {
    _wrongWordController.dispose();
    _correctWordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Sayfa raporu veya kurallar güncellendiğinde listeyi otomatik yenile
    ref.watch(readerProvider.select((s) => s.currentReflowData));
    final entries = OcrProofreaderEngine.userAutoCorrectRules.entries.toList();
    final ignoredList = OcrProofreaderEngine.ignoredWords.toList()..sort();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      children: [
        Text(
          'Word "Otomatik Düzeltme" Kuralı Ekle',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Eklediğiniz kelimeler hem bu sayfada hem de bundan sonra taranacak tüm OCR sayfalarında otomatik olarak düzeltilir.',
          style: GoogleFonts.inter(
            fontSize: 11.5,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _wrongWordController,
                decoration: InputDecoration(
                  labelText: 'Hatalı Kelime',
                  hintText: 'Örn: deviet',
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.arrow_forward_rounded, size: 18),
            ),
            Expanded(
              child: TextField(
                controller: _correctWordController,
                decoration: InputDecoration(
                  labelText: 'Doğru Kelime',
                  hintText: 'Örn: devlet',
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        FilledButton.tonalIcon(
          icon: const Icon(Icons.save_outlined, size: 17),
          label: const Text('Kuralı Kaydet ve Sayfaya Uygula'),
          onPressed: () async {
            final wrong = _wrongWordController.text.trim();
            final right = _correctWordController.text.trim();
            if (wrong.isEmpty || right.isEmpty) return;

            await ref
                .read(readerProvider.notifier)
                .addCustomAutoCorrectRule(wrong, right);
            _wrongWordController.clear();
            _correctWordController.clear();
            if (mounted) setState(() {});
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '✨ "$wrong ➔ $right" otomatik düzeltme kuralı kaydedildi ve sayfaya uygulandı.',
                  ),
                ),
              );
            }
          },
        ),
        const Divider(height: 24),
        Text(
          'Kayıtlı Otomatik Düzeltme Kuralları (${entries.length})',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        if (entries.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Henüz özel bir otomatik düzeltme kuralı eklenmedi.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
          )
        else
          for (int idx = 0; idx < entries.length; idx++) ...[
            if (idx > 0) const Divider(height: 1),
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Row(
                children: [
                  Text(
                    entries[idx].key,
                    style: GoogleFonts.literata(
                      color: Colors.redAccent,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.arrow_forward_rounded, size: 14),
                  ),
                  Text(
                    entries[idx].value,
                    style: GoogleFonts.literata(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, size: 18),
                onPressed: () async {
                  await ref
                      .read(readerProvider.notifier)
                      .removeCustomAutoCorrectRule(entries[idx].key);
                  if (mounted) setState(() {});
                },
              ),
            ),
          ],
        const Divider(height: 24),
        Text(
          'Yoksayılan / Özel Sözlük Kelimeleri (${ignoredList.length})',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        if (ignoredList.isEmpty)
          Text(
            'Öneriler sekmesinden yoksayılan veya özel sözlüğe eklenen kelime bulunmuyor.',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ignoredList.map((word) {
              return InputChip(
                label: Text(
                  word,
                  style: GoogleFonts.literata(fontSize: 12.5),
                ),
                deleteIcon: const Icon(Icons.close_rounded, size: 16),
                onDeleted: () async {
                  await ref.read(readerProvider.notifier).unignoreOcrWord(word);
                  if (mounted) setState(() {});
                },
              );
            }).toList(),
          ),
      ],
    );
  }
}

class _QuickWordCorrectionDialog extends StatefulWidget {
  final String initialWord;
  final WidgetRef ref;

  const _QuickWordCorrectionDialog({
    required this.initialWord,
    required this.ref,
  });

  @override
  State<_QuickWordCorrectionDialog> createState() =>
      _QuickWordCorrectionDialogState();
}

class _QuickWordCorrectionDialogState
    extends State<_QuickWordCorrectionDialog> {
  late final TextEditingController _controller;
  late final List<String> _suggestions;
  bool _alwaysAutoCorrect = true;

  @override
  void initState() {
    super.initState();
    _suggestions = OcrProofreaderEngine.suggestForWord(widget.initialWord);
    _controller = TextEditingController(
      text: _suggestions.isNotEmpty ? _suggestions.first : widget.initialWord,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      backgroundColor: theme.colorScheme.surface,
      title: Row(
        children: [
          Icon(Icons.spellcheck_rounded, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Kelime Tashihi: “${widget.initialWord}”',
              style: GoogleFonts.literata(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_suggestions.isNotEmpty) ...[
              Text(
                'Önerilen Düzeltmeler:',
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _suggestions
                    .map(
                      (s) => ActionChip(
                        label: Text(
                          s,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onPressed: () {
                          setState(() => _controller.text = s);
                        },
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Düzeltilmiş Kelime',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: _alwaysAutoCorrect,
              onChanged: (v) => setState(() => _alwaysAutoCorrect = v ?? true),
              title: Text(
                'Otomatik Düzeltme sözlüğüne ekle (sonraki OCR sayfalarında otomatik düzelt)',
                style: GoogleFonts.inter(fontSize: 11.5),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('İptal'),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.check_rounded, size: 17),
          label: const Text('Sayfada Düzelt'),
          onPressed: () async {
            final target = _controller.text.trim();
            if (target.isNotEmpty && target != widget.initialWord) {
              await widget.ref
                  .read(readerProvider.notifier)
                  .applyOcrWordCorrection(
                    originalWord: widget.initialWord,
                    correctedWord: target,
                    addToAutoCorrectRules: _alwaysAutoCorrect,
                  );
            }
            if (context.mounted) {
              Navigator.pop(context);
            }
          },
        ),
      ],
    );
  }
}
