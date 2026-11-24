import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/speed_reading_curriculum_corpus.dart';
import '../../domain/speed_reading_models.dart';
import '../../engine/speed_reading_engine.dart';
import '../providers/speed_reading_provider.dart';

Future<void> _openSheet(BuildContext context, Widget child) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => child,
    );

int _wordCount(String text) => text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length.clamp(1, 5);
TextStyle _serif(double s, [FontWeight w = FontWeight.w700, Color? c, double? h]) => GoogleFonts.literata(fontSize: s, fontWeight: w, color: c, height: h);
TextStyle _sans(double s, [FontWeight w = FontWeight.w600, Color? c]) => GoogleFonts.inter(fontSize: s, fontWeight: w, color: c);
TextStyle _mono(double s, [FontWeight w = FontWeight.w800, Color? c]) => GoogleFonts.jetBrainsMono(fontSize: s, fontWeight: w, color: c);

/// Emekli edilen dev egzersiz sayfasının yerine geçen yalın Göz Atölyesi & İkincil RSVP aracı.
class EyeWorkshopSheet extends ConsumerStatefulWidget {
  final SpeedReadingExerciseType initialExercise;
  const EyeWorkshopSheet({super.key, this.initialExercise = SpeedReadingExerciseType.peripheralPyramid});

  static const _modes = [
    SpeedReadingExerciseType.peripheralPyramid,
    SpeedReadingExerciseType.tachistoscope,
    SpeedReadingExerciseType.schulteGrid,
    SpeedReadingExerciseType.wpmComprehensionTest,
  ];

  static Future<void> show(BuildContext context, {SpeedReadingExerciseType initialExercise = SpeedReadingExerciseType.peripheralPyramid}) =>
      _openSheet(context, EyeWorkshopSheet(initialExercise: initialExercise));

  static Future<void> showSecondaryRsvp(BuildContext context, {required String text, required String title, int initialWpm = 260}) =>
      _openSheet(context, _SecondaryRsvpSheet(text: text, title: title, initialWpm: initialWpm));

  @override
  ConsumerState<EyeWorkshopSheet> createState() => _EyeWorkshopSheetState();
}

class _EyeWorkshopSheetState extends ConsumerState<EyeWorkshopSheet> {
  static const int _tachTotal = 6;
  Timer? _timer;
  late SpeedReadingExerciseType _mode;
  String? _savedBanner;
  int _passageIdx = 0;

  int _pyrIntervalMs = 950, _pyrRowIdx = 0;
  bool _pyrRunning = false;
  late List<PyramidSpanRow> _pyrRows;
  DateTime? _pyrStart;

  int _tachSpan = 1, _tachMs = 150, _tachBestMs = 150, _tachRound = 0, _tachCorrect = 0;
  bool _tachFlashing = false, _tachAwaiting = false;
  TachistoscopeRound? _tachData;
  DateTime? _tachStart;

  int _schulteDim = 4, _schulteIdx = 0, _schulteMiss = 0, _schulteTenths = 0;
  bool _schulteLetters = false, _schulteRunning = false;
  late List<String> _schulteTargets, _schulteGrid;

  int _testSeconds = 0;
  bool _testInQuiz = false;
  final Map<int, int> _testAnswers = {};
  ({int raw, int eff, int comp})? _testResult;

  SpeedReadingPassage get _passage => SpeedReadingCurriculumCorpus.passages[_passageIdx % SpeedReadingCurriculumCorpus.passages.length];

