import 'dart:async';
import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import '../../../../core/database/zikir_seed_data.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/providers/database_provider.dart';
import '../../../../core/services/sound_pool_service.dart';
import '../../../../core/services/screen_awake_service.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/utils/quran_word_highlighter.dart';
import '../../../gamification/providers/gamification_providers.dart';
import '../../../kuran/providers/kuran_providers.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../providers/zikir_providers.dart';
import '../widgets/circular_counter_painter.dart';
import '../widgets/add_edit_zikir_sheet.dart';
import '../widgets/zikir_share_card_widget.dart';
import '../widgets/zikir_share_preview_modal.dart';
import '../../../../core/services/cloud_sync_engine.dart';

class ZikirCounterScreen extends ConsumerStatefulWidget {
  const ZikirCounterScreen({super.key});

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
      if (ref.read(settingsProvider).isKeepScreenAwakeEnabled) {
        ScreenAwakeService.setKeepAwake(true);
      }
      if (mounted && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
        _desktopFocusNode.requestFocus();
      }
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
    Future.microtask(() {
      try {
        if (!mounted) return;
        final currentZikir = ref.read(currentZikirProvider);
        if (currentZikir != null) {
          ref.read(zikirCounterNotifierProvider(currentZikir.id).notifier).flushPending();
          CloudSyncEngine.instance.triggerDebouncedSync(ref, delay: const Duration(seconds: 1));
        }
      } catch (_) {}
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
      } catch (_) {}
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

  void _showSwitchZikirSheet() {
    final zikirListAsync = ref.watch(zikirListStreamProvider);
    final colors = context.colors;
    final isFocusMode = ref.read(isZikirFocusModeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark || isFocusMode;
    final currentZikirId = ref.read(selectedZikirIdProvider);
    final arabicFont = ref.read(arabicFontFamilyProvider);
    final isBoldArabic = ref.read(isBoldArabicProvider);

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.65,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1F1A17) : colors.bottomSheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            bottom: true,
            child: Column(
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
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      context.l10n.isTurkish ? 'Zikir Seçin' : 'Select Dhikr',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: colors.primaryText,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      color: colors.secondaryTextAlt,
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: zikirListAsync.when(
                    data: (zikirs) => ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      itemCount: zikirs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (ctx, idx) {
                        final z = zikirs[idx];
                        final isSelected = z.id == currentZikirId;
                        return Container(
                          decoration: BoxDecoration(
                            color: isSelected ? colors.accent.withValues(alpha: 0.12) : colors.cardBackground,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? colors.accent : colors.borderStroke,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            leading: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: isSelected ? colors.accent : colors.headerBackground,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '${idx + 1}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? Colors.white : colors.primaryText,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                            title: Text(
                              z.name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: colors.primaryText,
                                fontSize: 15,
                              ),
                            ),
                            subtitle: z.arabic != null && z.arabic!.isNotEmpty
                                ? Text(
                                    QuranWordHighlighter.formatArabicTextForFont(z.arabic!, arabicFont),
                                    textDirection: TextDirection.rtl,
                                    style: TextStyle(
                                      fontFamily: arabicFont,
                                      fontSize: 16,
                                      fontWeight: isBoldArabic ? FontWeight.bold : FontWeight.normal,
                                      color: colors.secondaryTextAlt,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                : null,
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                                  decoration: BoxDecoration(
                                    color: colors.headerBackground,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: colors.borderStroke.withValues(alpha: 0.6)),
                                  ),
                                  child: Text(
                                    _formatThousands(z.totalCount),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: colors.primaryText,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                if (z.currentCount > 0) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    '${z.currentCount}/${z.target}',
                                    style: TextStyle(fontSize: 10, color: colors.secondaryTextAlt),
                                  ),
                                ],
                              ],
                            ),
                            onTap: () {
                              ref.read(selectedZikirIdProvider.notifier).select(z.id);
                              Navigator.of(ctx).pop();
                            },
                          ),
                        );
                      },
                    ),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (_, __) => const Text('Yüklenemedi'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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

    // =========================================================================
    // HILAL / OLED / FOCUS MODE (Pure AMOLED Black, Full-Screen Tap Target)
    // =========================================================================
    final Widget counterContent;
    if (isFocusMode) {
      counterContent = PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) {
            ref.read(isZikirFocusModeProvider.notifier).state = false;
          }
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _onTapCounter(counterNotifier, currentZikir.soundEffect, quickSettings),
              child: Stack(
                children: [
                  // Top "Dünyaya Dön" Pill Button
                  Positioned(
                    top: 14,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Material(
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
                      ),
                    ),
                  ),

                  // Giant Counter Number in the Center of Screen
                  Center(
                    child: AnimatedBuilder(
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
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } else {
      final pageBg = colors.pageBackground;
      final headerPillBg = colors.headerBackground;
      final buttonInnerBg = colors.counterButtonColor;
      final arabicColor = colors.zikirArabicColor;
      final progressValue = quickSettings.isInfiniteMode ? 1.0 : counterState.progress;

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
              child: Column(
                children: [
            // ==========================================
            // 1. TOP ARABIC TEXT & HINT AREA
            // ==========================================
            Expanded(
              flex: 4,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (currentZikir.arabic != null && currentZikir.arabic!.isNotEmpty)
                        GestureDetector(
                          onTap: () => _showZikirDetails(
                            currentZikir.name,
                            currentZikir.arabic,
                            currentZikir.category,
                          ),
                          child: Text(
                            QuranWordHighlighter.formatArabicTextForFont(currentZikir.arabic!, arabicFont),
                            textDirection: TextDirection.rtl,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: arabicFont,
                              fontSize: 38,
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
                            Text(
                              l10n.isTurkish ? 'Açıklama için metne dokunun' : 'Tap text for details',
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.secondaryTextAlt,
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

            // ==========================================
            // 2. CIRCULAR COUNTER & TAP AREA
            // ==========================================
            Expanded(
              flex: 6,
              child: Center(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _onTapCounter(counterNotifier, currentZikir.soundEffect, quickSettings),
                  child: AnimatedBuilder(
                    animation: _scaleAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _scaleAnimation.value,
                        child: SizedBox(
                          width: 290,
                          height: 290,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Circular Progress Ring starting from bottom (6 o'clock)
                              CustomPaint(
                                size: const Size(290, 290),
                                painter: CircularCounterPainter(
                                  progress: progressValue,
                                  progressColor: colors.counterProgressColor,
                                  trackColor: Colors.transparent,
                                  strokeWidth: 9.0,
                                ),
                              ),

                              // Main Counter Clickable Circle
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
                                    // Bird Lottie right above centered number (Enlarged +35%: 74 -> 100)
                                    Positioned(
                                      top: 14,
                                      child: SizedBox(
                                        width: 100,
                                        height: 100,
                                        child: Lottie.asset(
                                          selectedBird.fileName,
                                          controller: _birdLottieController,
                                          errorBuilder: (context, error, stackTrace) {
                                            return Center(
                                              child: Text(
                                                selectedBird.badge,
                                                style: const TextStyle(fontSize: 48),
                                              ),
                                            );
                                          },
                                          onLoaded: (comp) {
                                            if (mounted) {
                                              _birdLottieController.duration = comp.duration;
                                              _birdLottieController.value = 0.5;
                                            }
                                          },
                                        ),
                                      ),
                                    ),

                                    // Counter text in the EXACT center of the circle button
                                    Center(
                                      child: Padding(
                                        padding: const EdgeInsets.only(top: 18),
                                        child: Text(
                                          '${counterState.currentCount}',
                                          style: TextStyle(
                                            fontSize: _getMainCounterFontSize(counterState.currentCount),
                                            fontWeight: FontWeight.bold,
                                            color: colors.counterValueColor,
                                            height: 1.0,
                                          ),
                                        ),
                                      ),
                                    ),

                                    // DOKUN label at the very bottom
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
                      );
                    },
                  ),
                ),
              ),
            ),

            // ==========================================
            // 3. TOOLBAR & QUICK SETTINGS AREA
            // ==========================================
            Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              margin: const EdgeInsets.only(bottom: 12),
              child: _isQuickSettingsOpen
                  ? // Quick Settings Mode (Auto-closing 7-button bar)
                  Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: headerPillBg,
                        borderRadius: BorderRadius.circular(23),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // 1. Sound Toggle
                          _buildSettingToggle(
                            icon: quickSettings.isSoundEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                            isActive: quickSettings.isSoundEnabled,
                            onTap: () {
                              _resetQuickSettingsTimer();
                              quickSettingsNotifier.toggleSound();
                            },
                            activeBg: colors.accent,
                          ),
                          // 2. Vibration Toggle
                          _buildSettingToggle(
                            icon: quickSettings.isVibrationEnabled ? Icons.vibration_rounded : Icons.smartphone_rounded,
                            isActive: quickSettings.isVibrationEnabled,
                            onTap: () {
                              _resetQuickSettingsTimer();
                              quickSettingsNotifier.toggleVibration();
                            },
                            activeBg: colors.accent,
                          ),
                          // 3. Infinite Mode Toggle
                          _buildSettingToggle(
                            icon: Icons.all_inclusive_rounded,
                            isActive: quickSettings.isInfiniteMode,
                            onTap: () async {
                              _resetQuickSettingsTimer();
                              final wasInfinite = quickSettings.isInfiniteMode;
                              await quickSettingsNotifier.toggleInfiniteMode();
                              if (wasInfinite) {
                                // Sonsuz moddan çıkarken çekilen zikir diske kaydedilsin ve sayaç sıfırlansın
                                await counterNotifier.onExitInfiniteMode();
                              }
                            },
                            activeBg: colors.accent,
                          ),
                          // 4. Hilal / OLED / Focus Mode
                          _buildSettingToggle(
                            icon: Icons.nightlight_round,
                            isActive: isFocusMode,
                            onTap: () {
                              _closeQuickSettings();
                              ref.read(isZikirFocusModeProvider.notifier).state = true;
                            },
                            activeBg: colors.accent,
                          ),
                          // 5. Share Selected Dhikr (Visual Card & Text)
                          _buildSettingToggle(
                            icon: Icons.share_rounded,
                            isActive: false,
                            onTap: () {
                              _resetQuickSettingsTimer();
                              final virtue = _getZikirVirtue(currentZikir.name, currentZikir.arabic);
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
                                initialTheme: ZikirShareThemeData.themeForGoalOrTask(
                                  category: currentZikir.category,
                                  goalType: 'zikir',
                                ),
                              );
                            },
                            activeBg: colors.accent,
                          ),
                          // 6. Reset Counter
                          _buildSettingToggle(
                            icon: Icons.refresh_rounded,
                            isActive: false,
                            onTap: () {
                              _resetQuickSettingsTimer();
                              counterNotifier.reset();
                            },
                            activeBg: colors.accent,
                          ),
                          // 7. Close Quick Settings
                          _buildSettingToggle(
                            icon: Icons.close_rounded,
                            isActive: false,
                            onTap: _closeQuickSettings,
                            activeBg: colors.accent,
                          ),
                        ],
                      ),
                    )
                  : // Standard Toolbar Mode
                  Row(
                      children: [
                        // Left Settings Toggle (42x42 round button)
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
                            child: Icon(Icons.tune_rounded, size: 20, color: colors.secondaryText),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Middle Zikir Selector Badge (Flexible to prevent right overflow on long zikir names)
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
                                    Icon(Icons.arrow_drop_down_rounded, size: 22, color: colors.secondaryText),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Right Edit Pencil Button (42x42 round button)
                        InkWell(
                          onTap: () {
                            AddEditZikirSheet.show(
                              context,
                              zikir: currentZikir,
                              onSave: (comp) async {
                                final db = ref.read(databaseProvider);
                                await (db.update(db.zikirs)..where((t) => t.id.equals(currentZikir.id))).write(comp);
                              },
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
                            child: Icon(Icons.edit_rounded, size: 18, color: colors.secondaryText),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    ),
    );
    }

      return KeyboardListener(
        focusNode: _desktopFocusNode,
        autofocus: true,
        onKeyEvent: (KeyEvent event) {
          if (event is KeyDownEvent) {
            final isSpace = event.logicalKey == LogicalKeyboardKey.space;
            final isEnter = event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.numpadEnter;
            final isArrow = event.logicalKey == LogicalKeyboardKey.arrowDown ||
                event.logicalKey == LogicalKeyboardKey.arrowUp;

            if ((isSpace && settings.desktopSpaceKeyEnabled) ||
                (isEnter && settings.desktopEnterKeyEnabled) ||
                (isArrow && settings.desktopArrowKeysEnabled)) {
              _onTapCounter(counterNotifier, currentZikir.soundEffect, quickSettings);
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

  Widget _buildSettingToggle({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
    required Color activeBg,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isActive ? activeBg : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 18,
          color: isActive ? Colors.white : context.colors.secondaryTextAlt,
        ),
      ),
    );
  }

  String _formatThousands(int n) {
    final s = n.toString();
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return s.replaceAllMapped(reg, (Match m) => '${m[1]}.');
  }
}
