import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../domain/entities/highlight_entity.dart';
import '../../domain/content_block.dart';
import '../../engine/ocr_proofreader_engine.dart';
import '../../engine/text_segmenter.dart';
import 'arabic_text_card.dart';
import 'inline_footnote_modal.dart';

/// Temiz Türkçe/İngilizce gövde metni ve başlıkları render eden performanslı tipografi widget'ı
class TextBlockWidget extends StatefulWidget {
  final TextBlock block;
  final ReaderThemeState themeState;
  final String? activeTtsWord;
  final bool isReadingAloud;
  final List<HighlightEntity> blockHighlights;
  final VoidCallback? onPlayTts;
  final void Function(String selectedText)? onOpenDictionary;
  final void Function(String selectedText)? onOpenQuoteStudio;
  final void Function(String selectedText)? onAddHighlight;
  final void Function(String selectedText)? onOpenConceptRadar;
  final void Function(String selectedText)? onCorrectWord;
  final void Function(String tappedWord, String paragraphText)? onTapWord;
  final bool isOcrReviewHighlightEnabled;
  final Set<String> autoCorrectedWordsLower;
  final Set<String> suspiciousWordsLower;
  final ({int start, int end, double opacity})? activeGuidedChunkRange;

  const TextBlockWidget({
    super.key,
    required this.block,
    required this.themeState,
    this.activeTtsWord,
    this.isReadingAloud = false,
    this.blockHighlights = const [],
    this.onPlayTts,
    this.onOpenDictionary,
    this.onOpenQuoteStudio,
    this.onAddHighlight,
    this.onOpenConceptRadar,
    this.onCorrectWord,
    this.onTapWord,
    this.isOcrReviewHighlightEnabled = false,
    this.autoCorrectedWordsLower = const {},
    this.suspiciousWordsLower = const {},
    this.activeGuidedChunkRange,
  });

  @override
  State<TextBlockWidget> createState() => _TextBlockWidgetState();
}

class _TextBlockWidgetState extends State<TextBlockWidget> {
  final List<TapGestureRecognizer> _tapRecognizers = [];

  void _clearTapRecognizers() {
    for (final r in _tapRecognizers) {
      r.dispose();
    }
    _tapRecognizers.clear();
  }

  @override
  void didUpdateWidget(covariant TextBlockWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _clearTapRecognizers();
  }

  @override
  void dispose() {
    _clearTapRecognizers();
    super.dispose();
  }

  TapGestureRecognizer? _createWordTapRecognizer(String rawWord) {
    if (widget.onTapWord == null) return null;
    final cleanTappedWord = rawWord
        .replaceAll(
          RegExp(r'^[^\p{L}\p{N}]+|[^\p{L}\p{N}]+$', unicode: true),
          '',
        )
        .trim();
    if (cleanTappedWord.length < 2) return null;

    final recognizer = TapGestureRecognizer()
      ..onTap = () {
        widget.onTapWord?.call(cleanTappedWord, widget.block.text);
      };
    _tapRecognizers.add(recognizer);
    return recognizer;
  }

  Color _parseHexColor(String hex, Color fallback) {
    final clean = hex.replaceAll('#', '').trim();
    if (clean.length == 6) {
      final val = int.tryParse('FF$clean', radix: 16);
      if (val != null) return Color(val);
    }
    return fallback;
  }