  @override
  void initState() {
    super.initState();
    _mode = EyeWorkshopSheet._modes.contains(widget.initialExercise) ? widget.initialExercise : SpeedReadingExerciseType.peripheralPyramid;
    _initPyramid();
    _prepareTach(flashNow: false);
    _initSchulte();
    if (_mode == SpeedReadingExerciseType.wpmComprehensionTest) _startTestTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _record(SpeedReadingExerciseType type, int wpm, int comp, double sec, String summary, {double? schulte5x5, int? tachMs}) async {
    await ref.read(speedReadingProvider.notifier).recordDrillCompletion(
          type: type,
          achievedWpm: wpm,
          comprehensionPercent: comp,
          durationSeconds: sec,
          summaryLabel: summary,
          schulte5x5Seconds: schulte5x5,
          tachistoscopeMs: tachMs,
        );
    if (mounted) setState(() => _savedBanner = '${type.shortTitle}: $summary (+${type.xpReward} XP)');
  }

  void _selectMode(SpeedReadingExerciseType next) {
    _timer?.cancel();
    setState(() { _mode = next; _pyrRunning = false; _tachFlashing = false; _schulteRunning = false; });
    if (next == SpeedReadingExerciseType.wpmComprehensionTest && !_testInQuiz && _testResult == null) _startTestTimer();
  }

  void _initPyramid() {
    _pyrRows = SpeedReadingEngine.generatePyramidSpanRows(_passage.content, maxRows: 10);
    _pyrRowIdx = 0;
  }

  void _togglePyramid() {
    if (_pyrRunning) { _timer?.cancel(); setState(() => _pyrRunning = false); return; }
    _pyrStart ??= DateTime.now();
    setState(() => _pyrRunning = true);
    _timer?.cancel();
    _timer = Timer.periodic(Duration(milliseconds: _pyrIntervalMs), (_) {
      if (!mounted) return;
      if (_pyrRowIdx + 1 >= _pyrRows.length) { _finishPyramid(); } else { setState(() => _pyrRowIdx++); }
    });
  }

  Future<void> _finishPyramid() async {
    _timer?.cancel();
    setState(() => _pyrRunning = false);
    final sec = _pyrStart == null ? 12.0 : DateTime.now().difference(_pyrStart!).inMilliseconds.clamp(3000, 600000) / 1000.0;
    await _record(SpeedReadingExerciseType.peripheralPyramid, ((120000 / _pyrIntervalMs) * 2).round().clamp(160, 680), 100, sec, '${_pyrRows.length} satır kanat odağı');
    if (mounted) setState(() { _pyrStart = null; _pyrRowIdx = 0; });
  }

  void _prepareTach({bool flashNow = true}) {
    _timer?.cancel();
    final list = SpeedReadingCurriculumCorpus.passages;
    final data = SpeedReadingEngine.generateTachistoscopeRound(wordSpan: _tachSpan, sourceText: list[_tachRound % list.length].content);
    setState(() { _tachData = data; _tachAwaiting = false; _tachFlashing = flashNow; });
    if (flashNow) {
      _tachStart ??= DateTime.now();
      _timer = Timer(Duration(milliseconds: _tachMs), () { if (mounted) setState(() { _tachFlashing = false; _tachAwaiting = true; }); });
    }
  }

  Future<void> _pickTach(int idx) async {
    final round = _tachData;
    if (!_tachAwaiting || round == null) return;
    final ok = idx == round.correctOptionIndex;
    final nextCorrect = _tachCorrect + (ok ? 1 : 0);
    final nextMs = (ok ? _tachMs - 15 : _tachMs + 15).clamp(45, 220);
    final nextBest = ok && _tachMs < _tachBestMs ? _tachMs : _tachBestMs;
    if (_tachRound + 1 >= _tachTotal) {
      final sec = _tachStart == null ? 15.0 : DateTime.now().difference(_tachStart!).inMilliseconds.clamp(3000, 600000) / 1000.0;
      await _record(SpeedReadingExerciseType.tachistoscope, 240 + nextCorrect * 35, ((nextCorrect / _tachTotal) * 100).round(), sec, '$nextCorrect/$_tachTotal • En hızlı ${nextBest}ms', tachMs: nextBest);
      if (!mounted) return;
      setState(() { _tachRound = 0; _tachCorrect = 0; _tachMs = 150; _tachBestMs = 150; _tachStart = null; });
      _prepareTach(flashNow: false);
      return;
    }
    setState(() { _tachCorrect = nextCorrect; _tachMs = nextMs; _tachBestMs = nextBest; _tachRound++; });
    _prepareTach(flashNow: true);
  }

  void _initSchulte() {
    final data = SpeedReadingEngine.generateSchulteGrid(dimension: _schulteDim, useLetters: _schulteLetters);
    _schulteTargets = data.orderedTargets;
    _schulteGrid = data.shuffledGrid;
    _schulteIdx = 0;
    _schulteMiss = 0;
    _schulteTenths = 0;
    _schulteRunning = false;
  }

  Future<void> _tapSchulte(String val) async {
    if (!_schulteRunning) {
      _schulteRunning = true;
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(milliseconds: 100), (_) { if (mounted) setState(() => _schulteTenths++); });
    }
    if (val != _schulteTargets[_schulteIdx]) { setState(() => _schulteMiss++); return; }
    if (_schulteIdx + 1 < _schulteTargets.length) { setState(() => _schulteIdx++); return; }
    _timer?.cancel();
    final sec = (_schulteTenths / 10.0).clamp(2.0, 600.0);
    final total = _schulteTargets.length;
    await _record(
      SpeedReadingExerciseType.schulteGrid,
      (200 + (total * 160 / sec)).round().clamp(160, 720),
      ((total / (total + _schulteMiss)) * 100).round().clamp(40, 100),
      sec,
      '${_schulteDim}x$_schulteDim • ${sec.toStringAsFixed(1)}s',
      schulte5x5: (_schulteDim == 5 && !_schulteLetters) ? sec : null,
    );
    if (mounted) setState(_initSchulte);
  }

