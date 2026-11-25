import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../domain/entities/book_entity.dart';
import '../../../../domain/entities/highlight_entity.dart';
import '../../../analytics_and_habits/presentation/widgets/completion_seal_dialog.dart';
import '../../../marginalia/presentation/widgets/dictionary_sheet.dart';
import '../../../marginalia/presentation/widgets/quote_studio_sheet.dart';
import '../../../speed_reading/domain/guided_flow_models.dart';
import '../../../speed_reading/presentation/providers/speed_reading_provider.dart';
import '../../../speed_reading/presentation/widgets/eye_workshop_sheet.dart';
import '../../../speed_reading/presentation/widgets/lexical_warmup_sheet.dart';
import '../../../subscription/presentation/providers/subscription_provider.dart';
import '../../../subscription/presentation/widgets/tahrir_pro_sheet.dart';
import '../../domain/content_block.dart';
import '../../domain/reading_mode_hysteresis.dart';
import '../../engine/ocr_proofreader_engine.dart';
import '../../engine/text_segmenter.dart';
import '../../services/offline_ai_service.dart';
import '../providers/guided_flow_provider.dart';
import '../providers/reader_provider.dart';
import '../widgets/ambient_sound_sheet.dart';
import '../widgets/arabic_text_card.dart';
import '../widgets/calligraphy_header_widget.dart';
import '../widgets/concept_radar_sheet.dart';
import '../widgets/fasil_reflection_sheet.dart';
import '../widgets/guided_flow_capsule_hud.dart';
import '../widgets/inline_crop_card.dart';
import '../widgets/interactive_snippet_badge_widget.dart';
import '../widgets/line_focus_overlay.dart';
import '../widgets/non_latin_warning_banner.dart';
import '../widgets/ocr_review_sheet.dart';
import '../widgets/optical_reflow_view.dart';
import '../widgets/popup_lugat_card.dart';
import '../widgets/reading_settings_sheet.dart';
import '../widgets/text_block_widget.dart';
import '../widgets/word_peek_sheet.dart';
import '../widgets/xray_split_view_widget.dart';

class ReaderScreen extends ConsumerStatefulWidget {
  final BookEntity book;
  final bool autoStartRitual;
  final int? initialGuidedFasilMinutes;

  const ReaderScreen({
    super.key,
    required this.book,
    this.autoStartRitual = false,
    this.initialGuidedFasilMinutes,
  });

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  bool _showControls = true;
  Object? _lastGuidedSyncSignature;
  late PdfViewerController _pdfViewerController;
  late final ScrollController _reflowScrollController;

