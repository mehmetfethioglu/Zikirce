import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../speed_reading/domain/guided_flow_models.dart';

/// Akıcı Fasıl bitiminde aktif hatırlama, Haşiye çıkarımı ve tempo kalibrasyonu sunan mühürleme modalı.
class FasilReflectionSheet extends StatefulWidget {
  final FasilReflectionSummary summary;
  final Future<void> Function({
    required TempoCalibrationFeedback tempoFeedback,
    String? hasiyeNoteText,
  }) onSeal;

  const FasilReflectionSheet({
    super.key,
    required this.summary,
    required this.onSeal,
  });

  static Future<void> show(
    BuildContext context, {
    required FasilReflectionSummary summary,
    required Future<void> Function({
      required TempoCalibrationFeedback tempoFeedback,
      String? hasiyeNoteText,
    }) onSeal,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => FasilReflectionSheet(
        summary: summary,
        onSeal: onSeal,
      ),
    );
  }

  @override
  State<FasilReflectionSheet> createState() => _FasilReflectionSheetState();
}

class _FasilReflectionSheetState extends State<FasilReflectionSheet> {
  final TextEditingController _hasiyeController = TextEditingController();
  TempoCalibrationFeedback _selectedFeedback = TempoCalibrationFeedback.inFlow;
  bool _isRecallRevealed = false;
  bool _isSealing = false;
  String? _errorMessage;

  @override
  void dispose() {
    _hasiyeController.dispose();
    super.dispose();
  }

  Future<void> _handleSeal() async {
    if (_isSealing) return;
    setState(() {
      _isSealing = true;
      _errorMessage = null;
    });
    final note = _hasiyeController.text.trim();
    try {
      await widget.onSeal(
        tempoFeedback: _selectedFeedback,
        hasiyeNoteText: note.isEmpty ? null : note,
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSealing = false;
        _errorMessage = 'Fasıl mühürlenirken bir hata oluştu: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.90,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                _ReflectionHeader(summary: widget.summary),
                const SizedBox(height: 14),
                _ReflectionMetricsGrid(summary: widget.summary),
                if (widget.summary.keyConcepts.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _ConceptChipsSection(concepts: widget.summary.keyConcepts),
                ],
                const SizedBox(height: 14),
                _ActiveRecallCard(
                  sentence: widget.summary.centralRecallSentence,
                  isRevealed: _isRecallRevealed,
                  onTap: () => setState(() => _isRecallRevealed = true),
                ),
                const SizedBox(height: 14),
                _HasiyeNoteInput(controller: _hasiyeController),
                const SizedBox(height: 14),
                _TempoFeedbackSelector(
                  selected: _selectedFeedback,
                  onSelect: (value) => setState(() => _selectedFeedback = value),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _errorMessage!,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _isSealing ? null : _handleSeal,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: _isSealing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.verified_outlined, size: 20),
                  label: Text(
                    _isSealing ? 'Mühürleniyor...' : 'Mühürle & Kaydet',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
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

class _ReflectionHeader extends StatelessWidget {
  final FasilReflectionSummary summary;

  const _ReflectionHeader({required this.summary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.amberGold.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.amberGold.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.amberGold.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.workspace_premium_rounded,
              color: AppColors.terracotta,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fasıl Mühürleme & Tefekkür',
                  style: GoogleFonts.literata(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${summary.bookTitle} • S. ${summary.startPage}–${summary.endPage}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.5),
              ),
            ),
            child: Text(
              summary.densityTier.label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReflectionMetricsGrid extends StatelessWidget {
  final FasilReflectionSummary summary;

  const _ReflectionMetricsGrid({required this.summary});

  String _formatDuration(int totalSeconds) {
    final safe = totalSeconds < 0 ? 0 : totalSeconds;
    final mins = safe ~/ 60;
    final secs = safe % 60;
    if (mins == 0) return '${secs}s';
    return '${mins}d ${secs.toString().padLeft(2, '0')}s';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricTile(
            label: 'Sayfa',
            value: '${summary.pagesRead}',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricTile(
            label: 'Kelime',
            value: '${summary.wordsRead}',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricTile(
            label: 'Ort. WPM',
            value: '${summary.averageWpm}',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricTile(
            label: 'Süre',
            value: _formatDuration(summary.durationSeconds),
          ),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;

  const _MetricTile({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10.5,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConceptChipsSection extends StatelessWidget {
  final List<String> concepts;

  const _ConceptChipsSection({required this.concepts});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Fasılda Öne Çıkan Kavramlar',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.78),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: concepts.map((concept) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.30),
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
      ],
    );
  }
}

class _ActiveRecallCard extends StatelessWidget {
  final String sentence;
  final bool isRevealed;
  final VoidCallback onTap;

  const _ActiveRecallCard({
    required this.sentence,
    required this.isRevealed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: isRevealed ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isRevealed
              ? AppColors.amberGold.withValues(alpha: 0.12)
              : theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isRevealed
                ? AppColors.amberGold
                : theme.colorScheme.outline.withValues(alpha: 0.5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isRevealed
                      ? Icons.lightbulb_rounded
                      : Icons.visibility_outlined,
                  size: 17,
                  color: AppColors.terracotta,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Aktif Hatırlama (Ana Cümle Yoklaması)',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (isRevealed)
              Text(
                sentence,
                style: GoogleFonts.literata(
                  fontSize: 13.5,
                  height: 1.5,
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.onSurface,
                ),
              )
            else
              Text(
                'Az önce okuduklarından aklında kalan temel fikri zihninde toparla, ardından metnin merkezî cümlesiyle kıyaslamak için dokun.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  height: 1.4,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HasiyeNoteInput extends StatelessWidget {
  final TextEditingController controller;

  const _HasiyeNoteInput({required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Haşiye Çıkarımı (İsteğe Bağlı • 1 Cümle)',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.78),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: 2,
          maxLength: 200,
          textInputAction: TextInputAction.done,
          style: GoogleFonts.literata(
            fontSize: 13.5,
            color: theme.colorScheme.onSurface,
          ),
          decoration: InputDecoration(
            hintText: 'Bu fasıldan zihnine nakşolan tek cümlelik çıkarımını yaz...',
            hintStyle: GoogleFonts.inter(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.48),
            ),
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.3),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: theme.colorScheme.outline.withValues(alpha: 0.45),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: theme.colorScheme.outline.withValues(alpha: 0.45),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: AppColors.amberGold,
                width: 1.5,
              ),
            ),
            counterStyle: GoogleFonts.jetBrainsMono(fontSize: 10.5),
          ),
        ),
      ],
    );
  }
}

class _TempoFeedbackSelector extends StatelessWidget {
  final TempoCalibrationFeedback selected;
  final ValueChanged<TempoCalibrationFeedback> onSelect;

  const _TempoFeedbackSelector({
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bir Sonraki Fasıl İçin Tempo Kalibrasyonu',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.78),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: TempoCalibrationFeedback.values.map((option) {
            final isSelected = option == selected;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: option == TempoCalibrationFeedback.values.last ? 0 : 8,
                ),
                child: InkWell(
                  onTap: () => onSelect(option),
                  borderRadius: BorderRadius.circular(14),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? theme.colorScheme.primary.withValues(alpha: 0.14)
                          : theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.amberGold
                            : theme.colorScheme.outline.withValues(alpha: 0.45),
                        width: isSelected ? 1.8 : 1.0,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          option.label,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          option.subtitle,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.65),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