  void _startTestTimer() {
    _timer?.cancel();
    _testSeconds = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) { if (mounted && !_testInQuiz && _testResult == null) setState(() => _testSeconds++); });
  }

  void _nextTestPassage() {
    setState(() { _passageIdx++; _testInQuiz = false; _testAnswers.clear(); _testResult = null; });
    _startTestTimer();
  }

  Future<void> _submitTest() async {
    final qs = _passage.questions;
    int correct = 0;
    for (int i = 0; i < qs.length; i++) { if (_testAnswers[i] == qs[i].correctIndex) correct++; }
    final comp = qs.isEmpty ? 100 : ((correct / qs.length) * 100).round();
    final m = SpeedReadingEngine.calculateWpmMetrics(wordCount: _passage.wordCount, elapsedSeconds: _testSeconds.toDouble(), comprehensionPercent: comp);
    await _record(SpeedReadingExerciseType.wpmComprehensionTest, m.rawWpm, comp, _testSeconds.clamp(1, 3600).toDouble(), '${m.effectiveWpm} E-WPM • %$comp Anlama');
    if (mounted) setState(() => _testResult = (raw: m.rawWpm, eff: m.effectiveWpm, comp: comp));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.90),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: Container(width: 42, height: 4, decoration: BoxDecoration(color: theme.colorScheme.outline.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Göz Atölyesi', style: _serif(20, FontWeight.w800)),
                  Text(_mode.subtitle, style: _sans(11.5, FontWeight.w500, theme.colorScheme.onSurface.withValues(alpha: 0.68))),
                ])),
                IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close_rounded)),
              ]),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: EyeWorkshopSheet._modes.map((ex) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(label: Text(ex.shortTitle), selected: ex == _mode, onSelected: (_) => _selectMode(ex)),
                )).toList()),
              ),
              if (_savedBanner != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: AppColors.amberGold.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.amberGold.withValues(alpha: 0.5))),
                    child: Text('Kaydedildi: $_savedBanner', style: _sans(11.5, FontWeight.w700)),
                  ),
                ),
              const SizedBox(height: 14),
              switch (_mode) {
                SpeedReadingExerciseType.peripheralPyramid => _PyramidDrillView(_pyrRows[_pyrRowIdx % _pyrRows.length], _pyrRowIdx, _pyrRows.length, _pyrIntervalMs, _pyrRunning, (ms) => setState(() => _pyrIntervalMs = ms), _togglePyramid, () { _timer?.cancel(); setState(() { _pyrRunning = false; _passageIdx++; _initPyramid(); }); }),
                SpeedReadingExerciseType.tachistoscope => _TachistoscopeDrillView(_tachSpan, _tachRound + 1, _tachTotal, _tachMs, _tachFlashing, _tachAwaiting, _tachData, (s) { setState(() => _tachSpan = s); _prepareTach(flashNow: false); }, () => _prepareTach(flashNow: true), _pickTach),
                SpeedReadingExerciseType.schulteGrid => _SchulteDrillView(_schulteDim, _schulteLetters, _schulteGrid, _schulteTargets, _schulteIdx, _schulteTenths, (d) { _timer?.cancel(); setState(() { _schulteDim = d; _initSchulte(); }); }, () { _timer?.cancel(); setState(() { _schulteLetters = !_schulteLetters; _initSchulte(); }); }, _tapSchulte),
                _ => _CalibrationTestView(_passage, _testSeconds, _testInQuiz, _testAnswers, _testResult, () { _timer?.cancel(); setState(() => _testInQuiz = true); }, _nextTestPassage, (q, o) => setState(() => _testAnswers[q] = o), _submitTest),
              },
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkshopBox extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double? height;
  final bool highlight;
  const _WorkshopBox({required this.child, this.padding = const EdgeInsets.all(14), this.height, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: height,
      padding: padding,
      alignment: height != null ? Alignment.center : null,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: highlight ? AppColors.amberGold : theme.colorScheme.outline.withValues(alpha: 0.45), width: highlight ? 1.7 : 1.0),
      ),
      child: child,
    );
  }
}