  List<TextSpan> _buildParagraphSpans({
    required ThemeData theme,
    required TextStyle normalStyle,
    required TextStyle boldStyle,
  }) {
    _clearTapRecognizers();

    final rawTts = widget.activeTtsWord?.trim();
    final ttsTarget = (rawTts != null && rawTts.isNotEmpty)
        ? OcrProofreaderEngine.toTurkishLower(rawTts)
        : null;
    final hasTtsTarget = ttsTarget != null &&
        OcrProofreaderEngine.toTurkishLower(widget.block.text)
            .contains(ttsTarget);
    final hasReviewUnderlines = widget.isOcrReviewHighlightEnabled &&
        (widget.autoCorrectedWordsLower.isNotEmpty ||
            widget.suspiciousWordsLower.isNotEmpty);
    final guidedRange = widget.activeGuidedChunkRange;
    final hasGuidedRange = guidedRange != null;

    if (!hasTtsTarget &&
        !hasReviewUnderlines &&
        !hasGuidedRange &&
        widget.onTapWord == null) {
      if (widget.themeState.bionicReadingEnabled) {
        return TextSegmenter.buildBionicSpans(
          widget.block.text,
          normalStyle: normalStyle,
          boldStyle: boldStyle,
        );
      }
      return [TextSpan(text: widget.block.text, style: normalStyle)];
    }

    final guidedBackground = guidedRange != null
        ? AppColors.amberGold
            .withValues(alpha: (0.28 * guidedRange.opacity).clamp(0.0, 1.0))
        : null;
    final spans = <TextSpan>[];
    final highlightStyle = normalStyle.copyWith(
      backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.28),
      fontWeight: FontWeight.w700,
    );
    final suspiciousStyle = normalStyle.copyWith(
      decoration: TextDecoration.underline,
      decorationColor: Colors.redAccent,
      decorationStyle: TextDecorationStyle.wavy,
      decorationThickness: 2.0,
    );
    final autoCorrectedStyle = normalStyle.copyWith(
      decoration: TextDecoration.underline,
      decorationColor: const Color(0xFF10B981),
      decorationStyle: TextDecorationStyle.dotted,
      decorationThickness: 1.8,
    );

