import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/guided_flow_models.dart';

/// Akıcı fasıl öncesinde aktif kitabın sayfalarından üretilen 60 saniyelik 2 aşamalı ısınma modalı.
class LexicalWarmupSheet extends StatefulWidget {
  final Future<WarmupLexicalPack> Function() loadPack;
  final FasilDurationPreset preset;
  final VoidCallback onLaunchFasil;

  const LexicalWarmupSheet({
    super.key,
    required this.loadPack,
    required this.preset,
    required this.onLaunchFasil,
  });

  static Future<void> show(
    BuildContext context, {
    required Future<WarmupLexicalPack> Function() loadPack,
    required FasilDurationPreset preset,
    required VoidCallback onLaunchFasil,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => LexicalWarmupSheet(
        loadPack: loadPack,
        preset: preset,
        onLaunchFasil: onLaunchFasil,
      ),
    );
  }

  @override
  State<LexicalWarmupSheet> createState() => _LexicalWarmupSheetState();
}

class _LexicalWarmupSheetState extends State<LexicalWarmupSheet> {
  static const int _totalSeconds = 60;
  static const int _stageSplitSeconds = 30;

  WarmupLexicalPack? _pack;
  bool _isLoading = true;
  String? _loadError;
  int _remainingSeconds = _totalSeconds;
  bool _isPaused = false;
  bool _launched = false;
  int _pyramidRowIndex = 0;
  int _overdriveChunkIndex = 0;

  Timer? _countdownTimer;
  Timer? _stageOneTimer;
  Timer? _stageTwoChunkTimer;

  @override
  void initState() {
    super.initState();
    _fetchPack();
  }

  @override
  void dispose() {
    _cancelAllTimers();
    super.dispose();
  }