class _PyramidDrillView extends StatelessWidget {
  final PyramidSpanRow row;
  final int rowIndex, totalRows, intervalMs;
  final bool isRunning;
  final ValueChanged<int> onChangeInterval;
  final VoidCallback onToggleRun, onNextText;
  const _PyramidDrillView(this.row, this.rowIndex, this.totalRows, this.intervalMs, this.isRunning, this.onChangeInterval, this.onToggleRun, this.onNextText);

  @override
  Widget build(BuildContext context) {
    final halfGap = (row.horizontalGap * 0.42).clamp(10.0, 46.0);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(spacing: 8, children: [1200, 950, 650].map((ms) => ChoiceChip(label: Text(ms == 1200 ? 'Rahat' : (ms == 950 ? 'Dengeli' : 'Hızlı')), selected: intervalMs == ms, onSelected: isRunning ? null : (_) => onChangeInterval(ms))).toList()),
      const SizedBox(height: 12),
      _WorkshopBox(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 26),
        child: Column(children: [
          Text('Satır ${rowIndex + 1} / $totalRows • Merkez noktaya odaklan', style: _sans(11.5, FontWeight.w500)),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(child: Text(row.leftWord, textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis, style: _serif(18))),
            SizedBox(width: halfGap),
            Container(width: 28, height: 28, alignment: Alignment.center, decoration: BoxDecoration(color: AppColors.terracotta.withValues(alpha: 0.16), shape: BoxShape.circle, border: Border.all(color: AppColors.terracotta)), child: Text(row.centerAnchor, style: _mono(11.5, FontWeight.w800, AppColors.terracotta))),
            SizedBox(width: halfGap),
            Expanded(child: Text(row.rightWord, textAlign: TextAlign.left, maxLines: 1, overflow: TextOverflow.ellipsis, style: _serif(18))),
          ]),
        ]),
      ),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: FilledButton.icon(onPressed: onToggleRun, icon: Icon(isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded), label: Text(isRunning ? 'Duraklat' : 'Akışı Başlat'))),
        const SizedBox(width: 10),
        OutlinedButton(onPressed: onNextText, child: const Text('Yeni Metin')),
      ]),
    ]);
  }
}

class _TachistoscopeDrillView extends StatelessWidget {
  final int wordSpan, roundNumber, totalRounds, flashMs;
  final bool isFlashing, isAwaitingAnswer;
  final TachistoscopeRound? roundData;
  final ValueChanged<int> onChangeSpan, onPickOption;
  final VoidCallback onStartFlash;
  const _TachistoscopeDrillView(this.wordSpan, this.roundNumber, this.totalRounds, this.flashMs, this.isFlashing, this.isAwaitingAnswer, this.roundData, this.onChangeSpan, this.onStartFlash, this.onPickOption);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Wrap(spacing: 6, children: [1, 2, 3].map((s) => ChoiceChip(label: Text('$s Kelime'), selected: wordSpan == s, onSelected: (_) => onChangeSpan(s))).toList()),
        Text('Tur $roundNumber/$totalRounds • ${flashMs}ms', style: _mono(11.5, FontWeight.w700, theme.colorScheme.primary)),
      ]),
      const SizedBox(height: 12),
      _WorkshopBox(
        height: 108,
        highlight: isFlashing,
        child: Text(
          isFlashing ? (roundData?.targetText ?? '') : (isAwaitingAnswer ? 'Gördüğün öbeği aşağıdan seç' : 'Hazırsan flaşı başlat'),
          textAlign: TextAlign.center,
          style: _serif(isFlashing ? 22 : 13.5, isFlashing ? FontWeight.w800 : FontWeight.w600),
        ),
      ),
      const SizedBox(height: 12),
      if (isAwaitingAnswer && roundData != null)
        ...List.generate(roundData!.options.length, (i) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: OutlinedButton(onPressed: () => onPickOption(i), child: Text(roundData!.options[i], style: _serif(15, FontWeight.w600))),
        ))
      else if (!isFlashing)
        FilledButton.icon(onPressed: onStartFlash, icon: const Icon(Icons.flash_on_rounded), label: const Text('Flaş Göster')),
    ]);
  }
}