    final matches = RegExp(r'\S+|\s+').allMatches(widget.block.text);
    for (final match in matches) {
      final token = match.group(0)!;
      final isInGuidedChunk = guidedRange != null &&
          guidedBackground != null &&
          match.start >= guidedRange.start &&
          match.end <= guidedRange.end;

      if (token.trim().isEmpty) {
        spans.add(
          TextSpan(
            text: token,
            style: isInGuidedChunk
                ? normalStyle.copyWith(backgroundColor: guidedBackground)
                : normalStyle,
          ),
        );
        continue;
      }

      final outerStripped = OcrProofreaderEngine.toTurkishLower(
        token.replaceAll(
          RegExp(r'^[^\p{L}\p{N}]+|[^\p{L}\p{N}]+$', unicode: true),
          '',
        ),
      );
      final cleanWord = OcrProofreaderEngine.toTurkishLower(
        token.replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), ''),
      );
      final tapRecognizer = _createWordTapRecognizer(token);

      final matchesSuspicious = hasReviewUnderlines &&
          ((outerStripped.isNotEmpty &&
                  widget.suspiciousWordsLower.contains(outerStripped)) ||
              (cleanWord.isNotEmpty &&
                  widget.suspiciousWordsLower.contains(cleanWord)));
      final matchesAutoCorrected = hasReviewUnderlines &&
          ((outerStripped.isNotEmpty &&
                  widget.autoCorrectedWordsLower.contains(outerStripped)) ||
              (cleanWord.isNotEmpty &&
                  widget.autoCorrectedWordsLower.contains(cleanWord)));

      if (cleanWord.isNotEmpty &&
          (cleanWord == ttsTarget || outerStripped == ttsTarget)) {
        spans.add(
          TextSpan(
            text: token,
            style: highlightStyle,
            recognizer: tapRecognizer,
          ),
        );
      } else if (matchesSuspicious) {
        spans.add(
          TextSpan(
            text: token,
            style: isInGuidedChunk
                ? suspiciousStyle.copyWith(backgroundColor: guidedBackground)
                : suspiciousStyle,
            recognizer: tapRecognizer,
          ),
        );
      } else if (matchesAutoCorrected) {
        spans.add(
          TextSpan(
            text: token,
            style: isInGuidedChunk
                ? autoCorrectedStyle.copyWith(backgroundColor: guidedBackground)
                : autoCorrectedStyle,
            recognizer: tapRecognizer,
          ),
        );
      } else if (widget.themeState.bionicReadingEnabled) {
        final length = token.length;
        final highlightLength =
            (length <= 3) ? 1 : (length <= 6 ? 2 : (length * 0.45).round());
        final secondRecognizer = _createWordTapRecognizer(token);
        spans.add(
          TextSpan(
            text: token.substring(0, highlightLength),
            style: isInGuidedChunk
                ? boldStyle.copyWith(backgroundColor: guidedBackground)
                : boldStyle,
            recognizer: tapRecognizer,
          ),
        );
        spans.add(
          TextSpan(
            text: token.substring(highlightLength),
            style: isInGuidedChunk
                ? normalStyle.copyWith(backgroundColor: guidedBackground)
                : normalStyle,
            recognizer: secondRecognizer,
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: token,
            style: isInGuidedChunk
                ? normalStyle.copyWith(backgroundColor: guidedBackground)
                : normalStyle,
            recognizer: tapRecognizer,
          ),
        );
      }
    }

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final block = widget.block;
    final themeState = widget.themeState;

    if (block.isHeading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          block.text,
          style: GoogleFonts.literata(
            fontSize: themeState.fontSize + 4,
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.primary,
            height: 1.3,
          ),
        ),
      );
    }

    if (block.isArabic) {
      return ArabicTextCard(
        arabicText: block.text,
        themeState: themeState,
        onPlayTts: widget.onPlayTts,
      );
    }

    final normalTextStyle = themeState.fontFamily.getTextStyle(
      fontSize: themeState.fontSize,
      height: themeState.lineHeight,
      color: theme.colorScheme.onSurface,
    );

    final boldTextStyle = themeState.fontFamily.getTextStyle(
      fontSize: themeState.fontSize,
      height: themeState.lineHeight,
      fontWeight: FontWeight.w800,
      color: theme.colorScheme.onSurface,
    );

    final paragraphLower = block.text.toLowerCase();
    final matchedHighlights = widget.blockHighlights.where((h) {
      final sel = h.selectedText.trim().toLowerCase();
      if (sel.isEmpty) return false;
      return paragraphLower.contains(sel) || sel.contains(paragraphLower);
    }).toList();

    final ttsTarget = widget.activeTtsWord?.trim().toLowerCase();
    final isTtsActiveInBlock = widget.isReadingAloud &&
        ttsTarget != null &&
        ttsTarget.isNotEmpty &&
        paragraphLower.contains(ttsTarget);
    final isDimmedByTts = widget.isReadingAloud &&
        ttsTarget != null &&
        ttsTarget.isNotEmpty &&
        !isTtsActiveInBlock;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 220),
      opacity: isDimmedByTts ? 0.50 : 1.0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        margin: const EdgeInsets.only(bottom: 16),
        padding: isTtsActiveInBlock
            ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
            : EdgeInsets.zero,
        decoration: isTtsActiveInBlock
            ? BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.45),
                  width: 1.4,
                ),
              )
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isTtsActiveInBlock || matchedHighlights.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (isTtsActiveInBlock)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '🔊 Sinematik Odak Spotu',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      )
                    else
                      const SizedBox.shrink(),
                    if (matchedHighlights.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.colorScheme.primary.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          '🖋️ ${matchedHighlights.length} Derkenar Haşiyesi',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            SelectableText.rich(
              TextSpan(
                children: _buildParagraphSpans(
                  theme: theme,
                  normalStyle: normalTextStyle,
                  boldStyle: boldTextStyle,
                ),
              ),
              textAlign: TextAlign.justify,
              contextMenuBuilder: (context, editableTextState) {
                return AdaptiveTextSelectionToolbar.buttonItems(
                  anchors: editableTextState.contextMenuAnchors,
                  buttonItems: [
                    if (widget.onCorrectWord != null)
                      ContextMenuButtonItem(
                        label: '🔍 Tashih / Düzelt',
                        onPressed: () {
                          final selected = editableTextState.textEditingValue.selection
                              .textInside(editableTextState.textEditingValue.text);
                          editableTextState.hideToolbar();
                          widget.onCorrectWord!(selected);
                        },
                      ),
                    if (widget.onOpenDictionary != null)
                      ContextMenuButtonItem(
                        label: '📖 Lügat / Sözlük',
                        onPressed: () {
                          final selected = editableTextState.textEditingValue.selection
                              .textInside(editableTextState.textEditingValue.text);
                          editableTextState.hideToolbar();
                          widget.onOpenDictionary!(selected);
                        },
                      ),
                    if (widget.onOpenConceptRadar != null)
                      ContextMenuButtonItem(
                        label: '🧭 Kavram Radarı',
                        onPressed: () {
                          final selected = editableTextState.textEditingValue.selection
                              .textInside(editableTextState.textEditingValue.text);
                          editableTextState.hideToolbar();
                          widget.onOpenConceptRadar!(selected);
                        },
                      ),
                    if (widget.onOpenQuoteStudio != null)
                      ContextMenuButtonItem(
                        label: '🎨 Alıntı Kartı Yap',
                        onPressed: () {
                          final selected = editableTextState.textEditingValue.selection
                              .textInside(editableTextState.textEditingValue.text);
                          editableTextState.hideToolbar();
                          widget.onOpenQuoteStudio!(selected);
                        },
                      ),
                    if (widget.onAddHighlight != null)
                      ContextMenuButtonItem(
                        label: '✍️ Not & Vurgu',
                        onPressed: () {
                          final selected = editableTextState.textEditingValue.selection
                              .textInside(editableTextState.textEditingValue.text);
                          editableTextState.hideToolbar();
                          widget.onAddHighlight!(selected);
                        },
                      ),
                  ],
                );
              },
            ),
            if (matchedHighlights.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: matchedHighlights.map((h) {
                    final barColor =
                        _parseHexColor(h.colorHex, theme.colorScheme.primary);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: barColor.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                        border: Border(
                          left: BorderSide(color: barColor, width: 4),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: barColor.withValues(alpha: 0.22),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  h.category.displayName,
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '“${h.selectedText}”',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.literata(
                                    fontSize: 11,
                                    fontStyle: FontStyle.italic,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.75),
                                  ),
                                ),
                              ),
                              if (widget.onOpenQuoteStudio != null)
                                InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () =>
                                      widget.onOpenQuoteStudio!(h.selectedText),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    child: Text(
                                      '🎨 Mühürle',
                                      style: GoogleFonts.inter(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                ),
                              if (widget.onOpenConceptRadar != null)
                                InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () {
                                    final firstWord = h.selectedText
                                        .trim()
                                        .split(RegExp(r'\s+'))
                                        .firstWhere(
                                          (w) => w.length >= 4,
                                          orElse: () => h.selectedText.trim(),
                                        );
                                    widget.onOpenConceptRadar!(firstWord);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    child: Text(
                                      '🧭 Radar',
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
                          if (h.userNote != null &&
                              h.userNote!.trim().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              '✍️ ${h.userNote}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                height: 1.4,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            if (block.footnoteAnchors.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: block.footnoteAnchors.map((anchor) {
                    final rawContent = anchor.content?.trim();
                    final footnoteContent = (rawContent != null &&
                            rawContent.isNotEmpty &&
                            !rawContent.endsWith('Bu sayfadaki ilgili izahat.'))
                        ? rawContent
                        : TextSegmenter.resolveContextualFootnote(
                            block.text,
                            anchorKey: anchor.key,
                          );
                    return ActionChip(
                      avatar: const Icon(Icons.bookmark_outline, size: 14),
                      label: Text(
                        'Dipnot ${anchor.key}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: () {
                        InlineFootnoteModal.show(
                          context,
                          anchorKey: anchor.key,
                          content: footnoteContent,
                        );
                      },
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