  void _cancelAllTimers() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _stageOneTimer?.cancel();
    _stageOneTimer = null;
    _stageTwoChunkTimer?.cancel();
    _stageTwoChunkTimer = null;
  }

  Future<void> _fetchPack() async {
    _cancelAllTimers();
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final pack = await widget.loadPack();
      if (!mounted) return;
      setState(() {
        _pack = pack;
        _isLoading = false;
        _remainingSeconds = _totalSeconds;
        _pyramidRowIndex = 0;
        _overdriveChunkIndex = 0;
      });
      _startTimers();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = 'Kitaba özel ısınma paketi hazırlanamadı: $error';
      });
    }
  }

  void _startTimers() {
    _cancelAllTimers();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _isPaused || _launched) return;
      if (_remainingSeconds <= 1) {
        _completeAndLaunch();
        return;
      }
      final nextSec = _remainingSeconds - 1;
      final enteringStageTwo =
          _remainingSeconds > _stageSplitSeconds && nextSec <= _stageSplitSeconds;
      setState(() => _remainingSeconds = nextSec);
      if (enteringStageTwo) {
        _stageOneTimer?.cancel();
        _stageOneTimer = null;
        _scheduleStageTwoTick();
      }
    });

    if (_remainingSeconds > _stageSplitSeconds) {
      _stageOneTimer = Timer.periodic(const Duration(milliseconds: 2400), (_) {
        final pack = _pack;
        if (!mounted || _isPaused || pack == null || pack.pyramidRows.isEmpty) {
          return;
        }
        if (_remainingSeconds <= _stageSplitSeconds) return;
        setState(() {
          _pyramidRowIndex = (_pyramidRowIndex + 1) % pack.pyramidRows.length;
        });
      });
    } else {
      _scheduleStageTwoTick();
    }
  }

  double _currentOverdriveMultiplier() {
    final elapsedStageTwo = (_stageSplitSeconds - _remainingSeconds).clamp(0, 30);
    final ratio = elapsedStageTwo / 30.0;
    if (ratio < 0.34) return 1.0;
    if (ratio < 0.74) return 1.45;
    return 1.15;
  }

  void _scheduleStageTwoTick() {
    _stageTwoChunkTimer?.cancel();
    final pack = _pack;
    if (!mounted ||
        _isPaused ||
        _launched ||
        pack == null ||
        pack.overdriveChunks.isEmpty) {
      return;
    }

    final multiplier = _currentOverdriveMultiplier();
    final effectiveWpm =
        (pack.suggestedWpm * pack.densityTier.speedMultiplier * multiplier)
            .round()
            .clamp(120, 950);
    final chunk =
        pack.overdriveChunks[_overdriveChunkIndex % pack.overdriveChunks.length];
    final wordCount = chunk
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .length
        .clamp(1, 5);
    final delayMs = ((60000.0 / effectiveWpm) * wordCount).round().clamp(130, 1400);

    _stageTwoChunkTimer = Timer(Duration(milliseconds: delayMs), () {
      if (!mounted || _isPaused || _launched) return;
      setState(() {
        _overdriveChunkIndex =
            (_overdriveChunkIndex + 1) % pack.overdriveChunks.length;
      });
      _scheduleStageTwoTick();
    });
  }

  void _togglePause() {
    setState(() => _isPaused = !_isPaused);
    if (_isPaused) {
      _stageTwoChunkTimer?.cancel();
      _stageTwoChunkTimer = null;
    } else if (_remainingSeconds <= _stageSplitSeconds) {
      _scheduleStageTwoTick();
    }
  }

  void _completeAndLaunch() {
    if (_launched || !mounted) return;
    _launched = true;
    _cancelAllTimers();
    Navigator.of(context).pop();
    widget.onLaunchFasil();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isStageOne = _remainingSeconds > _stageSplitSeconds;
    final progress = (_totalSeconds - _remainingSeconds) / _totalSeconds;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
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
              const SizedBox(height: 14),
              _WarmupTopBar(
                preset: widget.preset,
                remainingSeconds: _remainingSeconds,
                progress: progress,
                isPaused: _isPaused,
                canPause: !_isLoading && _loadError == null,
                onTogglePause: _togglePause,
              ),
              const SizedBox(height: 14),
              if (_isLoading)
                const _WarmupLoadingState()
              else if (_loadError != null)
                _WarmupErrorState(
                  message: _loadError!,
                  onRetry: _fetchPack,
                )
              else if (_pack != null) ...[
                _BookContextCard(pack: _pack!),
                const SizedBox(height: 14),
                if (isStageOne)
                  _StageOnePeripheralView(
                    pack: _pack!,
                    activeRowIndex: _pyramidRowIndex,
                    stageRemainingSeconds: _remainingSeconds - _stageSplitSeconds,
                  )
                else
                  _StageTwoOverdriveView(
                    pack: _pack!,
                    activeChunkIndex: _overdriveChunkIndex,
                    multiplier: _currentOverdriveMultiplier(),
                    stageRemainingSeconds: _remainingSeconds,
                  ),
              ],
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: _completeAndLaunch,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(
                    color: AppColors.amberGold.withValues(alpha: 0.7),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.bolt_rounded, size: 19),
                label: Text(
                  'Atla ve Doğrudan Fasla Geç',
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WarmupTopBar extends StatelessWidget {
  final FasilDurationPreset preset;
  final int remainingSeconds;
  final double progress;
  final bool isPaused;
  final bool canPause;
  final VoidCallback onTogglePause;

  const _WarmupTopBar({
    required this.preset,
    required this.remainingSeconds,
    required this.progress,
    required this.isPaused,
    required this.canPause,
    required this.onTogglePause,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kitaba Özel 60 sn Isınma',
                    style: GoogleFonts.literata(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Hedef: ${preset.title}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            if (canPause)
              IconButton(
                onPressed: onTogglePause,
                tooltip: isPaused ? 'Devam Et' : 'Duraklat',
                icon: Icon(
                  isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                  color: theme.colorScheme.primary,
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.amberGold.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.amberGold.withValues(alpha: 0.5),
                ),
              ),
              child: Text(
                '${remainingSeconds}s',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: theme.colorScheme.outline.withValues(alpha: 0.25),
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.amberGold),
          ),
        ),
      ],
    );
  }
}

class _WarmupLoadingState extends StatelessWidget {
  const _WarmupLoadingState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        children: [
          const CircularProgressIndicator(color: AppColors.amberGold),
          const SizedBox(height: 14),
          Text(
            'Yaklaşan sayfaların kavram ağı ve ritim şeridi hazırlanıyor...',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
            ),
          ),
        ],
      ),
    );
  }
}

class _WarmupErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _WarmupErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.error.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.tonal(
            onPressed: onRetry,
            child: const Text('Tekrar Dene'),
          ),
        ],
      ),
    );
  }
}

class _BookContextCard extends StatelessWidget {
  final WarmupLexicalPack pack;