class _SchulteDrillView extends StatelessWidget {
  final int dimension, nextIndex, elapsedTenths;
  final bool useLetters;
  final List<String> grid, targets;
  final ValueChanged<int> onSetDim;
  final VoidCallback onToggleLetters;
  final ValueChanged<String> onTapCell;
  const _SchulteDrillView(this.dimension, this.useLetters, this.grid, this.targets, this.nextIndex, this.elapsedTenths, this.onSetDim, this.onToggleLetters, this.onTapCell);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final centerIdx = grid.length ~/ 2;
    final target = nextIndex < targets.length ? targets[nextIndex] : '-';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        ChoiceChip(label: const Text('4x4'), selected: dimension == 4, onSelected: (_) => onSetDim(4)),
        const SizedBox(width: 6),
        ChoiceChip(label: const Text('5x5'), selected: dimension == 5, onSelected: (_) => onSetDim(5)),
        const SizedBox(width: 6),
        ChoiceChip(label: Text(useLetters ? 'Harf' : 'Sayı'), selected: useLetters, onSelected: (_) => onToggleLetters()),
        const Spacer(),
        Text('Hedef: $target • ${(elapsedTenths / 10).toStringAsFixed(1)}s', style: _mono(11.5, FontWeight.w800, theme.colorScheme.primary)),
      ]),
      const SizedBox(height: 12),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: dimension, crossAxisSpacing: 6, mainAxisSpacing: 6),
        itemCount: grid.length,
        itemBuilder: (_, idx) {
          final label = grid[idx];
          final found = targets.indexOf(label) < nextIndex;
          final center = idx == centerIdx;
          return InkWell(
            onTap: found ? null : () => onTapCell(label),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: found ? AppColors.amberGold.withValues(alpha: 0.18) : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: center ? AppColors.terracotta : theme.colorScheme.outline.withValues(alpha: 0.45), width: center ? 1.6 : 1.0),
              ),
              child: Text(label, style: _mono(dimension == 5 ? 14 : 16, FontWeight.w800, found ? theme.colorScheme.onSurface.withValues(alpha: 0.35) : theme.colorScheme.onSurface)),
            ),
          );
        },
      ),
    ]);
  }
}

class _CalibrationTestView extends StatelessWidget {
  final SpeedReadingPassage passage;
  final int seconds;
  final bool inQuiz;
  final Map<int, int> answers;
  final ({int raw, int eff, int comp})? result;
  final VoidCallback onFinishReading, onSwitchPassage, onSubmit;
  final void Function(int questionIndex, int optionIndex) onSelectAnswer;
  const _CalibrationTestView(this.passage, this.seconds, this.inQuiz, this.answers, this.result, this.onFinishReading, this.onSwitchPassage, this.onSelectAnswer, this.onSubmit);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (result != null) {
      return _WorkshopBox(
        highlight: true,
        child: Column(children: [
          Text('Kalibrasyon Tamamlandı', style: _serif(17, FontWeight.w800)),
          const SizedBox(height: 8),
          Text('${result!.eff} E-WPM • Ham: ${result!.raw} WPM • Anlama: %${result!.comp}', style: _mono(12.5, FontWeight.w700, theme.colorScheme.primary)),
          const SizedBox(height: 12),
          FilledButton(onPressed: onSwitchPassage, child: const Text('Yeni Metinle Tekrar Ölç')),
        ]),
      );
    }
    if (inQuiz) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ...List.generate(passage.questions.length, (qIdx) {
          final q = passage.questions[qIdx];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${qIdx + 1}. ${q.question}', style: _sans(12.5, FontWeight.w700)),
              const SizedBox(height: 6),
              ...List.generate(q.options.length, (oIdx) {
                final sel = answers[qIdx] == oIdx;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: InkWell(
                    onTap: () => onSelectAnswer(qIdx, oIdx),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(color: sel ? theme.colorScheme.primary.withValues(alpha: 0.14) : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(10), border: Border.all(color: sel ? AppColors.amberGold : theme.colorScheme.outline.withValues(alpha: 0.4))),
                      child: Text(q.options[oIdx], style: _sans(12, FontWeight.w500)),
                    ),
                  ),
                );
              }),
            ]),
          );
        }),
        FilledButton(onPressed: answers.length == passage.questions.length ? onSubmit : null, child: const Text('Sınavı Tamamla & E-WPM Hesapla')),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: Text('${passage.title} (${passage.wordCount} kelime)', style: _serif(15, FontWeight.w800))),
        Text('${seconds}s', style: _mono(13, FontWeight.w800, AppColors.terracotta)),
      ]),
      const SizedBox(height: 8),
      _WorkshopBox(child: Text(passage.content, style: _serif(15.5, FontWeight.w500, null, 1.65))),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: FilledButton(onPressed: onFinishReading, child: const Text('Okumayı Bitirdim'))),
        const SizedBox(width: 8),
        OutlinedButton(onPressed: onSwitchPassage, child: const Text('Değiştir')),
      ]),
    ]);
  }
}