  @override
  void initState() {
    super.initState();
    _pdfViewerController = PdfViewerController();
    _reflowScrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final isPro = ref.read(subscriptionProvider).isPro;
      await ref.read(readerProvider.notifier).openBook(
            widget.book,
            forceOriginalPdfView:
                !isPro && widget.book.format == BookFormat.pdf,
          );
      if (widget.autoStartRitual && isPro && mounted) {
        await ref.read(readerProvider.notifier).startMutalaaRitual();
      }
      if (widget.initialGuidedFasilMinutes != null && isPro && mounted) {
        _startGuidedFasil(durationMinutes: widget.initialGuidedFasilMinutes!);
      }
    });
  }

  @override
  void dispose() {
    _reflowScrollController.dispose();
    _pdfViewerController.dispose();
    super.dispose();
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
  }

  void _scrollToPageEdge({required bool toBottom}) {
    if (!mounted) return;
    if (!toBottom && _reflowScrollController.hasClients) {
      _reflowScrollController.jumpTo(0.0);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_reflowScrollController.hasClients) return;
      if (!toBottom) {
        _reflowScrollController.jumpTo(0.0);
        return;
      }
      _reflowScrollController.jumpTo(
        _reflowScrollController.position.maxScrollExtent,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_reflowScrollController.hasClients) return;
        final maxExtent = _reflowScrollController.position.maxScrollExtent;
        if ((_reflowScrollController.offset - maxExtent).abs() > 1.0) {
          _reflowScrollController.jumpTo(maxExtent);
        }
      });
    });
  }

  Future<void> _goToNextPage() async {
    await ref.read(readerProvider.notifier).nextPage();
    if (widget.book.format == BookFormat.pdf) {
      _pdfViewerController.nextPage();
    }
    _scrollToPageEdge(toBottom: false);
  }

  Future<void> _goToPreviousPage() async {
    await ref.read(readerProvider.notifier).previousPage();
    if (widget.book.format == BookFormat.pdf) {
      _pdfViewerController.previousPage();
    }
    _scrollToPageEdge(toBottom: true);
  }

  Future<void> _jumpToPage(int page) async {
    final prevPage = ref.read(readerProvider).currentPage;
    if (page == prevPage) return;
    final isGoingBackOnePage = page == prevPage - 1;
    await ref.read(readerProvider.notifier).jumpToPage(page);
    if (widget.book.format == BookFormat.pdf) {
      _pdfViewerController.jumpToPage(page);
    }
    _scrollToPageEdge(toBottom: isGoingBackOnePage);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(
      guidedFlowProvider.select((s) => s.justCompletedFasil),
      (prev, next) {
        if (next != true || prev == true) return;
        final flowSnapshot = ref.read(guidedFlowProvider);
        ref.read(guidedFlowProvider.notifier).clearCompletionFlag();

        final activeReader = ref.read(readerProvider);
        final activeBook = activeReader.currentBook ?? widget.book;
        final readerNotifier = ref.read(readerProvider.notifier);
        final speedNotifier = ref.read(speedReadingProvider.notifier);
        final visitedPages = flowSnapshot.visitedPages.isNotEmpty
            ? flowSnapshot.visitedPages
            : <int>{activeReader.currentPage};
        final insights = readerNotifier.collectInsightsForPages(visitedPages);
        final elapsedSeconds = (flowSnapshot.totalDurationSeconds -
                flowSnapshot.remainingSeconds)
            .clamp(1, flowSnapshot.totalDurationSeconds);
        final averageWpm = (elapsedSeconds >= 8 && flowSnapshot.wordsRead >= 10)
            ? ((flowSnapshot.wordsRead * 60) / elapsedSeconds)
                .round()
                .clamp(100, 900)
            : flowSnapshot.currentEffectiveWpm;
        final centralRecall = insights.summaryBulletPoints.isNotEmpty
            ? insights.summaryBulletPoints.first
            : '${activeBook.title} eserinde ${flowSnapshot.pagesRead} sayfa kesintisiz odaklanarak okudun.';

        final summary = FasilReflectionSummary(
          bookTitle: activeBook.title,
          bookId: activeBook.id,
          startPage: flowSnapshot.startPage,
          endPage: flowSnapshot.currentPage,
          pagesRead: flowSnapshot.pagesRead,
          wordsRead: flowSnapshot.wordsRead,
          durationSeconds: elapsedSeconds,
          averageWpm: averageWpm,
          keyConcepts: insights.keyConcepts,
          centralRecallSentence: centralRecall,
          densityTier: flowSnapshot.densityTier,
          insightSnippets: insights.summaryBulletPoints,
        );

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          FasilReflectionSheet.show(
            context,
            summary: summary,
            onSeal: ({required tempoFeedback, hasiyeNoteText}) async {
              await speedNotifier.recordGuidedFasilCompleted(
                bookId: activeBook.id,
                bookTitle: activeBook.title,
                startPage: summary.startPage,
                endPage: summary.endPage,
                pagesRead: summary.pagesRead,
                wordsRead: summary.wordsRead,
                durationSeconds: summary.durationSeconds,
                averageWpm: summary.averageWpm,
                tempoFeedback: tempoFeedback,
                densityTier: summary.densityTier,
                keyConcepts: summary.keyConcepts,
                centralRecallSentence: summary.centralRecallSentence,
                hasiyeNoteText: hasiyeNoteText,
                insightSnippets: summary.insightSnippets,
              );
              if (hasiyeNoteText != null &&
                  hasiyeNoteText.trim().isNotEmpty &&
                  mounted) {
                await readerNotifier.loadCurrentPageHighlights();
              }
            },
          );
        });
      },
    );

    ref.listen<int?>(
      guidedFlowProvider.select((s) => s.activeChunk?.paragraphIndex),
      (prev, next) {
        if (next == null || next == prev) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_reflowScrollController.hasClients) return;
          final currentReader = ref.read(readerProvider);
          final reflow = currentReader.currentReflowData;
          final contentLen = reflow?.contentBlocks.length ?? 0;
          final legacyLen = reflow?.paragraphs.length ??
              (currentReader.epubChapters.isNotEmpty &&
                      currentReader.currentEpubChapterIndex >= 0 &&
                      currentReader.currentEpubChapterIndex <
                          currentReader.epubChapters.length
                  ? currentReader
                      .epubChapters[currentReader.currentEpubChapterIndex]
                      .paragraphs
                      .length
                  : 0);
          final totalBlocks = contentLen > 0 ? contentLen : legacyLen;
          if (totalBlocks <= 1) return;
          final ratio = (next / (totalBlocks - 1)).clamp(0.0, 1.0);
          final maxExtent = _reflowScrollController.position.maxScrollExtent;
          if (maxExtent <= 0) return;
          final targetOffset = (maxExtent * ratio).clamp(0.0, maxExtent);
          if ((_reflowScrollController.offset - targetOffset).abs() < 48) {
            return;
          }
          _reflowScrollController.animateTo(
            targetOffset,
            duration: const Duration(milliseconds: 360),
            curve: Curves.easeOutCubic,
          );
        });
      },
    );

    final readerState = ref.watch(readerProvider.select((s) => s));
    final themeState = ref.watch(readerThemeProvider.select((s) => s));
    final guidedFlow = ref.watch(guidedFlowProvider.select((s) => s));
    final showCelebration = ref.watch(
      readerProvider.select((s) => s.showCompletionCelebration),
    );
    final theme = Theme.of(context);

    final isOriginalPdfMode = widget.book.format == BookFormat.pdf &&
        (readerState.isOriginalPdfView || readerState.isXRaySplitMode);
    if (guidedFlow.isActive && !readerState.isLoading) {
      final syncSig = Object.hash(
        readerState.currentPage,
        isOriginalPdfMode,
        readerState.currentEpubChapterIndex,
        readerState.currentReflowData?.rawText.hashCode,
      );
      if (_lastGuidedSyncSignature != syncSig) {
        _lastGuidedSyncSignature = syncSig;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !ref.read(guidedFlowProvider).isActive) return;
          final latestState = ref.read(readerProvider);
          final latestPdfMode = widget.book.format == BookFormat.pdf &&
              (latestState.isOriginalPdfView || latestState.isXRaySplitMode);
          ref.read(guidedFlowProvider.notifier).syncPageContent(
                currentPage: latestState.currentPage,
                paragraphs: ref
                    .read(readerProvider.notifier)
                    .getCurrentPageIndexableBlocks(),
                isOriginalPdfMode: latestPdfMode,
              );
        });
      }
    } else if (!guidedFlow.isActive) {
      _lastGuidedSyncSignature = null;
    }

    if (showCelebration) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final activeBook = readerState.currentBook ?? widget.book;
        ref.read(readerProvider.notifier).clearCompletionCelebration();
        if (ref.read(subscriptionProvider).isPro) {
          CompletionSealDialog.show(
            context,
            bookTitle: activeBook.title,
            author: activeBook.author,
            totalPages: activeBook.totalPages > 0 ? activeBook.totalPages : 1,
            readingMinutes:
                (activeBook.totalReadingTimeSeconds / 60).round().clamp(1, 99999),
          );
        }
      });
    }

    if (readerState.isLoading &&
        readerState.currentReflowData == null &&
        readerState.epubChapters.isEmpty) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Tahrir metin akışı tanzim ediliyor...',
                style: GoogleFonts.literata(fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    final totalPages = (readerState.currentBook?.totalPages ?? widget.book.totalPages) > 0
        ? (readerState.currentBook?.totalPages ?? widget.book.totalPages)
        : 1;

    return Scaffold(
      body: LineFocusOverlay(
        isEnabled: readerState.isLineFocusEnabled ||
            (guidedFlow.isActive && guidedFlow.isOriginalPdfMode),
        autoPaceProgress: (guidedFlow.isActive && guidedFlow.isOriginalPdfMode)
            ? guidedFlow.pdfLineProgress
            : null,
        child: SafeArea(
          child: Stack(
            children: [
              // Main Reading Content with Touch & Gesture Navigation
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) {
                  final screenWidth = MediaQuery.of(context).size.width;
                  final dx = details.localPosition.dx;
                  if (dx < screenWidth * 0.20) {
                    _goToPreviousPage();
                  } else if (dx > screenWidth * 0.80) {
                    _goToNextPage();
                  } else {
                    _toggleControls();
                  }
                },
                onHorizontalDragEnd: (details) {
                  final velocity = details.primaryVelocity;
                  if (velocity != null) {
                    if (velocity < -200) {
                      _goToNextPage();
                    } else if (velocity > 200) {
                      _goToPreviousPage();
                    }
                  }
                },
                child: SizedBox.expand(
                  child: readerState.isXRaySplitMode
                      ? XRaySplitViewWidget(
                          originalPdfView: _buildOriginalPdfView(
                            readerState,
                            themeState,
                            theme,
                            forXRayComparison: true,
                          ),
                          smartReflowView: _buildSmartReflowContent(
                            readerState,
                            themeState,
                            theme,
                            guidedFlow,
                          ),
                          onExitXRay: () =>
                              ref.read(readerProvider.notifier).toggleXRaySplitMode(),
                        )
                      : (readerState.displayMode == ReaderDisplayMode.originalPdf
                          ? _buildOriginalPdfView(readerState, themeState, theme)
                          : (readerState.displayMode ==
                                  ReaderDisplayMode.opticalReflow
                              ? _buildOpticalReflowContent(
                                  readerState,
                                  themeState,
                                  theme,
                                )
                              : _buildSmartReflowContent(
                                  readerState,
                                  themeState,
                                  theme,
                                  guidedFlow,
                                ))),
                ),
              ),

              // Sayfa yüklenirken / OCR taranırken üstte ince akıcı ilerleme çubuğu
              if (readerState.isLoading)
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                    minHeight: 2.5,
                    backgroundColor: Colors.transparent,
                  ),
                ),

              // Top Minimal App Bar (Auto-hiding, max 4 items)
              if (_showControls && !readerState.isZenMode)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.scaffoldBackgroundColor.withOpacity(0.96),
                      border: Border(bottom: BorderSide(color: theme.colorScheme.outline)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.book.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.literata(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                ),
                              ),
                              Text(
                                'Sayfa ${readerState.currentPage} / $totalPages',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 10.5,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (widget.book.format == BookFormat.pdf) ...[
                          const SizedBox(width: 4),
                          _buildCompactViewSelector(readerState, theme),
                        ],
                        if (!readerState.isOriginalPdfView)
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Gözden Geçir (Tashih)',
                            icon: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Icon(
                                  Icons.spellcheck_rounded,
                                  size: 20,
                                  color: readerState.isOcrReviewHighlightEnabled
                                      ? AppColors.amberGold
                                      : null,
                                ),
                                if (readerState.currentReflowData
                                        ?.ocrReviewReport.hasAnyActivity ??
                                    false)
                                  Positioned(
                                    right: -1,
                                    top: -1,
                                    child: Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: (readerState
                                                        .currentReflowData
                                                        ?.ocrReviewReport
                                                        .suggestionCount ??
                                                    0) >
                                                0
                                            ? AppColors.amberGold
                                            : const Color(0xFF10B981),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            onPressed: () {
                              if (!ref.read(subscriptionProvider).isPro) {
                                TahrirProSheet.show(context);
                                return;
                              }
                              OcrReviewSheet.show(context);
                            },
                          ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Araçlar',
                          icon: const Icon(Icons.more_horiz_rounded, size: 22),
                          onPressed: () =>
                              _showReaderToolsSheet(context, readerState, themeState),
                        ),
                      ],
                    ),
                  ),
                ),

              // Odak Seansı Aktif Sayaç Kapsülü
              if (readerState.isRitualActive)
                Positioned(
                  top: (_showControls && !readerState.isZenMode) ? 68 : 12,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: () {
                        final notifier = ref.read(readerProvider.notifier);
                        AmbientSoundSheet.show(context, notifier.ambientService);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF1E1B18),
                              Color(0xFF2D241E),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: AppColors.amberGold.withValues(alpha: 0.75),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.amberGold.withValues(alpha: 0.22),
                              blurRadius: 12,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🕯️', style: TextStyle(fontSize: 13)),
                            const SizedBox(width: 6),
                            Text(
                              'Odak Seansı • ${_formatRitualTimer(readerState.ritualRemainingSeconds)}',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.warmBone,
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => ref
                                  .read(readerProvider.notifier)
                                  .stopMutalaaRitual(),
                              child: const Icon(
                                Icons.close_rounded,
                                size: 15,
                                color: AppColors.amberGold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // Bottom Guided Flow Capsule HUD or Auto-hiding Reading Toolbar
              if (guidedFlow.isActive)
                Positioned(
                  bottom: 12,
                  left: 12,
                  right: 12,
                  child: Center(
                    child: GuidedFlowCapsuleHud(
                      phase: guidedFlow.phase,
                      currentWpm: guidedFlow.currentEffectiveWpm,
                      remainingSeconds: guidedFlow.remainingSeconds,
                      isPaused: guidedFlow.isPaused,
                      pausedByInteraction: guidedFlow.pausedByInteraction,
                      isOriginalPdfMode: guidedFlow.isOriginalPdfMode,
                      onTogglePause: () =>
                          ref.read(guidedFlowProvider.notifier).togglePause(),
                      onAdjustWpm: (delta) =>
                          ref.read(guidedFlowProvider.notifier).adjustWpm(delta),
                      onFinishEarly: () => ref
                          .read(guidedFlowProvider.notifier)
                          .finishEarlyAndReflect(),
                      onStop: () => ref
                          .read(guidedFlowProvider.notifier)
                          .stopWithoutReflection(),
                    ),
                  ),
                )
              else if (_showControls && !readerState.isZenMode)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                    decoration: BoxDecoration(
                      color: theme.scaffoldBackgroundColor.withOpacity(0.96),
                      border: Border(top: BorderSide(color: theme.colorScheme.outline)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Üst Satır: ‹ + Slider + Sayfa X/Y + ›
                        _buildPageSlider(readerState, theme),
                        const SizedBox(height: 2),
                        // Alt Satır: 4 Temiz Hızlı Aksiyon
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildBottomQuickAction(
                              theme: theme,
                              icon: Icons.text_fields_rounded,
                              label: 'Görünüm',
                              isActive: false,
                              onTap: () {
                                if (!ref.read(subscriptionProvider).isPro) {
                                  TahrirProSheet.show(context);
                                  return;
                                }
                                ReadingSettingsSheet.show(context);
                              },
                            ),
                            _buildBottomQuickAction(
                              theme: theme,
                              icon: readerState.isTtsPlaying
                                  ? Icons.volume_up_rounded
                                  : Icons.headphones_rounded,
                              label: 'Ses & Ambiyans',
                              isActive:
                                  readerState.isTtsPlaying || readerState.isRitualActive,
                              onTap: () {
                                if (!ref.read(subscriptionProvider).isPro) {
                                  TahrirProSheet.show(context);
                                  return;
                                }
                                _showAudioAndAmbientSheet(
                                  context,
                                  readerState,
                                  theme,
                                );
                              },
                            ),
                            _buildBottomQuickAction(
                              theme: theme,
                              icon: Icons.bolt_rounded,
                              label: 'Hızlı Oku',
                              isActive: false,
                              accentColor: AppColors.amberGold,
                              onTap: () {
                                if (!ref.read(subscriptionProvider).isPro) {
                                  TahrirProSheet.show(context);
                                  return;
                                }
                                _openLiveSpeedReadingCoach(readerState);
                              },
                            ),
                            _buildBottomQuickAction(
                              theme: theme,
                              icon: Icons.menu_book_rounded,
                              label: 'Araçlar',
                              isActive: false,
                              onTap: () => _showReaderToolsSheet(
                                context,
                                readerState,
                                themeState,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatRitualTimer(int totalSeconds) {
    final mins = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final secs = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  bool _isPageGatedBySmartReflowPro(ReaderState readerState) {
    final isPro = ref.read(subscriptionProvider).isPro;
    return !isPro && !readerState.isOriginalPdfView;
  }

  void _startGuidedFasil({required int durationMinutes}) {
    final isPro = ref.read(subscriptionProvider).isPro;
    if (!isPro) {
      TahrirProSheet.show(context);
      return;
    }

    final readerState = ref.read(readerProvider);
    final speedState = ref.read(speedReadingProvider);

    final readerNotifier = ref.read(readerProvider.notifier);
    final plainText = readerNotifier.getCurrentPagePlainText();
    final insights = const OfflineAiService().analyzeText(plainText);
    final densityTier =
        TextDensityTier.fromComplexityLabel(insights.complexityLevel);
    final targetWpm = speedState.targetWpmForDensity(densityTier);
    final paragraphs = readerNotifier.getCurrentPageIndexableBlocks();
    final isOriginalPdfMode = widget.book.format == BookFormat.pdf &&
        (readerState.isOriginalPdfView || readerState.isXRaySplitMode);

    ref.read(guidedFlowProvider.notifier).startFasil(
      durationMinutes: durationMinutes,
      targetWpm: targetWpm,
      densityTier: densityTier,
      scaffoldingEnabled: isPro,
      currentPage: readerState.currentPage,
      paragraphs: paragraphs,
      isOriginalPdfMode: isOriginalPdfMode,
      onRequestNextPage: () async {
        if (!mounted) return false;
        final current = ref.read(readerProvider);
        final activeBook = current.currentBook ?? widget.book;
        final isChapterBased = activeBook.format == BookFormat.epub ||
            activeBook.format == BookFormat.markdown ||
            activeBook.format == BookFormat.txt;
        final maxPage = isChapterBased && current.epubChapters.isNotEmpty
            ? current.epubChapters.length
            : (activeBook.totalPages > 0 ? activeBook.totalPages : 1);
        if (current.currentPage >= maxPage) {
          return false;
        }
        await _goToNextPage();
        if (!mounted) return false;
        final updated = ref.read(readerProvider);
        final updatedPdfMode = widget.book.format == BookFormat.pdf &&
            (updated.isOriginalPdfView || updated.isXRaySplitMode);
        ref.read(guidedFlowProvider.notifier).syncPageContent(
              currentPage: updated.currentPage,
              paragraphs: ref
                  .read(readerProvider.notifier)
                  .getCurrentPageIndexableBlocks(),
              isOriginalPdfMode: updatedPdfMode,
            );
        return true;
      },
    );

    setState(() => _showControls = false);
  }

  void _openLiveSpeedReadingCoach(ReaderState readerState) {
    ref.read(guidedFlowProvider.notifier).pauseForInteraction();
    if (!ref.read(subscriptionProvider).isPro) {
      TahrirProSheet.show(context);
      return;
    }

    final readerNotifier = ref.read(readerProvider.notifier);
    final plainText = readerNotifier.getCurrentPagePlainText();
    final insights = const OfflineAiService().analyzeText(plainText);
    final densityTier =
        TextDensityTier.fromComplexityLabel(insights.complexityLevel);
    final speedState = ref.read(speedReadingProvider);
    final isPro = ref.read(subscriptionProvider).isPro;
    final targetWpm = speedState.targetWpmForDensity(densityTier);
    final canStartFreeToday = speedState.canStartFreeFasilToday(isPro: isPro);
    final theme = Theme.of(context);

    var selectedPreset = FasilDurationPreset.spark5;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (modalCtx, setSheetState) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.outline.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Icon(
                        Icons.bolt_rounded,
                        color: AppColors.amberGold,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Sayfa İçi Akıcı Fasıl',
                          style: GoogleFonts.literata(
                            fontSize: 17.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => Navigator.of(sheetCtx).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  Text(
                    'Sayfa ${readerState.currentPage} • ${densityTier.label} • Hedef $targetWpm WPM',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: FasilDurationPreset.values.map((preset) {
                      final isSelected = preset == selectedPreset;
                      final locked = preset.requiresPro && !isPro;
                      return ChoiceChip(
                        selected: isSelected,
                        selectedColor:
                            AppColors.terracotta.withValues(alpha: 0.18),
                        onSelected: (_) {
                          if (locked) {
                            Navigator.of(sheetCtx).pop();
                            TahrirProSheet.show(context);
                            return;
                          }
                          setSheetState(() => selectedPreset = preset);
                        },
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${preset.minutes} Dk',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                              ),
                            ),
                            if (locked) ...[
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.lock_outline_rounded,
                                size: 13,
                                color: AppColors.amberGold,
                              ),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    selectedPreset.subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        Navigator.of(sheetCtx).pop();
                        if (!canStartFreeToday ||
                            (selectedPreset.requiresPro && !isPro)) {
                          TahrirProSheet.show(context);
                          return;
                        }
                        final activeBook =
                            ref.read(readerProvider).currentBook ?? widget.book;
                        LexicalWarmupSheet.show(
                          context,
                          loadPack: () => ref
                              .read(speedReadingProvider.notifier)
                              .prepareBookWarmupPack(
                                book: activeBook,
                                fallbackPageText: plainText,
                              ),
                          preset: selectedPreset,
                          onLaunchFasil: () {
                            if (!mounted) return;
                            _startGuidedFasil(
                              durationMinutes: selectedPreset.minutes,
                            );
                          },
                        );
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.terracotta,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        '⚡ 60 Sn Isın ve Fasla Başla',
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(sheetCtx).pop();
                        _startGuidedFasil(
                          durationMinutes: selectedPreset.minutes,
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Doğrudan Sayfa İçi Faslı Başlat',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Divider(
                    height: 1,
                    color: theme.colorScheme.outline.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.center_focus_strong_rounded,
                      color: AppColors.amberGold,
                    ),
                    title: Text(
                      'Tarama Modu (RSVP + ORP)',
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      'Odak noktalı hızlı tarama aracıyla sayfayı gözden geçir',
                      style: GoogleFonts.inter(fontSize: 11.5),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.of(sheetCtx).pop();
                      if (plainText.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Bu sayfada tarama modu için yeterli metin bulunamadı.',
                            ),
                          ),
                        );
                        return;
                      }
                      EyeWorkshopSheet.showSecondaryRsvp(
                        context,
                        text: plainText,
                        title:
                            '${widget.book.title} • Sayfa ${readerState.currentPage}',
                        initialWpm: targetWpm,
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _openConceptRadarFor(String initialConcept) {
    ref.read(guidedFlowProvider.notifier).pauseForInteraction();
    if (!ref.read(subscriptionProvider).isPro) {
      TahrirProSheet.show(context);
      return;
    }
    final insights = ref.read(readerProvider.notifier).getPageInsights();
    ConceptRadarSheet.show(
      context,
      initialConcept: initialConcept,
      suggestedConcepts: insights.keyConcepts,
      onJumpToPage: _jumpToPage,
    );
  }

  Widget _buildCompactViewSelector(ReaderState readerState, ThemeData theme) {
    final isPro = ref.watch(subscriptionProvider.select((s) => s.isPro));
    final activeMode = readerState.displayMode == ReaderDisplayMode.originalPdf
        ? 'pdf'
        : (readerState.displayMode == ReaderDisplayMode.opticalReflow
            ? 'optical'
            : 'reflow');

    Widget buildChip(String modeKey, String label, {bool locked = false}) {
      final isSelected = activeMode == modeKey;
      return InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          if (locked) {
            TahrirProSheet.show(context);
            return;
          }
          final notifier = ref.read(readerProvider.notifier);
          if (modeKey == 'reflow') {
            notifier.setDisplayMode(ReaderDisplayMode.textReflow);
          } else if (modeKey == 'optical') {
            notifier.setDisplayMode(ReaderDisplayMode.opticalReflow);
          } else if (modeKey == 'pdf') {
            notifier.setDisplayMode(ReaderDisplayMode.originalPdf);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primary.withValues(alpha: 0.16)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.72),
                ),
              ),
              if (locked) ...[
                const SizedBox(width: 2),
                const Icon(
                  Icons.lock_outline_rounded,
                  size: 11,
                  color: AppColors.amberGold,
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          buildChip('reflow', 'Akış', locked: !isPro),
          buildChip('optical', 'Baskı', locked: !isPro),
          buildChip('pdf', 'PDF'),
        ],
      ),
    );
  }

  Widget _buildBottomQuickAction({
    required ThemeData theme,
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    Color? accentColor,
  }) {
    final effectiveColor = accentColor ??
        (isActive
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurface.withValues(alpha: 0.82));

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: effectiveColor),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10.5,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                color: effectiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAudioAndAmbientSheet(
    BuildContext context,
    ReaderState readerState,
    ThemeData theme,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outline.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Sesli Okuma & Ambiyans',
                style: GoogleFonts.literata(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor:
                      theme.colorScheme.primary.withValues(alpha: 0.14),
                  child: Icon(
                    readerState.isTtsPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: theme.colorScheme.primary,
                  ),
                ),
                title: Text(
                  readerState.isTtsPlaying
                      ? 'Sesli Okumayı Duraklat (TTS)'
                      : 'Bu Sayfayı Sesli Dinle (TTS)',
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  'Sayfadaki metni kelime takibiyle seslendirir.',
                  style: GoogleFonts.inter(fontSize: 11.5),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  if (_isPageGatedBySmartReflowPro(readerState)) {
                    TahrirProSheet.show(context);
                    return;
                  }
                  ref.read(readerProvider.notifier).toggleTts();
                },
              ),
              const Divider(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: AppColors.amberGold.withValues(alpha: 0.16),
                  child: const Icon(
                    Icons.graphic_eq_rounded,
                    color: AppColors.amberGold,
                  ),
                ),
                title: Text(
                  'Stüdyo Ambiyans Sesleri & Odak',
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  'Yağmur, Kütüphane, Şömine ve Ney sesleriyle odaklanın.',
                  style: GoogleFonts.inter(fontSize: 11.5),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  final notifier = ref.read(readerProvider.notifier);
                  AmbientSoundSheet.show(context, notifier.ambientService);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showReaderToolsSheet(
    BuildContext context,
    ReaderState readerState,
    ReaderThemeState themeState,
  ) {
    ref.read(guidedFlowProvider.notifier).pauseForInteraction();
    final theme = Theme.of(context);
    final isPro = ref.read(subscriptionProvider).isPro;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outline.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Okuma Araçları & İçindekiler',
                style: GoogleFonts.literata(
                  fontSize: 17.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.format_list_bulleted_rounded),
                title: const Text('İçindekiler & Dipnotlar'),
                subtitle: const Text('Bölümler ve sayfa gezgini'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showTableOfContentsSheet(context, readerState);
                },
              ),
              if (widget.book.format == BookFormat.pdf)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.compare_rounded,
                    color: AppColors.amberGold,
                  ),
                  title: Text(
                    readerState.isXRaySplitMode
                        ? '📐 X-Ray Karşılaştırmayı Kapat'
                        : '📐 X-Ray Karşılaştırma (Orijinal + Akış)',
                  ),
                  subtitle: const Text(
                    'Orijinal PDF ve Metin Akışını üst üste kıyasla',
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    if (!isPro) {
                      TahrirProSheet.show(context);
                      return;
                    }
                    ref.read(readerProvider.notifier).toggleXRaySplitMode();
                  },
                ),
              Builder(
                builder: (_) {
                  final report = readerState.currentReflowData?.ocrReviewReport ??
                      const OcrPageReviewReport.empty();
                  final accuracy = report.pageAccuracyPercent.toStringAsFixed(0);
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.spellcheck_rounded,
                      color: Color(0xFF10B981),
                    ),
                    title: const Text('✨ Gözden Geçir & Kusursuz Okuma Tashihi'),
                    subtitle: Text(
                      'Berraklık %$accuracy · ${report.suggestionCount} şüpheli · ${report.autoCorrectedCount} otomatik tashih',
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      if (!isPro) {
                        TahrirProSheet.show(context);
                        return;
                      }
                      OcrReviewSheet.show(context);
                    },
                  );
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.bolt_rounded,
                  color: AppColors.amberGold,
                ),
                title: const Text('⚡ Sayfa İçi Akıcı Fasıl'),
                subtitle: const Text(
                  '60 sn ısınma, ritim kalibrasyonu ve RSVP tarama',
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  if (!isPro) {
                    TahrirProSheet.show(context);
                    return;
                  }
                  _openLiveSpeedReadingCoach(readerState);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.radar_rounded,
                  color: AppColors.terracotta,
                ),
                title: Row(
                  children: [
                    const Expanded(child: Text('🧭 Kavram Radarı')),
                    if (!isPro)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.amberGold.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'PRO',
                          style: GoogleFonts.inter(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.amberGold,
                          ),
                        ),
                      ),
                  ],
                ),
                subtitle: const Text('Kitap boyunca kavram indeksini tara'),
                onTap: () {
                  Navigator.pop(ctx);
                  if (!isPro) {
                    TahrirProSheet.show(context);
                    return;
                  }
                  _openConceptRadarFor('');
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.self_improvement_rounded),
                title: Text(
                  readerState.isRitualActive
                      ? '🕯️ 25 Dk Odak Seansını Bitir'
                      : '🕯️ 25 Dk Odak Seansı Başlat',
                ),
                subtitle: const Text('Pomodoro sayacı ve odak ritüeli'),
                onTap: () {
                  Navigator.pop(ctx);
                  if (!isPro) {
                    TahrirProSheet.show(context);
                    return;
                  }
                  final notifier = ref.read(readerProvider.notifier);
                  if (readerState.isRitualActive) {
                    notifier.stopMutalaaRitual();
                  } else {
                    notifier.startMutalaaRitual();
                  }
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.psychology_outlined),
                title: const Text('🧠 Sayfa Özeti & Çalışma Soruları'),
                subtitle: const Text('3 maddelik özet ve Sokratik sorular'),
                onTap: () {
                  Navigator.pop(ctx);
                  if (!isPro) {
                    TahrirProSheet.show(context);
                    return;
                  }
                  _showAiInsightsDialog(context);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  readerState.isLineFocusEnabled
                      ? Icons.line_weight_rounded
                      : Icons.horizontal_rule_rounded,
                ),
                title: Text(
                  readerState.isLineFocusEnabled
                      ? '📏 Odak Cetvelini Kapat'
                      : '📏 Odak Cetvelini Aç',
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  if (!isPro) {
                    TahrirProSheet.show(context);
                    return;
                  }
                  ref.read(readerProvider.notifier).toggleLineFocus();
                },
              ),
              if (widget.book.format == BookFormat.pdf)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.crop_rounded),
                  title: Text(
                    readerState.isPdfAutoCrop
                        ? '✂️ Otomatik Kenar Kırpma (Açık)'
                        : '✂️ Otomatik Kenar Kırpma (Kapalı)',
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    if (!isPro) {
                      TahrirProSheet.show(context);
                      return;
                    }
                    final nextCrop = !readerState.isPdfAutoCrop;
                    ref.read(readerProvider.notifier).togglePdfAutoCrop();
                    _pdfViewerController.zoomLevel = nextCrop ? 1.18 : 1.0;
                  },
                ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.fullscreen_rounded),
                title: Text(
                  readerState.isZenMode
                      ? '⛶ Tam Ekran Zen Modundan Çık'
                      : '⛶ Tam Ekran Zen Modu',
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  if (!isPro) {
                    TahrirProSheet.show(context);
                    return;
                  }
                  ref.read(readerProvider.notifier).toggleZenMode();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPageSlider(ReaderState readerState, ThemeData theme) {
    final rawTotal = readerState.currentBook?.totalPages ?? widget.book.totalPages;
    final total = rawTotal > 0 ? rawTotal : 1;
    final current = readerState.currentPage.clamp(1, total).toDouble();

    return Row(
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: 'Önceki Sayfa',
          icon: const Icon(Icons.chevron_left_rounded, size: 24),
          onPressed: _goToPreviousPage,
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2.5,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            ),
            child: Slider(
              value: current,
              min: 1,
              max: total.toDouble(),
              divisions: total > 1 ? total - 1 : 1,
              onChanged: (val) {
                _jumpToPage(val.round());
              },
            ),
          ),
        ),
        Text(
          'Sayfa ${readerState.currentPage}/$total',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: 'Sonraki Sayfa',
          icon: const Icon(Icons.chevron_right_rounded, size: 24),
          onPressed: _goToNextPage,
        ),
      ],
    );
  }

  Widget _buildSmartReflowProShieldCard(
    ReaderState readerState,
    ThemeData theme,
  ) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 90, 24, 140),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: AppColors.amberGold.withValues(alpha: 0.55),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: AppColors.amberGold.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: AppColors.amberGold,
                    size: 30,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Akıllı Reflow, OCR & EPUB/MD — Tahrir Pro',
                textAlign: TextAlign.center,
                style: GoogleFonts.literata(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Temel kullanımda kitaplarınızı Orijinal PDF görünümünde ücretsiz okuyabilir ve günlük serinizi takip edebilirsiniz. Akıllı Parşömen Akışı, 300 DPI OCR, Zemberek tashih ve X-Ray modu için Tahrir Pro\'ya geçebilir veya 3 ödüllü reklamla 24 saat ücretsiz Pro açabilirsiniz.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  height: 1.48,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.76),
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.terracotta,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => TahrirProSheet.show(context),
                icon: const Icon(Icons.workspace_premium_rounded, size: 19),
                label: Text(
                  '✨ Pro Aç • veya 3 Reklamla 24s Pro',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (widget.book.format == BookFormat.pdf) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () =>
                      ref.read(readerProvider.notifier).setOriginalPdfView(true),
                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                  label: Text(
                    '📄 Orijinal PDF Görünümünde Ücretsiz Okumaya Devam Et',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showPopupLugatForWord(
    BuildContext context,
    String tappedWord,
    String paragraphText,
    OcrPageReviewReport ocrReport,
    int pageNumber,
  ) {
    if (!ref.read(subscriptionProvider).isPro) {
      TahrirProSheet.show(context);
      return;
    }
    final cleanLower = OcrProofreaderEngine.toTurkishLower(
      tappedWord.replaceAll(
        RegExp(r'^[^\p{L}\p{N}]+|[^\p{L}\p{N}]+$', unicode: true),
        '',
      ),
    );
    final strippedLower = OcrProofreaderEngine.toTurkishLower(
      tappedWord.replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), ''),
    );
    if (cleanLower.isEmpty && strippedLower.isEmpty) return;
    ref.read(guidedFlowProvider.notifier).pauseForInteraction();

    OcrCorrectionItem? matchedCorrection;
    for (final c in ocrReport.autoCorrections) {
      final corrLower = OcrProofreaderEngine.toTurkishLower(c.correctedWord);
      final origLower = OcrProofreaderEngine.toTurkishLower(c.originalWord);
      if (corrLower == cleanLower ||
          origLower == cleanLower ||
          corrLower == strippedLower ||
          origLower == strippedLower) {
        matchedCorrection = c;
        break;
      }
    }

    OcrSuggestionItem? matchedSuggestion;
    for (final s in ocrReport.suggestions) {
      final suspLower = OcrProofreaderEngine.toTurkishLower(s.suspiciousWord);
      if (suspLower == cleanLower || suspLower == strippedLower) {
        matchedSuggestion = s;
        break;
      }
    }

    PopupLugatCard.show(
      context,
      word: tappedWord,
      surroundingParagraph: paragraphText,
      ocrCorrection: matchedCorrection,
      ocrSuggestion: matchedSuggestion,
      onCorrectWord: (w) => OcrReviewSheet.showQuickWordCorrectionDialog(
        context,
        ref,
        w,
      ),
      onApplyDirectCorrection: (orig, corr) {
        ref.read(readerProvider.notifier).applyOcrWordCorrection(
              originalWord: orig,
              correctedWord: corr,
            );
      },
      onOpenFullDictionary: (w) => DictionarySheet.show(context, w),
      onOpenConceptRadar: _openConceptRadarFor,
      onAddHighlight: (w) => _showAddHighlightDialog(
        context,
        selectedText: w,
        pageNumber: pageNumber,
      ),
    );
  }

  void _openWordPeekSheet(
    BuildContext context,
    String targetWord,
    OcrPageReviewReport ocrReport,
    ReaderState readerState,
  ) {
    final cleanLower = OcrProofreaderEngine.toTurkishLower(
      targetWord.replaceAll(
        RegExp(r'^[^\p{L}\p{N}]+|[^\p{L}\p{N}]+$', unicode: true),
        '',
      ),
    );
    OcrCorrectionItem? matchedCorrection;
    for (final c in ocrReport.autoCorrections) {
      if (OcrProofreaderEngine.toTurkishLower(c.correctedWord) == cleanLower ||
          OcrProofreaderEngine.toTurkishLower(c.originalWord) == cleanLower) {
        matchedCorrection = c;
        break;
      }
    }
    WordPeekSheet.show(
      context,
      word: targetWord,
      bookFilePath: widget.book.filePath,
      pageNumber: readerState.currentPage,
      wordBoxes: readerState.currentReflowData?.wordBoxes ?? const [],
      correction: matchedCorrection,
      onCorrectWord: () => OcrReviewSheet.showQuickWordCorrectionDialog(
        context,
        ref,
        targetWord,
      ),
    );
  }

  Widget _buildOpticalReflowContent(
    ReaderState readerState,
    ReaderThemeState themeState,
    ThemeData theme,
  ) {
    final isPro = ref.watch(subscriptionProvider.select((s) => s.isPro));
    if (!isPro) {
      return _buildSmartReflowProShieldCard(readerState, theme);
    }

    final reflowData = readerState.currentReflowData;
    return OpticalReflowView(
      alphaMaskPath: reflowData?.opticalAlphaMaskPath,
      wordBlobs: reflowData?.opticalWordBlobs ?? const [],
      imageWidth: reflowData?.opticalImageWidth ?? 0,
      imageHeight: reflowData?.opticalImageHeight ?? 0,
      themeState: themeState,
      scrollController: _reflowScrollController,
      padding: EdgeInsets.fromLTRB(
        themeState.sideMargin,
        _showControls ? 86 : 24,
        themeState.sideMargin,
        _showControls ? 136 : 40,
      ),
      onSwitchToOriginalPdf: () => ref
          .read(readerProvider.notifier)
          .setDisplayMode(ReaderDisplayMode.originalPdf),
    );
  }

  Widget _buildSmartReflowContent(
    ReaderState readerState,
    ReaderThemeState themeState,
    ThemeData theme,
    GuidedFlowState guidedFlow,
  ) {
    final isPro = ref.watch(subscriptionProvider.select((s) => s.isPro));
    if (!isPro) {
      return _buildSmartReflowProShieldCard(readerState, theme);
    }

    final reflowData = readerState.currentReflowData;
    final contentBlocks = reflowData?.contentBlocks ?? const <ContentBlock>[];
    final footnotes = reflowData?.footnotes ?? const <PageFootnote>[];
    final showWarning = reflowData?.hasNonLatinOrVisualWarning ?? false;
    final ocrReport =
        reflowData?.ocrReviewReport ?? const OcrPageReviewReport.empty();
    final autoCorrectedSet = {
      for (final c in ocrReport.autoCorrections)
        OcrProofreaderEngine.toTurkishLower(c.correctedWord),
    };
    final suspiciousSet = {
      for (final s in ocrReport.suggestions)
        OcrProofreaderEngine.toTurkishLower(s.suspiciousWord),
    };

    // If page contains no text (e.g. cover page, illustration, or scanned PDF)
    if ((contentBlocks.isEmpty &&
            (reflowData?.paragraphs.isEmpty ?? true) &&
            readerState.epubChapters.isEmpty) ||
        (reflowData != null && !reflowData.hasTextContent && readerState.epubChapters.isEmpty)) {
      return _buildEmptyOrCoverPage(readerState, themeState, theme);
    }

    final hasFootnotes = footnotes.isNotEmpty;
    final warningOffset = showWarning ? 1 : 0;
    final totalItems = contentBlocks.isNotEmpty
        ? (contentBlocks.length + (hasFootnotes ? 1 : 0) + warningOffset)
        : ((reflowData?.paragraphs.length ??
                (readerState.epubChapters.isNotEmpty
                    ? readerState.epubChapters[readerState.currentEpubChapterIndex]
                        .paragraphs
                        .length
                    : 0)) +
            (hasFootnotes ? 1 : 0) +
            warningOffset);

    return ListView.builder(
      controller: _reflowScrollController,
      cacheExtent: 2500,
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        themeState.sideMargin,
        _showControls ? 86 : 24,
        themeState.sideMargin,
        (_showControls || guidedFlow.isActive) ? 136 : 40,
      ),
      itemCount: totalItems,
      itemBuilder: (context, index) {
        // En üstte Latin harfleri dışındaki dil / hat / görsel uyarısı
        if (showWarning && index == 0) {
          return NonLatinWarningBanner(
            onTap: () => ref.read(readerProvider.notifier).setOriginalPdfView(true),
          );
        }

        final effectiveIndex = index - warningOffset;
        final activeChunk = guidedFlow.isActive ? guidedFlow.activeChunk : null;
        final ({int start, int end, double opacity})? guidedChunkRange =
            (activeChunk != null && activeChunk.paragraphIndex == effectiveIndex)
                ? (
                    start: activeChunk.startOffset,
                    end: activeChunk.endOffset,
                    opacity: guidedFlow.phase.highlightOpacity,
                  )
                : null;

        // ContentBlock tabanlı modern render
        if (contentBlocks.isNotEmpty) {
          if (effectiveIndex < contentBlocks.length) {
            final block = contentBlocks[effectiveIndex];
            switch (block) {
              case CalligraphyHeaderBlock():
                return CalligraphyHeaderWidget(headerBlock: block);
              case TextBlock():
                return TextBlockWidget(
                  block: block,
                  themeState: themeState,
                  activeTtsWord: readerState.activeTtsWord,
                  isReadingAloud: readerState.isTtsPlaying,
                  activeGuidedChunkRange: guidedChunkRange,
                  blockHighlights: readerState.currentPageHighlights,
                  isOcrReviewHighlightEnabled:
                      readerState.isOcrReviewHighlightEnabled,
                  autoCorrectedWordsLower: autoCorrectedSet,
                  suspiciousWordsLower: suspiciousSet,
                  onPlayTts: () => ref.read(readerProvider.notifier).toggleTts(),
                  onTapWord: (tappedWord, paragraphText) =>
                      _showPopupLugatForWord(
                    context,
                    tappedWord,
                    paragraphText,
                    ocrReport,
                    readerState.currentPage,
                  ),
                  onLongPressWord: (peekWord, _) => _openWordPeekSheet(
                    context,
                    peekWord,
                    ocrReport,
                    readerState,
                  ),
                  onCorrectWord: (selected) =>
                      OcrReviewSheet.showQuickWordCorrectionDialog(
                    context,
                    ref,
                    selected,
                  ),
                  onOpenDictionary: (selected) {
                    ref.read(guidedFlowProvider.notifier).pauseForInteraction();
                    DictionarySheet.show(context, selected);
                  },
                  onOpenConceptRadar: _openConceptRadarFor,
                  onOpenQuoteStudio: (selected) {
                    ref.read(guidedFlowProvider.notifier).pauseForInteraction();
                    QuoteStudioSheet.show(
                      context,
                      quoteText: selected,
                      bookTitle: widget.book.title,
                      author: widget.book.author,
                      onSaveToNotes: () => _saveQuoteCardToNotes(
                        selectedText: selected,
                        pageNumber: readerState.currentPage,
                      ),
                    );
                  },
                  onAddHighlight: (selected) => _showAddHighlightDialog(
                    context,
                    selectedText: selected,
                    pageNumber: readerState.currentPage,
                  ),
                );
              case OpticalInkBlock():
                return OpticalInkBlockWidget(block: block);
              case InteractiveSnippetBlock():
                return InteractiveSnippetBadgeWidget(snippet: block);
            }
          }
          return _buildPageFootnotesSection(footnotes, themeState, theme);
        }

        // Geriye dönük uyumluluk (Epub / legacy paragraphs)
        final paragraphs = reflowData?.paragraphs ??
            (readerState.epubChapters.isNotEmpty
                ? readerState.epubChapters[readerState.currentEpubChapterIndex].paragraphs
                : <ParagraphSegment>[]);

        if (effectiveIndex < paragraphs.length) {
          final segment = paragraphs[effectiveIndex];
          if (segment.isCalligraphyFallback) {
            return _buildCalligraphyFallbackBanner(segment, theme);
          }
          if (segment.isArabic) {
            return _buildArabicBlock(segment, themeState, theme);
          }
          if (segment.isHeading) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                segment.rawText,
                style: GoogleFonts.literata(
                  fontSize: themeState.fontSize + 4,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.primary,
                  height: 1.3,
                ),
              ),
            );
          }
          return TextBlockWidget(
            block: TextBlock(
              text: segment.rawText,
              isHeading: segment.isHeading,
              isArabic: segment.isArabic,
              footnoteAnchors: segment.footnoteAnchors,
            ),
            themeState: themeState,
            activeTtsWord: readerState.activeTtsWord,
            isReadingAloud: readerState.isTtsPlaying,
            activeGuidedChunkRange: guidedChunkRange,
            blockHighlights: readerState.currentPageHighlights,
            isOcrReviewHighlightEnabled:
                readerState.isOcrReviewHighlightEnabled,
            autoCorrectedWordsLower: autoCorrectedSet,
            suspiciousWordsLower: suspiciousSet,
            onPlayTts: () => ref.read(readerProvider.notifier).toggleTts(),
            onTapWord: (tappedWord, paragraphText) => _showPopupLugatForWord(
              context,
              tappedWord,
              paragraphText,
              ocrReport,
              readerState.currentPage,
            ),
            onLongPressWord: (peekWord, _) => _openWordPeekSheet(
              context,
              peekWord,
              ocrReport,
              readerState,
            ),
            onCorrectWord: (selected) =>
                OcrReviewSheet.showQuickWordCorrectionDialog(
              context,
              ref,
              selected,
            ),
            onOpenDictionary: (selected) {
              ref.read(guidedFlowProvider.notifier).pauseForInteraction();
              DictionarySheet.show(context, selected);
            },
            onOpenConceptRadar: _openConceptRadarFor,
            onOpenQuoteStudio: (selected) {
              ref.read(guidedFlowProvider.notifier).pauseForInteraction();
              QuoteStudioSheet.show(
                context,
                quoteText: selected,
                bookTitle: widget.book.title,
                author: widget.book.author,
                onSaveToNotes: () => _saveQuoteCardToNotes(
                  selectedText: selected,
                  pageNumber: readerState.currentPage,
                ),
              );
            },
            onAddHighlight: (selected) => _showAddHighlightDialog(
              context,
              selectedText: selected,
              pageNumber: readerState.currentPage,
            ),
          );
        }

        return _buildPageFootnotesSection(footnotes, themeState, theme);
      },
    );
  }

  Widget _buildCalligraphyFallbackBanner(ParagraphSegment segment, ThemeData theme) {
    return InlineCropCard(
      imageBytes: segment.imageBytes,
      imagePath: segment.imagePath,
      caption: segment.rawText.isNotEmpty
          ? segment.rawText
          : '📜 Asıl Hat / Kaligrafi (Orijinal Sayfa Kesiti)',
      onSwitchToOriginalPdf: () => ref.read(readerProvider.notifier).toggleDualView(),
    );
  }

  Widget _buildArabicBlock(
    ParagraphSegment segment,
    ReaderThemeState themeState,
    ThemeData theme,
  ) {
    return ArabicTextCard(
      arabicText: segment.rawText,
      themeState: themeState,
      onPlayTts: () => ref.read(readerProvider.notifier).toggleTts(),
    );
  }

  Widget _buildPageFootnotesSection(
    List<PageFootnote> footnotes,
    ReaderThemeState themeState,
    ThemeData theme,
  ) {
    return Container(
      margin: const EdgeInsets.only(top: 24, bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bookmark_outline, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'SAYFA DİPNOTLARI',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          ...footnotes.map((fn) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(right: 8, top: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      fn.key,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      fn.content,
                      textAlign: TextAlign.justify,
                      style: GoogleFonts.literata(
                        fontSize: 13,
                        height: 1.5,
                        color: theme.colorScheme.onSurface.withOpacity(0.85),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildEmptyOrCoverPage(
    ReaderState readerState,
    ReaderThemeState themeState,
    ThemeData theme,
  ) {
    final isFirstPage = readerState.currentPage == 1;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.colorScheme.outline.withOpacity(0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    isFirstPage ? Icons.menu_book_rounded : Icons.image_outlined,
                    size: 34,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isFirstPage ? 'Kitap Kapağı / Ön Sayfa' : 'Görsel / Taranmış Mizanpaj',
                style: GoogleFonts.literata(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Sayfa ${readerState.currentPage} / ${widget.book.totalPages}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isFirstPage
                    ? 'Bu sayfa kapak görseli veya tipografik mizanpaj içeriyor. Sayfayı orijinal PDF formatında görüntüleyebilir veya okumaya devam etmek için sonraki sayfaya geçebilirsiniz.'
                    : 'Bu sayfada seçilebilir metin bulunamadı (taranmış sayfa, resim veya boş sayfa). Orijinal PDF görünümünde tam detaylı inceleyebilirsiniz.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.5,
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton.icon(
                    icon: const Icon(Icons.picture_as_pdf, size: 18),
                    label: const Text('Orijinal PDF Görünümü'),
                    onPressed: () =>
                        ref.read(readerProvider.notifier).setOriginalPdfView(true),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.arrow_forward, size: 18),
                    label: const Text('Sonraki Sayfa'),
                    onPressed: _goToNextPage,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.swipe, size: 16, color: theme.colorScheme.onSurface.withOpacity(0.4)),
                  const SizedBox(width: 6),
                  Text(
                    'Sayfa çevirmek için ekranda kaydırın (Swipe)',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  ColorFilter _resolvePdfColorFilter(ReaderThemeState themeState, Brightness brightness) {
    final isDark = brightness == Brightness.dark ||
        themeState.preset == TahrirThemePreset.amoled ||
        themeState.preset == TahrirThemePreset.sapphire ||
        themeState.preset == TahrirThemePreset.forest;

    if (isDark) {
      return const ColorFilter.matrix(<double>[
        -0.85, 0.0, 0.0, 0.0, 235.0,
        0.0, -0.85, 0.0, 0.0, 235.0,
        0.0, 0.0, -0.82, 0.0, 235.0,
        0.0, 0.0, 0.0, 1.0, 0.0,
      ]);
    }

    if (themeState.preset == TahrirThemePreset.parchment) {
      return const ColorFilter.matrix(<double>[
        0.96, 0.0, 0.0, 0.0, 0.0,
        0.0, 0.93, 0.0, 0.0, 0.0,
        0.0, 0.0, 0.85, 0.0, 0.0,
        0.0, 0.0, 0.0, 1.0, 0.0,
      ]);
    }

    // paperWhite (doğal kağıt tonu)
    return const ColorFilter.matrix(<double>[
      0.98, 0.0, 0.0, 0.0, 0.0,
      0.0, 0.975, 0.0, 0.0, 0.0,
      0.0, 0.0, 0.96, 0.0, 0.0,
      0.0, 0.0, 0.0, 1.0, 0.0,
    ]);
  }

  Widget _buildOriginalPdfView(
    ReaderState readerState,
    ReaderThemeState themeState,
    ThemeData theme, {
    bool forXRayComparison = false,
  }) {
    final file = File(widget.book.filePath);
    if (file.existsSync()) {
      final colorFilter = _resolvePdfColorFilter(themeState, theme.brightness);

      return Stack(
        children: [
          Positioned.fill(
            child: ColorFiltered(
              colorFilter: colorFilter,
              child: Container(
                color: Colors.white,
                child: SfPdfViewer.file(
                  file,
                  controller: _pdfViewerController,
                  canShowScrollHead: false,
                  canShowScrollStatus: false,
                  enableDoubleTapZooming: !forXRayComparison,
                  pageLayoutMode: PdfPageLayoutMode.single,
                  onPageChanged: (PdfPageChangedDetails details) {
                    ref.read(readerProvider.notifier).syncPdfPage(details.newPageNumber);
                  },
                  initialPageNumber: readerState.currentPage,
                ),
              ),
            ),
          ),
          if (!forXRayComparison)
            Positioned(
              right: 16,
              bottom: _showControls ? 116 : 24,
              child: Material(
                color: theme.colorScheme.surface.withOpacity(0.92),
                elevation: 4,
                borderRadius: BorderRadius.circular(24),
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () {
                    if (!ref.read(subscriptionProvider).isPro) {
                      TahrirProSheet.show(context);
                      return;
                    }
                    final nextCrop = !readerState.isPdfAutoCrop;
                    ref.read(readerProvider.notifier).togglePdfAutoCrop();
                    _pdfViewerController.zoomLevel = nextCrop ? 1.18 : 1.0;
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          readerState.isPdfAutoCrop ? Icons.crop : Icons.crop_free,
                          size: 16,
                          color: readerState.isPdfAutoCrop
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          readerState.isPdfAutoCrop ? 'Auto-Crop 1.18x' : 'Auto-Crop 1.0x',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: readerState.isPdfAutoCrop
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    }

    // Örnek eserler için X-Ray karşılaştırmasında gerçekçi çift sütunlu sıkışık PDF mizanpajı göster
    final rawText = readerState.currentReflowData?.rawText ?? '';
    final midpoint = (rawText.length ~/ 2).clamp(0, rawText.length);
    final leftCol = rawText.isNotEmpty ? rawText.substring(0, midpoint) : '';
    final rightCol = rawText.isNotEmpty ? rawText.substring(midpoint) : '';

    return Container(
      color: const Color(0xFFE5E5E5),
      padding: EdgeInsets.fromLTRB(
        14,
        _showControls ? 82 : 24,
        14,
        _showControls ? 128 : 28,
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.black26),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'PDF SCAN • MATBAA MİZANPAJI (2 SÜTUN)',
                  style: GoogleFonts.inter(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: Colors.black54,
                    letterSpacing: 0.8,
                  ),
                ),
                Text(
                  'S. ${readerState.currentPage}',
                  style: GoogleFonts.inter(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
            const Divider(color: Colors.black38, height: 10),
            Expanded(
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        leftCol,
                        textAlign: TextAlign.justify,
                        style: GoogleFonts.ebGaramond(
                          fontSize: 8.5,
                          height: 1.18,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 520,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      color: Colors.black12,
                    ),
                    Expanded(
                      child: Text(
                        rightCol,
                        textAlign: TextAlign.justify,
                        style: GoogleFonts.ebGaramond(
                          fontSize: 8.5,
                          height: 1.18,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (!forXRayComparison) ...[
              const Divider(color: Colors.black26, height: 12),
              Center(
                child: FilledButton.tonalIcon(
                  icon: const Icon(Icons.auto_stories, size: 16),
                  label: const Text('Tahrir Akıllı Akışa Dön'),
                  onPressed: () =>
                      ref.read(readerProvider.notifier).setOriginalPdfView(false),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _saveQuoteCardToNotes({
    required String selectedText,
    required int pageNumber,
  }) async {
    final trimmed = selectedText.trim();
    if (trimmed.isEmpty) return;
    ref.read(guidedFlowProvider.notifier).pauseForInteraction();

    final repo = ref.read(highlightRepositoryProvider);
    final habitRepo = ref.read(habitRepositoryProvider);
    final bookId = widget.book.id ?? 1;

    await repo.insertHighlight(
      HighlightEntity(
        bookId: bookId,
        pageNumber: pageNumber,
        selectedText: trimmed,
        userNote: 'Alıntı Stüdyosu Kartı',
        category: HighlightCategory.quote,
        colorHex: '#F59E0B',
        createdAt: DateTime.now(),
      ),
    );
    await ref.read(readerProvider.notifier).loadCurrentPageHighlights();
    ref.read(highlightsRevisionProvider.notifier).state++;

    final allRes = await repo.getAllHighlights();
    if ((allRes.dataOrNull?.length ?? 0) >= 10) {
      await habitRepo.addEarnedSeal('seal_scholar');
    }
  }

  void _showAddHighlightDialog(
    BuildContext context, {
    required String selectedText,
    required int pageNumber,
  }) {
    final trimmed = selectedText.trim();
    if (trimmed.isEmpty) return;
    ref.read(guidedFlowProvider.notifier).pauseForInteraction();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _AddHighlightBottomSheet(
        selectedText: trimmed,
        onSave: (category, colorHex, note) async {
          final repo = ref.read(highlightRepositoryProvider);
          final habitRepo = ref.read(habitRepositoryProvider);
          final bookId = widget.book.id ?? 1;
          await repo.insertHighlight(HighlightEntity(
            bookId: bookId,
            pageNumber: pageNumber,
            selectedText: trimmed,
            userNote: note.trim().isEmpty ? null : note.trim(),
            category: category,
            colorHex: colorHex,
            createdAt: DateTime.now(),
          ));
          await ref.read(readerProvider.notifier).loadCurrentPageHighlights();
          ref.read(highlightsRevisionProvider.notifier).state++;
          final allRes = await repo.getAllHighlights();
          if ((allRes.dataOrNull?.length ?? 0) >= 10) {
            await habitRepo.addEarnedSeal('seal_scholar');
          }
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('✨ Not ve vurgu kaydedildi!')),
            );
          }
        },
      ),
    );
  }


  void _showTableOfContentsSheet(BuildContext context, ReaderState readerState) {
    final theme = Theme.of(context);
    final chapters = readerState.epubChapters;
    final totalPages = (readerState.currentBook?.totalPages ?? widget.book.totalPages) > 0
        ? (readerState.currentBook?.totalPages ?? widget.book.totalPages)
        : 1;

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outline.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.format_list_bulleted, color: theme.colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      chapters.isNotEmpty
                          ? 'İçindekiler & Bölümler (${chapters.length})'
                          : 'Sayfa Gezgini ($totalPages Sayfa)',
                      style: GoogleFonts.literata(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                child: chapters.isNotEmpty
                    ? ListView.separated(
                        shrinkWrap: true,
                        itemCount: chapters.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, idx) {
                          final ch = chapters[idx];
                          final isCurrent = idx == readerState.currentEpubChapterIndex;
                          return ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              radius: 14,
                              backgroundColor: isCurrent
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.primary.withOpacity(0.12),
                              child: Text(
                                '${idx + 1}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isCurrent
                                      ? theme.colorScheme.onPrimary
                                      : theme.colorScheme.primary,
                                ),
                              ),
                            ),
                            title: Text(
                              ch.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.literata(
                                fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w500,
                                color: isCurrent
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurface,
                              ),
                            ),
                            trailing: isCurrent
                                ? Icon(Icons.check_circle, size: 18, color: theme.colorScheme.primary)
                                : null,
                            onTap: () {
                              Navigator.pop(ctx);
                              _jumpToPage(idx + 1);
                            },
                          );
                        },
                      )
                    : GridView.builder(
                        shrinkWrap: true,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 1.35,
                        ),
                        itemCount: totalPages,
                        itemBuilder: (_, idx) {
                          final pageNum = idx + 1;
                          final isCurrent = pageNum == readerState.currentPage;
                          return InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () {
                              Navigator.pop(ctx);
                              _jumpToPage(pageNum);
                            },
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isCurrent
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.surface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isCurrent
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.outline,
                                ),
                              ),
                              child: Text(
                                '$pageNum',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isCurrent
                                      ? theme.colorScheme.onPrimary
                                      : theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAiInsightsDialog(BuildContext context) {
    final insights = ref.read(readerProvider.notifier).getPageInsights();
    final theme = Theme.of(context);
    final estMins = (insights.estimatedReadTimeSeconds / 60).ceil().clamp(1, 120);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        title: Row(
          children: [
            const Icon(Icons.auto_awesome, color: Colors.amber),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Çevrimdışı Akıllı Katip',
                style: GoogleFonts.literata(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '📊 ${insights.complexityLevel}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '⏱️ ~$estMins dk okuma (${insights.estimatedReadTimeSeconds} sn)',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Kilit Kavramlar (Radarda İncelemek İçin Dokun):',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: insights.keyConcepts
                    .map((k) => ActionChip(
                          avatar: const Icon(Icons.radar_rounded, size: 13),
                          visualDensity: VisualDensity.compact,
                          label: Text(k, style: const TextStyle(fontSize: 11)),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _openConceptRadarFor(k);
                          },
                        ))
                    .toList(),
              ),
              const SizedBox(height: 12),
              Text(
                '3 Maddelik Hızlı Özet:',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 6),
              ...insights.summaryBulletPoints.map(
                (b) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '• $b',
                    style: GoogleFonts.literata(fontSize: 13, height: 1.4),
                  ),
                ),
              ),
              if (insights.studyQuestions.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  '🤔 Sokratik Tefekkür & Çalışma Soruları:',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                ...insights.studyQuestions.map(
                  (q) => Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: theme.colorScheme.primary.withOpacity(0.25),
                      ),
                    ),
                    child: Text(
                      '❓ $q',
                      style: GoogleFonts.literata(
                        fontSize: 12.5,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          FilledButton.tonalIcon(
            icon: const Icon(Icons.radar_rounded, size: 16),
            label: const Text('Kavram Radarı & İndeks'),
            onPressed: () {
              Navigator.pop(ctx);
              final initial =
                  insights.keyConcepts.isNotEmpty ? insights.keyConcepts.first : '';
              _openConceptRadarFor(initial);
            },
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Anladım'),
          ),
        ],
      ),
    );
  }
}

class _AddHighlightBottomSheet extends StatefulWidget {
  final String selectedText;
  final Future<void> Function(
    HighlightCategory category,
    String colorHex,
    String note,
  ) onSave;

  const _AddHighlightBottomSheet({
    required this.selectedText,
    required this.onSave,
  });

  @override
  State<_AddHighlightBottomSheet> createState() => _AddHighlightBottomSheetState();
}

class _AddHighlightBottomSheetState extends State<_AddHighlightBottomSheet> {
  late final TextEditingController _noteController;
  HighlightCategory _selectedCategory = HighlightCategory.thought;
  String _selectedColorHex = '#F59E0B';

  static const List<(String, String, Color)> _colorOptions = [
    ('#F59E0B', 'Kehribar', Color(0xFFF59E0B)),
    ('#10B981', 'Zümrüt', Color(0xFF10B981)),
    ('#EF4444', 'Lal', Color(0xFFEF4444)),
    ('#3B82F6', 'Safir', Color(0xFF3B82F6)),
    ('#8B5CF6', 'Mor', Color(0xFF8B5CF6)),
  ];

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  String _categoryEmoji(HighlightCategory cat) => switch (cat) {
        HighlightCategory.thought => '💡',
        HighlightCategory.quote => '✨',
        HighlightCategory.question => '❓',
        HighlightCategory.critical => '⚡',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outline.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '✍️ Not & Vurgu Ekle',
                style: GoogleFonts.literata(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.primary.withOpacity(0.25),
                  ),
                ),
                child: Text(
                  '“${widget.selectedText}”',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.literata(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Kategori Seçin',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: HighlightCategory.values.map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return ChoiceChip(
                    label: Text('${_categoryEmoji(cat)} ${cat.displayName}'),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _selectedCategory = cat),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Text(
                'Vurgu Rengi',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: _colorOptions.map((opt) {
                  final (hex, name, color) = opt;
                  final isSelected = _selectedColorHex == hex;
                  return InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => setState(() => _selectedColorHex = hex),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: color.withOpacity(isSelected ? 0.25 : 0.10),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? color : color.withOpacity(0.4),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            name,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _noteController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Notunuz (İsteğe Bağlı)',
                  hintText: 'Bu metin hakkındaki düşüncenizi veya notunuzu yazın...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                  label: const Text('Notu Kaydet'),
                  onPressed: () async {
                    final note = _noteController.text;
                    Navigator.pop(context);
                    await widget.onSave(
                      _selectedCategory,
                      _selectedColorHex,
                      note,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