  const _BookContextCard({required this.pack});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        children: [
          Icon(
            pack.isFromUserBook
                ? Icons.auto_stories_rounded
                : Icons.menu_book_rounded,
            size: 18,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pack.sourceTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.literata(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  '${pack.sourceAuthor} • Sayfa ${pack.targetPage}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.amberGold.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              pack.densityTier.label,
              style: GoogleFonts.inter(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StageOnePeripheralView extends StatelessWidget {
  final WarmupLexicalPack pack;
  final int activeRowIndex;
  final int stageRemainingSeconds;

  const _StageOnePeripheralView({
    required this.pack,
    required this.activeRowIndex,
    required this.stageRemainingSeconds,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = pack.pyramidRows;
    final safeRow =
        rows.isEmpty ? null : rows[activeRowIndex % rows.length];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PhaseHeaderBadge(
          phaseText: 'Aşama 1/2 • Kavramsal Ön-Okuma & Çevresel Kanatlar',
          secondsText: '${stageRemainingSeconds}s',
        ),
        const SizedBox(height: 10),
        if (pack.keyConcepts.isNotEmpty) ...[
          Text(
            'Yaklaşan Anahtar Kavramlar',
            style: GoogleFonts.inter(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: pack.keyConcepts.map((concept) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.amberGold.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.amberGold.withValues(alpha: 0.45),
                  ),
                ),
                child: Text(
                  concept,
                  style: GoogleFonts.literata(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
        ],
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.4),
            ),
          ),
          child: Column(
            children: [
              Text(
                'Gözünüzü merkezdeki noktaya sabitleyip iki kanadı aynı anda görün',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
              const SizedBox(height: 18),
              if (safeRow != null) _PyramidWingRow(row: safeRow),
              const SizedBox(height: 10),
              if (rows.length > 1)
                Text(
                  'Kanat ${(activeRowIndex % rows.length) + 1} / ${rows.length}',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PyramidWingRow extends StatelessWidget {
  final PyramidSpanRow row;

  const _PyramidWingRow({required this.row});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final halfGap = (row.horizontalGap * 0.42).clamp(10.0, 48.0);
    return Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              row.leftWord,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.literata(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ),
        SizedBox(width: halfGap),
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.terracotta.withValues(alpha: 0.16),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.terracotta, width: 1.4),
          ),
          child: Text(
            row.centerAnchor,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.terracotta,
            ),
          ),
        ),
        SizedBox(width: halfGap),
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              row.rightWord,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.literata(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StageTwoOverdriveView extends StatelessWidget {
  final WarmupLexicalPack pack;
  final int activeChunkIndex;
  final double multiplier;
  final int stageRemainingSeconds;

  const _StageTwoOverdriveView({
    required this.pack,
    required this.activeChunkIndex,
    required this.multiplier,
    required this.stageRemainingSeconds,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chunks = pack.overdriveChunks;
    final activeChunk = chunks.isEmpty
        ? pack.sourceTitle
        : chunks[activeChunkIndex % chunks.length];
    final activeWpm =
        (pack.suggestedWpm * pack.densityTier.speedMultiplier * multiplier)
            .round()
            .clamp(120, 950);

    final speedLabel = multiplier >= 1.4
        ? 'Aşırı Hız • 1.45x'
        : (multiplier >= 1.1
            ? 'Konfor Sabitleme • 1.15x'
            : 'Baz Kalibrasyon • 1.0x');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PhaseHeaderBadge(
          phaseText: 'Aşama 2/2 • Akış Kalibrasyonu (1.0x → 1.45x → 1.15x)',
          secondsText: '${stageRemainingSeconds}s',
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
          decoration: BoxDecoration(
            color: AppColors.amberGold.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.amberGold.withValues(alpha: 0.55),
              width: 1.4,
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.terracotta.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      speedLabel,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.terracotta,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$activeWpm WPM',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                activeChunk,
                textAlign: TextAlign.center,
                style: GoogleFonts.literata(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  height: 1.35,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'İçsesi susturun; gözünüzü merkezde tutup anlam öbeklerini yakalayın.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PhaseHeaderBadge extends StatelessWidget {
  final String phaseText;
  final String secondsText;

  const _PhaseHeaderBadge({
    required this.phaseText,
    required this.secondsText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            phaseText,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        Text(
          secondsText,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.amberGold,
          ),
        ),
      ],
    );
  }
}