class _SecondaryRsvpSheet extends StatefulWidget {
  final String text, title;
  final int initialWpm;
  const _SecondaryRsvpSheet({required this.text, required this.title, required this.initialWpm});

  @override
  State<_SecondaryRsvpSheet> createState() => _SecondaryRsvpSheetState();
}

class _SecondaryRsvpSheetState extends State<_SecondaryRsvpSheet> {
  Timer? _timer;
  late int _wpm;
  int _chunkSize = 1, _idx = 0;
  bool _playing = false;
  late List<String> _chunks;

  @override
  void initState() {
    super.initState();
    _wpm = widget.initialWpm.clamp(120, 900);
    _chunks = SpeedReadingEngine.tokenizeIntoChunks(widget.text, chunkSize: _chunkSize);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _setChunkSize(int size) {
    _timer?.cancel();
    setState(() { _chunkSize = size; _playing = false; _idx = 0; _chunks = SpeedReadingEngine.tokenizeIntoChunks(widget.text, chunkSize: size); });
  }

  void _togglePlay() {
    if (_chunks.isEmpty) return;
    if (_playing) { _timer?.cancel(); setState(() => _playing = false); return; }
    if (_idx >= _chunks.length - 1) _idx = 0;
    setState(() => _playing = true);
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    if (!mounted || !_playing || _chunks.isEmpty) return;
    final chunk = _chunks[_idx];
    final ms = SpeedReadingEngine.calculateChunkDelayMs(chunk: chunk, targetWpm: _wpm, wordsInChunk: _wordCount(chunk));
    _timer = Timer(Duration(milliseconds: ms), () {
      if (!mounted || !_playing) return;
      if (_idx + 1 >= _chunks.length) { setState(() => _playing = false); } else { setState(() => _idx++); _schedule(); }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final orp = SpeedReadingEngine.splitForOrp(_chunks.isEmpty ? '' : _chunks[_idx % _chunks.length]);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _serif(16, FontWeight.w800))),
            ChoiceChip(label: const Text('1K'), selected: _chunkSize == 1, onSelected: (_) => _setChunkSize(1)),
            const SizedBox(width: 6),
            ChoiceChip(label: const Text('2K'), selected: _chunkSize == 2, onSelected: (_) => _setChunkSize(2)),
          ]),
          const SizedBox(height: 14),
          _WorkshopBox(
            height: 112,
            highlight: true,
            child: _chunks.isEmpty
                ? const Text('Taranacak metin bulunamadı.')
                : Row(children: [
                    Expanded(child: Text(orp.leftPart, textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis, style: _serif(26))),
                    Text(orp.pivotChar, style: _serif(28, FontWeight.w900, AppColors.terracotta)),
                    Expanded(child: Text(orp.rightPart, textAlign: TextAlign.left, maxLines: 1, overflow: TextOverflow.ellipsis, style: _serif(26))),
                  ]),
          ),
          const SizedBox(height: 12),
          Row(children: [
            IconButton(onPressed: () => setState(() => _wpm = (_wpm - 20).clamp(120, 900)), icon: const Icon(Icons.remove_circle_outline)),
            Text('$_wpm WPM', style: _mono(14, FontWeight.w800, theme.colorScheme.primary)),
            IconButton(onPressed: () => setState(() => _wpm = (_wpm + 20).clamp(120, 900)), icon: const Icon(Icons.add_circle_outline)),
            const Spacer(),
            Text(_chunks.isEmpty ? '0/0' : '${_idx + 1}/${_chunks.length}', style: _mono(12, FontWeight.w600)),
          ]),
          const SizedBox(height: 8),
          FilledButton.icon(onPressed: _togglePlay, icon: Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded), label: Text(_playing ? 'Duraklat' : 'ORP Akışını Başlat')),
        ]),
      ),
    );
  }
}
