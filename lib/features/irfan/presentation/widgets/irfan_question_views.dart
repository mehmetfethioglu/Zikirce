import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../domain/irfan_models.dart';
import 'irfan_seljuk_star_painter.dart';

const Color _emeraldSuccess = Color(0xFF10B981);
const Color _gentleCoral = Color(0xFFD96B52);
const Color _seljukGold = Color(0xFFD4A574);

/// Çoktan seçmeli soru görünümü (%50 eleme jokeri ve sakin renk geri bildirimi ile).
class IrfanMultipleChoiceView extends StatelessWidget {
  final MultipleChoicePayload payload;
  final Set<int> eliminatedOptionIndices;
  final bool isAnswered;
  final int? selectedChoiceIndex;
  final ValueChanged<int> onSelectOption;

  const IrfanMultipleChoiceView({
    super.key,
    required this.payload,
    required this.eliminatedOptionIndices,
    required this.isAnswered,
    required this.selectedChoiceIndex,
    required this.onSelectOption,
  });

  static const List<String> _letters = ['A', 'B', 'C', 'D', 'E', 'F'];

  @override
  Widget build(BuildContext context) {
    final isTr = context.l10n.isTurkish;

    return Column(
      children: [
        for (int i = 0; i < payload.options.length; i++) ...[
          _ChoiceOptionTile(
            letter: i < _letters.length ? _letters[i] : '${i + 1}',
            text: payload.options[i].resolve(isTr),
            isEliminated: eliminatedOptionIndices.contains(i),
            isAnswered: isAnswered,
            isCorrectOption: i == payload.correctIndex,
            isSelectedOption: selectedChoiceIndex == i,
            onTap: () => onSelectOption(i),
          ),
          if (i < payload.options.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _ChoiceOptionTile extends StatelessWidget {
  final String letter;
  final String text;
  final bool isEliminated;
  final bool isAnswered;
  final bool isCorrectOption;
  final bool isSelectedOption;
  final VoidCallback onTap;

  const _ChoiceOptionTile({
    required this.letter,
    required this.text,
    required this.isEliminated,
    required this.isAnswered,
    required this.isCorrectOption,
    required this.isSelectedOption,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    Color borderColor = colors.borderStroke;
    Color bgColor = colors.cardBackground;
    Color badgeColor = colors.accent.withValues(alpha: 0.12);
    Color badgeTextColor = colors.accent;
    IconData? trailingIcon;
    Color? trailingColor;

    if (isAnswered) {
      if (isCorrectOption) {
        borderColor = _emeraldSuccess;
        bgColor = _emeraldSuccess.withValues(alpha: 0.10);
        badgeColor = _emeraldSuccess;
        badgeTextColor = Colors.white;
        trailingIcon = Icons.check_circle_rounded;
        trailingColor = _emeraldSuccess;
      } else if (isSelectedOption) {
        borderColor = _gentleCoral;
        bgColor = _gentleCoral.withValues(alpha: 0.10);
        badgeColor = _gentleCoral;
        badgeTextColor = Colors.white;
        trailingIcon = Icons.info_outline_rounded;
        trailingColor = _gentleCoral;
      }
    }

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 220),
      opacity: (isEliminated && !isAnswered) ? 0.34 : 1.0,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: (isAnswered || isEliminated) ? null : onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: borderColor,
                width: (isAnswered && (isCorrectOption || isSelectedOption))
                    ? 1.6
                    : 1.0,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    letter,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: badgeTextColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 14.5,
                      height: 1.38,
                      fontWeight: (isAnswered && isCorrectOption)
                          ? FontWeight.w600
                          : FontWeight.w500,
                      decoration: (isEliminated && !isAnswered)
                          ? TextDecoration.lineThrough
                          : null,
                      color: colors.primaryText,
                    ),
                  ),
                ),
                if (trailingIcon != null) ...[
                  const SizedBox(width: 8),
                  Icon(trailingIcon, color: trailingColor, size: 22),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Doğru / Yanlış soru görünümü.
class IrfanTrueFalseView extends StatelessWidget {
  final TrueFalsePayload payload;
  final bool isAnswered;
  final bool? selectedBoolAnswer;
  final ValueChanged<bool> onSelectAnswer;

  const IrfanTrueFalseView({
    super.key,
    required this.payload,
    required this.isAnswered,
    required this.selectedBoolAnswer,
    required this.onSelectAnswer,
  });

  @override
  Widget build(BuildContext context) {
    final isTr = context.l10n.isTurkish;

    return Row(
      children: [
        Expanded(
          child: _TrueFalseCard(
            label: isTr ? 'Doğru' : 'True',
            icon: Icons.check_rounded,
            value: true,
            isAnswered: isAnswered,
            isCorrectValue: payload.correctAnswer == true,
            isSelected: selectedBoolAnswer == true,
            onTap: () => onSelectAnswer(true),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _TrueFalseCard(
            label: isTr ? 'Yanlış' : 'False',
            icon: Icons.close_rounded,
            value: false,
            isAnswered: isAnswered,
            isCorrectValue: payload.correctAnswer == false,
            isSelected: selectedBoolAnswer == false,
            onTap: () => onSelectAnswer(false),
          ),
        ),
      ],
    );
  }
}

class _TrueFalseCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool value;
  final bool isAnswered;
  final bool isCorrectValue;
  final bool isSelected;
  final VoidCallback onTap;

  const _TrueFalseCard({
    required this.label,
    required this.icon,
    required this.value,
    required this.isAnswered,
    required this.isCorrectValue,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    Color borderColor = colors.borderStroke;
    Color bgColor = colors.cardBackground;
    Color iconBg = colors.accent.withValues(alpha: 0.12);
    Color iconColor = colors.accent;

    if (isAnswered) {
      if (isCorrectValue) {
        borderColor = _emeraldSuccess;
        bgColor = _emeraldSuccess.withValues(alpha: 0.12);
        iconBg = _emeraldSuccess;
        iconColor = Colors.white;
      } else if (isSelected) {
        borderColor = _gentleCoral;
        bgColor = _gentleCoral.withValues(alpha: 0.12);
        iconBg = _gentleCoral;
        iconColor = Colors.white;
      }
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isAnswered ? null : onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 14),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: borderColor,
              width: (isAnswered && (isCorrectValue || isSelected)) ? 1.6 : 1.0,
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.bold,
                  color: colors.primaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kavram eşleştirme (Matching) soru görünümü.
class IrfanMatchingView extends StatefulWidget {
  final String questionId;
  final MatchingPayload payload;
  final bool isAnswered;
  final ValueChanged<int> onCompleted;

  const IrfanMatchingView({
    super.key,
    required this.questionId,
    required this.payload,
    required this.isAnswered,
    required this.onCompleted,
  });

  @override
  State<IrfanMatchingView> createState() => _IrfanMatchingViewState();
}

class _IrfanMatchingViewState extends State<IrfanMatchingView>
    with SingleTickerProviderStateMixin {
  late List<int> _rightOrder;
  final Set<int> _matchedIndices = <int>{};
  int? _selectedLeftIndex;
  int? _wrongLeftIndex;
  int? _wrongRightPairIndex;
  int _mistakesCount = 0;

  late final AnimationController _mismatchController;

  @override
  void initState() {
    super.initState();
    _mismatchController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() {
            _wrongLeftIndex = null;
            _wrongRightPairIndex = null;
          });
        }
      });
    _resetForQuestion();
  }

  @override
  void didUpdateWidget(covariant IrfanMatchingView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.questionId != widget.questionId) {
      _resetForQuestion();
    }
  }

  void _resetForQuestion() {
    final len = widget.payload.pairs.length;
    final indices = List<int>.generate(len, (i) => i);
    if (len > 1) {
      final rng = math.Random(widget.questionId.hashCode);
      indices.shuffle(rng);
      bool allSame = true;
      for (int i = 0; i < len; i++) {
        if (indices[i] != i) {
          allSame = false;
          break;
        }
      }
      if (allSame) {
        final first = indices.removeAt(0);
        indices.add(first);
      }
    }
    _rightOrder = indices;
    _matchedIndices.clear();
    _selectedLeftIndex = null;
    _wrongLeftIndex = null;
    _wrongRightPairIndex = null;
    _mistakesCount = 0;
  }

  @override
  void dispose() {
    _mismatchController.dispose();
    super.dispose();
  }

  void _onTapLeft(int pairIndex) {
    if (widget.isAnswered || _matchedIndices.contains(pairIndex)) return;
    HapticService.selectionClick();
    setState(() {
      _selectedLeftIndex =
          (_selectedLeftIndex == pairIndex) ? null : pairIndex;
      _wrongLeftIndex = null;
      _wrongRightPairIndex = null;
    });
  }

  void _onTapRight(int pairIndex) {
    if (widget.isAnswered || _matchedIndices.contains(pairIndex)) return;
    final leftIdx = _selectedLeftIndex;
    if (leftIdx == null) {
      HapticService.selectionClick();
      return;
    }

    if (leftIdx == pairIndex) {
      HapticService.lightImpact();
      setState(() {
        _matchedIndices.add(pairIndex);
        _selectedLeftIndex = null;
        _wrongLeftIndex = null;
        _wrongRightPairIndex = null;
      });
      if (_matchedIndices.length == widget.payload.pairs.length) {
        widget.onCompleted(_mistakesCount);
      }
    } else {
      HapticService.error();
      setState(() {
        _mistakesCount++;
        _wrongLeftIndex = leftIdx;
        _wrongRightPairIndex = pairIndex;
        _selectedLeftIndex = null;
      });
      _mismatchController.forward(from: 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isTr = context.l10n.isTurkish;
    final pairs = widget.payload.pairs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isTr
              ? 'Önce soldaki kavramı, ardından sağdaki karşılığını seçin:'
              : 'Tap a concept on the left, then its match on the right:',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: colors.secondaryTextAlt,
          ),
        ),
        const SizedBox(height: 10),
        for (int row = 0; row < pairs.length; row++) ...[
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _MatchCell(
                    text: pairs[row].left.resolve(isTr),
                    isMatched:
                        widget.isAnswered || _matchedIndices.contains(row),
                    isSelected: _selectedLeftIndex == row,
                    isWrongFlash: _wrongLeftIndex == row,
                    onTap: () => _onTapLeft(row),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MatchCell(
                    text: pairs[_rightOrder[row]].right.resolve(isTr),
                    isMatched: widget.isAnswered ||
                        _matchedIndices.contains(_rightOrder[row]),
                    isSelected: false,
                    isWrongFlash: _wrongRightPairIndex == _rightOrder[row],
                    onTap: () => _onTapRight(_rightOrder[row]),
                  ),
                ),
              ],
            ),
          ),
          if (row < pairs.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _MatchCell extends StatelessWidget {
  final String text;
  final bool isMatched;
  final bool isSelected;
  final bool isWrongFlash;
  final VoidCallback onTap;

  const _MatchCell({
    required this.text,
    required this.isMatched,
    required this.isSelected,
    required this.isWrongFlash,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    Color borderColor = colors.borderStroke;
    Color bgColor = colors.cardBackground;

    if (isMatched) {
      borderColor = _emeraldSuccess;
      bgColor = _emeraldSuccess.withValues(alpha: 0.11);
    } else if (isWrongFlash) {
      borderColor = _gentleCoral;
      bgColor = _gentleCoral.withValues(alpha: 0.12);
    } else if (isSelected) {
      borderColor = colors.accent;
      bgColor = colors.accent.withValues(alpha: 0.12);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isMatched ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: borderColor,
              width: (isSelected || isMatched || isWrongFlash) ? 1.5 : 1.0,
            ),
          ),
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.32,
                    fontWeight: isSelected || isMatched
                        ? FontWeight.w600
                        : FontWeight.w500,
                    color: colors.primaryText,
                  ),
                ),
              ),
              if (isMatched) ...[
                const SizedBox(width: 4),
                const Icon(
                  Icons.check_circle_rounded,
                  size: 16,
                  color: _emeraldSuccess,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Cevap sonrası zarif "Hikmet & Sahih Kaynak Kartı" (mukayeseli fıkıh + yanlışta okuma köprüsü).
class IrfanHikmetCardView extends StatelessWidget {
  final IrfanHikmetCard hikmet;
  final bool isCorrect;
  final ValueChanged<String>? onPracticeZikir;
  final ValueChanged<int>? onReadFarz;
  final ValueChanged<String>? onReadBook;
  final String? linkedBookTitle;
  final VoidCallback? onUseMistakeShield;
  final bool isShieldUsed;

  const IrfanHikmetCardView({
    super.key,
    required this.hikmet,
    required this.isCorrect,
    this.onPracticeZikir,
    this.onReadFarz,
    this.onReadBook,
    this.linkedBookTitle,
    this.onUseMistakeShield,
    this.isShieldUsed = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final isTr = l10n.isTurkish;
    final hanafi = hikmet.hanafiNote?.resolve(isTr);
    final shafii = hikmet.shafiiNote?.resolve(isTr);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isCorrect
              ? _emeraldSuccess.withValues(alpha: 0.45)
              : _seljukGold.withValues(alpha: 0.55),
          width: 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IrfanSeljukStarBadge(
                size: 28,
                color: isCorrect ? _emeraldSuccess : _seljukGold,
                accentColor: _seljukGold,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isCorrect
                      ? (isTr
                          ? 'İsabet! Hikmet & Sahih Kaynak'
                          : 'Correct! Wisdom & Authentic Source')
                      : (isTr
                          ? 'Hikmet Notu • Öğrenme Fırsatı'
                          : 'Wisdom Note • Learning Moment'),
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: isCorrect ? _emeraldSuccess : colors.primaryText,
                  ),
                ),
              ),
              if (isCorrect && isShieldUsed)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _emeraldSuccess.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    isTr ? '🛡️ Kalkan' : '🛡️ Shielded',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: _emeraldSuccess,
                    ),
                  ),
                )
              else if (isCorrect && IrfanEconomyConfig.correctGoldReward > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _seljukGold.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '+${IrfanEconomyConfig.correctGoldReward} 🪙',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: colors.primaryText,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            hikmet.explanation.resolve(isTr),
            style: TextStyle(
              fontSize: 14,
              height: 1.52,
              color: colors.primaryText,
            ),
          ),
          if ((hanafi != null && hanafi.isNotEmpty) ||
              (shafii != null && shafii.isNotEmpty)) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.accent.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: colors.accent.withValues(alpha: 0.22),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isTr
                        ? '⚖️ Mezhep Mukayese Notu'
                        : '⚖️ Comparative Fiqh Note',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: colors.accent,
                    ),
                  ),
                  if (hanafi != null && hanafi.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      '• ${isTr ? 'Hanefî' : 'Hanafi'}: $hanafi',
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: colors.primaryText,
                      ),
                    ),
                  ],
                  if (shafii != null && shafii.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '• ${isTr ? 'Şâfiî' : 'Shafi\'i'}: $shafii',
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: colors.primaryText,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: colors.pageBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.borderStroke),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.verified_outlined,
                  size: 16,
                  color: colors.accent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hikmet.sourceRef.resolve(isTr),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colors.secondaryTextAlt,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (onPracticeZikir != null &&
              hikmet.linkedZikirKey != null &&
              hikmet.linkedZikirKey!.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  HapticService.selectionClick();
                  onPracticeZikir!(hikmet.linkedZikirKey!);
                },
                icon: Icon(
                  Icons.fingerprint_rounded,
                  size: 18,
                  color: colors.accent,
                ),
                label: Text(
                  '${l10n.irfanPracticeZikirCta} • ${hikmet.linkedZikirKey}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: colors.accent,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  side: BorderSide(color: colors.accent),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
              ),
            ),
          ],
          if (!isCorrect) ...[
            if (onUseMistakeShield != null) ...[
              const SizedBox(height: 12),
              _MistakeShieldCtaButton(
                label: isTr
                    ? '🛡️ İrfan Kalkanı ile Telafi Et (${IrfanEconomyConfig.swapOrShieldDiamondCost} 💎)'
                    : '🛡️ Redeem with Wisdom Shield (${IrfanEconomyConfig.swapOrShieldDiamondCost} 💎)',
                onTap: onUseMistakeShield!,
              ),
            ],
            if (hikmet.linkedFarzId != null && onReadFarz != null) ...[
              const SizedBox(height: 10),
              _WrongAnswerStudyButton(
                icon: Icons.menu_book_rounded,
                label: isTr
                    ? 'Farz #${hikmet.linkedFarzId} İlmihal Maddesini Oku'
                    : 'Read Farz #${hikmet.linkedFarzId} Catechism Entry',
                onTap: () => onReadFarz!(hikmet.linkedFarzId!),
              ),
            ],
            if (hikmet.linkedBookId != null && onReadBook != null) ...[
              const SizedBox(height: 8),
              _WrongAnswerStudyButton(
                icon: Icons.auto_stories_rounded,
                label: isTr
                    ? (linkedBookTitle != null
                        ? 'Külliyat\'ta Oku: $linkedBookTitle'
                        : 'Külliyat\'tan İlgili Eseri Oku')
                    : (linkedBookTitle != null
                        ? 'Read in Library: $linkedBookTitle'
                        : 'Read Related Book in Library'),
                onTap: () => onReadBook!(hikmet.linkedBookId!),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _MistakeShieldCtaButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _MistakeShieldCtaButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const Color amberAccent = Color(0xFFD4A574);
    final colors = context.colors;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          HapticService.selectionClick();
          onTap();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: amberAccent.withValues(alpha: 0.18),
          foregroundColor: colors.primaryText,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          side: BorderSide(color: amberAccent.withValues(alpha: 0.65)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            color: colors.primaryText,
          ),
        ),
      ),
    );
  }
}

class _WrongAnswerStudyButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _WrongAnswerStudyButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          HapticService.selectionClick();
          onTap();
        },
        icon: Icon(icon, size: 17, color: colors.accent),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: colors.primaryText,
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          backgroundColor: colors.accent.withValues(alpha: 0.06),
          side: BorderSide(color: colors.accent.withValues(alpha: 0.35)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
      ),
    );
  }
}
