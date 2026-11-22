import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/zikir_seed_data.dart';
import '../../../../core/layout/foldable_layout_info.dart';
import '../../../../core/layout/foldable_two_pane.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/sound_pool_service.dart';
import '../../../../core/services/screen_awake_service.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/utils/quran_word_highlighter.dart';
import '../../../gamification/models/user_rank.dart';
import '../../../gamification/providers/gamification_providers.dart';
import '../../../kuran/providers/kuran_providers.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../providers/zikir_providers.dart';
import '../widgets/circular_counter_painter.dart';
import '../widgets/add_edit_zikir_sheet.dart';
import '../widgets/zikir_selection_sheet.dart';
import '../widgets/zikir_share_card_widget.dart';
import '../widgets/zikir_share_preview_modal.dart';
import '../../../../core/services/cloud_sync_engine.dart';
import '../../../../core/providers/tv_mode_provider.dart';

class ZikirCounterScreen extends ConsumerStatefulWidget {
  final bool openSelectionSheetOnMount;

  const ZikirCounterScreen({
    super.key,
    this.openSelectionSheetOnMount = false,
  });

  @override
  ConsumerState<ZikirCounterScreen> createState() => _ZikirCounterScreenState();
}

class _ZikirCounterScreenState extends ConsumerState<ZikirCounterScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late AnimationController _birdLottieController;

  final FocusNode _desktopFocusNode = FocusNode();
  DateTime? _lastWheelScrollTime;

  bool _isQuickSettingsOpen = false;
  Timer? _quickSettingsTimer;
  bool _didConsumeOpenSheet = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 70),
      lowerBound: 0.0,
      upperBound: 0.04,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );

    _birdLottieController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final isTv = ref.read(isTvModeProvider);
      if (ref.read(settingsProvider).isKeepScreenAwakeEnabled || isTv) {
        ScreenAwakeService.setKeepAwake(true);
      }
      if (mounted && (Platform.isWindows || Platform.isMacOS || Platform.isLinux || isTv)) {
        _desktopFocusNode.requestFocus();
      }
    });
    _consumeOpenSheetIfNeeded();
  }

  @override
  void didUpdateWidget(covariant ZikirCounterScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.openSelectionSheetOnMount && widget.openSelectionSheetOnMount) {
      _didConsumeOpenSheet = false;
      _consumeOpenSheetIfNeeded();
    } else if (!widget.openSelectionSheetOnMount) {
      _didConsumeOpenSheet = false;
    }
  }

  void _consumeOpenSheetIfNeeded() {
    if (!widget.openSelectionSheetOnMount || _didConsumeOpenSheet) return;
    _didConsumeOpenSheet = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.replace('/zikir');
      _showSwitchZikirSheet();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _flushCurrentZikir();
    }
  }

  @override
  void deactivate() {
    _flushCurrentZikir();
    super.deactivate();
  }

  void _flushCurrentZikir() {
    Future.microtask(() async {
      await _flushCurrentZikirAsync();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _desktopFocusNode.dispose();
    _flushCurrentZikir();
    _quickSettingsTimer?.cancel();
    _animController.dispose();
    _birdLottieController.dispose();
    Future.microtask(() {
      try {
        CloudSyncEngine.instance.read(isZikirFocusModeProvider.notifier)?.state = false;
      } catch (e) {
        debugPrint('[ZikirCounterScreen] reset focus mode error: $e');
      }
    });
    super.dispose();
  }

  void _openQuickSettings() {
    setState(() => _isQuickSettingsOpen = true);
    _startQuickSettingsTimer();
  }

  void _closeQuickSettings() {
    _quickSettingsTimer?.cancel();
    _quickSettingsTimer = null;
    setState(() => _isQuickSettingsOpen = false);
  }

  void _startQuickSettingsTimer() {
    _quickSettingsTimer?.cancel();
    _quickSettingsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _isQuickSettingsOpen) {
        setState(() => _isQuickSettingsOpen = false);
      }
    });
  }

  void _resetQuickSettingsTimer() {
    if (_isQuickSettingsOpen) {
      _startQuickSettingsTimer();
    }
  }

  void _onTapCounter(
    ZikirCounterNotifier notifier,
    String? soundEffect,
    ZikirQuickSettingsState quickSettings,
  ) {
    _animController.forward().then((_) => _animController.reverse());
    if (quickSettings.isSoundEnabled) {
      SoundPoolService.playCounterSound(soundName: soundEffect ?? 'bulbul');
    }
    if (_birdLottieController.isAnimating) {
      _birdLottieController.reset();
    }
    _birdLottieController.forward(from: 0.0);
    notifier.increment(
      isInfinite: quickSettings.isInfiniteMode,
      isSoundEnabled: quickSettings.isSoundEnabled,
      isVibrationEnabled: quickSettings.isVibrationEnabled,
    );
  }

  double _getMainCounterFontSize(int count) {
    if (count < 1000) return 82;
    if (count < 10000) return 70;
    if (count < 100000) return 58;
    return 48;
  }

  double _getFocusCounterFontSize(int count) {
    if (count < 1000) return 120;
    if (count < 10000) return 100;
    if (count < 100000) return 84;
    return 68;
  }

  String? _getZikirVirtue(String name, [String? arabic]) {
    return ZikirSeedData.getVirtueForZikir(name, arabic: arabic);
  }

  void _showZikirDetails(String name, String? arabic, String category) {
    final colors = context.colors;
    final l10n = context.l10n;
    final isFocusMode = ref.read(isZikirFocusModeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark || isFocusMode;
    final virtue = _getZikirVirtue(name, arabic);
    final arabicFont = ref.read(arabicFontFamilyProvider);
    final isBoldArabic = ref.read(isBoldArabicProvider);
    final lowerCat = category.toLowerCase();
    final isDuaCat = lowerCat.contains('dua') || lowerCat.contains('prayer');
    final isEsmaCat = lowerCat.contains('esma') || lowerCat.contains('asma');
    final String detailSectionTitle = l10n.isTurkish
        ? (isDuaCat
            ? 'Âyet Meâli & Kaynak:'
            : (isEsmaCat ? 'İsmin Mânâsı & Sahih Hadis-i Şerif:' : 'Sahih Hadis-i Şerif & Fazileti:'))
        : (isDuaCat
            ? 'Verse Meaning & Source:'
            : (isEsmaCat ? 'Meaning & Authentic Hadith:' : 'Authentic Hadith & Virtues:'));

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.78,
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1F1A17) : colors.bottomSheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            bottom: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.accent.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: colors.primaryText,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      color: colors.secondaryTextAlt,
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                Flexible(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (arabic != null && arabic.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: colors.cardBackgroundAlt,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: colors.borderStroke.withValues(alpha: 0.6)),
                            ),
                            child: Text(
                              QuranWordHighlighter.formatArabicTextForFont(arabic, arabicFont),
                              textDirection: TextDirection.rtl,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: arabicFont,
                                fontSize: 28,
                                fontWeight: isBoldArabic ? FontWeight.bold : FontWeight.normal,
                                color: colors.zikirArabicColor,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        Text(
                          '${l10n.isTurkish ? "Kategori" : "Category"}: $category',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colors.accent),
                        ),
                        const SizedBox(height: 8),
                        if (virtue != null && virtue.isNotEmpty) ...[
                          Text(
                            detailSectionTitle,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colors.accent),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            virtue,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              color: colors.secondaryTextAlt,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _flushCurrentZikirAsync() async {
    try {
      if (!mounted) return;
      final currentZikir = ref.read(currentZikirProvider);
      if (currentZikir != null) {
        await ref
            .read(zikirCounterNotifierProvider(currentZikir.id).notifier)
            .flushPending();
        CloudSyncEngine.instance.triggerDebouncedSync(ref, delay: const Duration(seconds: 1));
      }
    } catch (e) {
      debugPrint('[ZikirCounterScreen] _flushCurrentZikirAsync error: $e');
    }
  }

  Future<void> _showSwitchZikirSheet() async {
    await _flushCurrentZikirAsync();
    if (!mounted) return;
    await ZikirSelectionSheet.show(
      context,
      onBeforeSelectZikir: _flushCurrentZikirAsync,
    );
  }

  @override
  Widget build(BuildContext context) {
    try {
      final currentZikir = ref.watch(currentZikirProvider);

      if (currentZikir == null) {
        final zikirs = ref.watch(zikirListStreamProvider).valueOrNull ?? [];
        return Scaffold(
          backgroundColor: context.colors.pageBackground,
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: context.colors.accent),
                const SizedBox(height: 16),
                Text(
                  context.l10n.isTurkish ? 'Zikir yükleniyor...' : 'Loading Dhikr...',
                  style: TextStyle(color: context.colors.primaryText, fontSize: 15),
                ),
                if (zikirs.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      ref.read(selectedZikirIdProvider.notifier).select(zikirs.first.id);
                    },
                    child: Text(
                      context.l10n.isTurkish ? '${zikirs.first.name} ile Başla' : 'Start with ${zikirs.first.name}',
                      style: TextStyle(color: context.colors.accent, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }

    final counterState = ref.watch(zikirCounterNotifierProvider(currentZikir.id));
    final counterNotifier = ref.read(zikirCounterNotifierProvider(currentZikir.id).notifier);
    final selectedBird = ref.watch(selectedBirdItemProvider);
    final arabicFont = ref.watch(arabicFontFamilyProvider);
    final isBoldArabic = ref.watch(isBoldArabicProvider);
    final isFocusMode = ref.watch(isZikirFocusModeProvider);
    final quickSettings = ref.watch(zikirQuickSettingsProvider);
    final quickSettingsNotifier = ref.read(zikirQuickSettingsProvider.notifier);
    final settings = ref.watch(userSettingsProvider);
    final colors = context.colors;
    final l10n = context.l10n;
    final layout = FoldableLayoutInfo.of(context);

    // =========================================================================
    // HILAL / OLED / FOCUS MODE (Pure AMOLED Black, Full-Screen Tap Target)
    // =========================================================================
    final Widget counterContent;
    if (isFocusMode) {
      counterContent = _buildFocusModeScaffold(
        layout: layout,
        counterState: counterState,
        counterNotifier: counterNotifier,
        currentZikir: currentZikir,
        quickSettings: quickSettings,
        l10n: l10n,
      );
    } else {
      final pageBg = colors.pageBackground;
      final headerPillBg = colors.headerBackground;
      final buttonInnerBg = colors.counterButtonColor;
      final arabicColor = colors.zikirArabicColor;
      final progressValue = quickSettings.isInfiniteMode ? 1.0 : counterState.progress;

      final arabicPromptArea = _buildArabicPromptArea(
        currentZikir: currentZikir,
        counterState: counterState,
        arabicFont: arabicFont,
        isBoldArabic: isBoldArabic,
        arabicColor: arabicColor,
        colors: colors,
        l10n: l10n,
        layout: layout,
        showTargetChip: layout.isTabletopPosture,
      );

      final circularCounter = _buildResponsiveCircularCounter(
        layout: layout,
        counterState: counterState,
        counterNotifier: counterNotifier,
        currentZikir: currentZikir,
        quickSettings: quickSettings,
        selectedBird: selectedBird,
        progressValue: progressValue,
        buttonInnerBg: buttonInnerBg,
        colors: colors,
        l10n: l10n,
      );

      final toolbarArea = _buildToolbarArea(
        layout: layout,
        currentZikir: currentZikir,
        counterState: counterState,
        counterNotifier: counterNotifier,
        quickSettings: quickSettings,
        quickSettingsNotifier: quickSettingsNotifier,
        isFocusMode: isFocusMode,
        arabicFont: arabicFont,
        headerPillBg: headerPillBg,
        colors: colors,
      );

      final Widget mainBody;
      if (layout.isTabletopPosture) {
        mainBody = FoldableTwoPane(
          key: const Key('zikir_tabletop_two_pane'),
          axis: FoldableSplitAxis.vertical,
          paneSpacing: 12.0,
          minVerticalPaneHeight: 120.0,
          startPane: arabicPromptArea,
          endPane: Column(
            children: [
              Expanded(child: circularCounter),
              toolbarArea,
            ],
          ),
        );
      } else if (layout.supportsTwoPaneHorizontal) {
        mainBody = FoldableTwoPane(
          key: const Key('zikir_horizontal_two_pane'),
          axis: FoldableSplitAxis.horizontal,
          paneProportion: 0.46,
          paneSpacing: 16.0,
          startPane: Column(
            children: [
              Expanded(child: arabicPromptArea),
              toolbarArea,
            ],
          ),
          endPane: circularCounter,
        );
      } else {
        mainBody = Column(
          children: [
            Expanded(flex: 4, child: arabicPromptArea),
            Expanded(flex: 6, child: circularCounter),
            toolbarArea,
          ],
        );
      }

      counterContent = Scaffold(
        backgroundColor: pageBg,
        body: SafeArea(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              if (settings.desktopFullScreenClickEnabled &&
                  (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
                _onTapCounter(counterNotifier, currentZikir.soundEffect, quickSettings);
              }
            },
            child: mainBody,
          ),
        ),
      );
    }

      return KeyboardListener(
        focusNode: _desktopFocusNode,
        autofocus: true,
        onKeyEvent: (KeyEvent event) {
          if (event is KeyDownEvent) {
            final isTv = ref.read(isTvModeProvider);
            final isSelect = event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.gameButtonA;
            final isSpace = event.logicalKey == LogicalKeyboardKey.space;
            final isEnter = event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.numpadEnter;
            final isArrow = event.logicalKey == LogicalKeyboardKey.arrowDown ||
                event.logicalKey == LogicalKeyboardKey.arrowUp;

            if (isSelect ||
                (isTv && (isSpace || isEnter || isArrow)) ||
                (isSpace && settings.desktopSpaceKeyEnabled) ||
                (isEnter && settings.desktopEnterKeyEnabled) ||
                (isArrow && settings.desktopArrowKeysEnabled)) {
              _onTapCounter(counterNotifier, currentZikir.soundEffect, quickSettings);
              return;
            }

            if (isTv &&
                (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
                    event.logicalKey == LogicalKeyboardKey.arrowRight)) {
              final zikirs = ref.read(zikirListStreamProvider).valueOrNull;
              if (zikirs != null && zikirs.length > 1) {
                final curIdx = zikirs.indexWhere((z) => z.id == currentZikir.id);
                if (curIdx != -1) {
                  final delta = event.logicalKey == LogicalKeyboardKey.arrowRight ? 1 : -1;
                  final nextIdx = (curIdx + delta + zikirs.length) % zikirs.length;
                  _flushCurrentZikir();
                  ref.read(selectedZikirIdProvider.notifier).select(zikirs[nextIdx].id);
                }
              }
            }
          }
        },
        child: Listener(
          onPointerSignal: (pointerSignal) {
            if (pointerSignal is PointerScrollEvent && settings.desktopMouseWheelEnabled) {
              final now = DateTime.now();
              if (_lastWheelScrollTime == null ||
                  now.difference(_lastWheelScrollTime!).inMilliseconds > 120) {
                _lastWheelScrollTime = now;
                _onTapCounter(counterNotifier, currentZikir.soundEffect, quickSettings);
              }
            }
          },
          child: counterContent,
        ),
      );
    } catch (e, stack) {
      debugPrint('[ZikirCounterScreen] Error in build: $e\n$stack');
      return Scaffold(
        backgroundColor: context.colors.pageBackground,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.refresh_rounded, color: context.colors.accent, size: 48),
                const SizedBox(height: 12),
                Text(
                  context.l10n.isTurkish ? 'Zikir Sayacı Hazırlanıyor' : 'Preparing Dhikr Counter',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: context.colors.primaryText),
                ),
                const SizedBox(height: 8),
                Text(
                  e.toString(),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: context.colors.secondaryTextAlt),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: Text(context.l10n.isTurkish ? 'Yenile' : 'Reload'),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  Widget _buildFocusModeScaffold({
    required FoldableLayoutInfo layout,
    required ZikirCounterState counterState,
    required ZikirCounterNotifier counterNotifier,
    required Zikir currentZikir,
    required ZikirQuickSettingsState quickSettings,
    required AppLocalizations l10n,
  }) {
    final returnToWorldPill = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          ref.read(isZikirFocusModeProvider.notifier).state = false;
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1F1F1F),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white24, width: 1),
          ),
          child: Text(
            l10n.translate('Zikir_ReturnToWorld'),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );

    final countDisplay = AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Text(
            '${counterState.currentCount}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: _getFocusCounterFontSize(counterState.currentCount),
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -1.0,
            ),
          ),
        );
      },
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          ref.read(isZikirFocusModeProvider.notifier).state = false;
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: layout.isTabletopPosture
              ? FoldableTwoPane(
                  axis: FoldableSplitAxis.vertical,
                  paneSpacing: 8,
                  minVerticalPaneHeight: 110,
                  startPane: Center(child: countDisplay),
                  endPane: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _onTapCounter(
                      counterNotifier,
                      currentZikir.soundEffect,
                      quickSettings,
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Text(
                            l10n.isTurkish ? 'DOKUN' : 'TAP',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 4.0,
                              color: Colors.white.withValues(alpha: 0.35),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 16,
                          left: 0,
                          right: 0,
                          child: Center(child: returnToWorldPill),
                        ),
                      ],
                    ),
                  ),
                )
              : GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _onTapCounter(
                    counterNotifier,
                    currentZikir.soundEffect,
                    quickSettings,
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        top: 14,
                        left: 0,
                        right: 0,
                        child: Center(child: returnToWorldPill),
                      ),
                      Center(child: countDisplay),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildArabicPromptArea({
    required Zikir currentZikir,
    required ZikirCounterState counterState,
    required String arabicFont,
    required bool isBoldArabic,
    required Color arabicColor,
    required AppThemeColors colors,
    required AppLocalizations l10n,
    required FoldableLayoutInfo layout,
    required bool showTargetChip,
  }) {
    final hasArabic =
        currentZikir.arabic != null && currentZikir.arabic!.isNotEmpty;
    final arabicSize = layout.isNarrowCoverScreen ? 32.0 : 38.0;

    return Center(
      key: const Key('zikir_arabic_prompt_area'),
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: layout.isNarrowCoverScreen ? 16 : 24,
          vertical: 12,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (hasArabic)
              GestureDetector(
                onTap: () => _showZikirDetails(
                  currentZikir.name,
                  currentZikir.arabic,
                  currentZikir.category,
                ),
                child: Text(
                  QuranWordHighlighter.formatArabicTextForFont(
                    currentZikir.arabic!,
                    arabicFont,
                  ),
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: arabicFont,
                    fontSize: arabicSize,
                    fontWeight: isBoldArabic ? FontWeight.bold : FontWeight.normal,
                    color: arabicColor,
                    height: 1.35,
                  ),
                ),
              ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => _showZikirDetails(
                currentZikir.name,
                currentZikir.arabic,
                currentZikir.category,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('💡', style: TextStyle(fontSize: 13)),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      l10n.isTurkish
                          ? 'Açıklama için metne dokunun'
                          : 'Tap text for details',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.secondaryTextAlt,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (showTargetChip) ...[
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: colors.headerBackground,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '${currentZikir.name} • ${counterState.currentCount} / ${currentZikir.target}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: colors.secondaryText,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResponsiveCircularCounter({
    required FoldableLayoutInfo layout,
    required ZikirCounterState counterState,
    required ZikirCounterNotifier counterNotifier,
    required Zikir currentZikir,
    required ZikirQuickSettingsState quickSettings,
    required BirdSelectionItem selectedBird,
    required double progressValue,
    required Color buttonInnerBg,
    required AppThemeColors colors,
    required AppLocalizations l10n,
  }) {
    final maxSide = layout.isMediumOrLarger ? 310.0 : 290.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final rawMax = math.min(
          constraints.maxWidth.isFinite ? constraints.maxWidth : 290.0,
          constraints.maxHeight.isFinite ? constraints.maxHeight : 290.0,
        );
        final targetBox = rawMax.clamp(120.0, maxSide);

        return Center(
          child: GestureDetector(
            key: const Key('zikir_counter_circle'),
            behavior: HitTestBehavior.opaque,
            onTap: () => _onTapCounter(
              counterNotifier,
              currentZikir.soundEffect,
              quickSettings,
            ),
            child: AnimatedBuilder(
              animation: _scaleAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: SizedBox(
                    width: targetBox,
                    height: targetBox,
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: SizedBox(
                        width: 290,
                        height: 290,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CustomPaint(
                              size: const Size(290, 290),
                              painter: CircularCounterPainter(
                                progress: progressValue,
                                progressColor: colors.counterProgressColor,
                                trackColor: Colors.transparent,
                                strokeWidth: 9.0,
                              ),
                            ),
                            Container(
                              width: 256,
                              height: 256,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: buttonInnerBg,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.06),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Positioned(
                                    top: 14,
                                    child: SizedBox(
                                      width: 100,
                                      height: 100,
                                      child: Lottie.asset(
                                        selectedBird.fileName,
                                        controller: _birdLottieController,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          return Center(
                                            child: Text(
                                              selectedBird.badge,
                                              style: const TextStyle(
                                                fontSize: 48,
                                              ),
                                            ),
                                          );
                                        },
                                        onLoaded: (comp) {
                                          if (mounted) {
                                            _birdLottieController.duration =
                                                comp.duration;
                                            _birdLottieController.value = 0.5;
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                  Center(
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 18),
                                      child: Text(
                                        '${counterState.currentCount}',
                                        style: TextStyle(
                                          fontSize: _getMainCounterFontSize(
                                            counterState.currentCount,
                                          ),
                                          fontWeight: FontWeight.bold,
                                          color: colors.counterValueColor,
                                          height: 1.0,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 20,
                                    child: Text(
                                      l10n.isTurkish ? 'DOKUN' : 'TAP',
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 3.0,
                                        color: Color(0xFFD1495B),
                                      ),
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
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildToolbarArea({
    required FoldableLayoutInfo layout,
    required Zikir currentZikir,
    required ZikirCounterState counterState,
    required ZikirCounterNotifier counterNotifier,
    required ZikirQuickSettingsState quickSettings,
    required ZikirQuickSettingsNotifier quickSettingsNotifier,
    required bool isFocusMode,
    required String arabicFont,
    required Color headerPillBg,
    required AppThemeColors colors,
  }) {
    final horizontalPad = layout.isNarrowCoverScreen ? 12.0 : 20.0;
    final bottomMargin = layout.useNavigationRail ? 8.0 : 12.0;

    return Container(
      height: 52,
      padding: EdgeInsets.symmetric(horizontal: horizontalPad),
      margin: EdgeInsets.only(bottom: bottomMargin),
      child: _isQuickSettingsOpen
          ? LayoutBuilder(
              builder: (context, constraints) {
                final toggleSize = constraints.maxWidth < 310 ? 30.0 : 36.0;
                final iconSize = constraints.maxWidth < 310 ? 15.5 : 18.0;
                return Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: headerPillBg,
                    borderRadius: BorderRadius.circular(23),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildSettingToggle(
                        icon: quickSettings.isSoundEnabled
                            ? Icons.volume_up_rounded
                            : Icons.volume_off_rounded,
                        isActive: quickSettings.isSoundEnabled,
                        onTap: () {
                          _resetQuickSettingsTimer();
                          quickSettingsNotifier.toggleSound();
                        },
                        activeBg: colors.accent,
                        size: toggleSize,
                        iconSize: iconSize,
                      ),
                      _buildSettingToggle(
                        icon: quickSettings.isVibrationEnabled
                            ? Icons.vibration_rounded
                            : Icons.smartphone_rounded,
                        isActive: quickSettings.isVibrationEnabled,
                        onTap: () {
                          _resetQuickSettingsTimer();
                          quickSettingsNotifier.toggleVibration();
                        },
                        activeBg: colors.accent,
                        size: toggleSize,
                        iconSize: iconSize,
                      ),
                      _buildSettingToggle(
                        icon: Icons.all_inclusive_rounded,
                        isActive: quickSettings.isInfiniteMode,
                        onTap: () async {
                          _resetQuickSettingsTimer();
                          final wasInfinite = quickSettings.isInfiniteMode;
                          await quickSettingsNotifier.toggleInfiniteMode();
                          if (wasInfinite) {
                            await counterNotifier.onExitInfiniteMode();
                          }
                        },
                        activeBg: colors.accent,
                        size: toggleSize,
                        iconSize: iconSize,
                      ),
                      _buildSettingToggle(
                        icon: Icons.nightlight_round,
                        isActive: isFocusMode,
                        onTap: () {
                          _closeQuickSettings();
                          ref.read(isZikirFocusModeProvider.notifier).state =
                              true;
                        },
                        activeBg: colors.accent,
                        size: toggleSize,
                        iconSize: iconSize,
                      ),
                      _buildSettingToggle(
                        icon: Icons.share_rounded,
                        isActive: false,
                        onTap: () {
                          _resetQuickSettingsTimer();
                          final virtue = _getZikirVirtue(
                            currentZikir.name,
                            currentZikir.arabic,
                          );
                          ZikirSharePreviewModal.show(
                            context: context,
                            zikirName: currentZikir.name,
                            arabicText: currentZikir.arabic,
                            virtue: virtue,
                            category: currentZikir.category,
                            currentCount: counterState.currentCount,
                            targetCount: currentZikir.target,
                            totalCount: counterState.totalCount,
                            arabicFontFamily: arabicFont,
                            initialTheme:
                                ZikirShareThemeData.themeForGoalOrTask(
                              category: currentZikir.category,
                              goalType: 'zikir',
                            ),
                          );
                        },
                        activeBg: colors.accent,
                        size: toggleSize,
                        iconSize: iconSize,
                      ),
                      _buildSettingToggle(
                        icon: Icons.refresh_rounded,
                        isActive: false,
                        onTap: () {
                          _resetQuickSettingsTimer();
                          counterNotifier.reset();
                        },
                        activeBg: colors.accent,
                        size: toggleSize,
                        iconSize: iconSize,
                      ),
                      _buildSettingToggle(
                        icon: Icons.close_rounded,
                        isActive: false,
                        onTap: _closeQuickSettings,
                        activeBg: colors.accent,
                        size: toggleSize,
                        iconSize: iconSize,
                      ),
                    ],
                  ),
                );
              },
            )
          : Row(
              children: [
                InkWell(
                  onTap: _openQuickSettings,
                  borderRadius: BorderRadius.circular(21),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: headerPillBg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.tune_rounded,
                      size: 20,
                      color: colors.secondaryText,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Center(
                    child: InkWell(
                      onTap: _showSwitchZikirSheet,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: headerPillBg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                currentZikir.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 15.0,
                                  fontWeight: FontWeight.bold,
                                  color: colors.secondaryText,
                                ),
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              Icons.arrow_drop_down_rounded,
                              size: 22,
                              color: colors.secondaryText,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () async {
                    await _flushCurrentZikirAsync();
                    if (!mounted) return;
                    await AddEditZikirSheet.show(
                      context,
                      zikir: currentZikir,
                      onSave: (comp) => ref
                          .read(zikirCrudProvider)
                          .updateZikir(currentZikir.id, comp),
                    );
                  },
                  borderRadius: BorderRadius.circular(21),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: headerPillBg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.edit_rounded,
                      size: 18,
                      color: colors.secondaryText,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSettingToggle({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
    required Color activeBg,
    double size = 36,
    double iconSize = 18,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(size * 0.5),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isActive ? activeBg : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: iconSize,
          color: isActive ? Colors.white : context.colors.secondaryTextAlt,
        ),
      ),
    );
  }
}
