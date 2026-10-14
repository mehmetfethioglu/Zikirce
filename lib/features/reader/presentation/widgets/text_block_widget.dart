import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../domain/entities/highlight_entity.dart';
import '../../domain/content_block.dart';
import '../../engine/text_segmenter.dart';
import 'arabic_text_card.dart';
import 'inline_footnote_modal.dart';

/// Temiz Türkçe/İngilizce gövde metni ve başlıkları render eden performanslı tipografi widget'ı
class TextBlockWidget extends StatelessWidget {
  final TextBlock block;
  final ReaderThemeState themeState;
  final String? activeTtsWord;
  final List<HighlightEntity> blockHighlights;
  final VoidCallback? onPlayTts;
  final void Function(String selectedText)? onOpenDictionary;
  final void Function(String selectedText)? onOpenQuoteStudio;
  final void Function(String selectedText)? onAddHighlight;

  const TextBlockWidget({
    super.key,
    required this.block,
    required this.themeState,
    this.activeTtsWord,
    this.blockHighlights = const [],
    this.onPlayTts,
    this.onOpenDictionary,
    this.onOpenQuoteStudio,
    this.onAddHighlight,
  });

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
    final ttsTarget = activeTtsWord?.trim().toLowerCase();
    final hasTtsTarget = ttsTarget != null &&
        ttsTarget.isNotEmpty &&
        block.text.toLowerCase().contains(ttsTarget);

    if (!hasTtsTarget) {
      if (themeState.bionicReadingEnabled) {
        return TextSegmenter.buildBionicSpans(
          block.text,
          normalStyle: normalStyle,
          boldStyle: boldStyle,
        );
      }
      return [TextSpan(text: block.text, style: normalStyle)];
    }

    final words = block.text.split(' ');
    final spans = <TextSpan>[];
    final highlightStyle = normalStyle.copyWith(
      backgroundColor: theme.colorScheme.primary.withOpacity(0.28),
      fontWeight: FontWeight.w700,
    );

    for (int i = 0; i < words.length; i++) {
      final word = words[i];
      if (word.isEmpty) continue;

      final cleanWord = word
          .replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '')
          .toLowerCase();

      if (cleanWord.isNotEmpty && cleanWord == ttsTarget) {
        spans.add(TextSpan(text: word, style: highlightStyle));
      } else if (themeState.bionicReadingEnabled) {
        final length = word.length;
        final highlightLength =
            (length <= 3) ? 1 : (length <= 6 ? 2 : (length * 0.45).round());
        spans.add(TextSpan(
          text: word.substring(0, highlightLength),
          style: boldStyle,
        ));
        spans.add(TextSpan(
          text: word.substring(highlightLength),
          style: normalStyle,
        ));
      } else {
        spans.add(TextSpan(text: word, style: normalStyle));
      }

      if (i < words.length - 1) {
        spans.add(TextSpan(text: ' ', style: normalStyle));
      }
    }

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
        onPlayTts: onPlayTts,
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
    final matchedHighlights = blockHighlights.where((h) {
      final sel = h.selectedText.trim().toLowerCase();
      if (sel.isEmpty) return false;
      return paragraphLower.contains(sel) || sel.contains(paragraphLower);
    }).toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                  if (onOpenDictionary != null)
                    ContextMenuButtonItem(
                      label: '📖 Lügat / Sözlük',
                      onPressed: () {
                        final selected = editableTextState.textEditingValue.selection
                            .textInside(editableTextState.textEditingValue.text);
                        editableTextState.hideToolbar();
                        onOpenDictionary!(selected);
                      },
                    ),
                  if (onOpenQuoteStudio != null)
                    ContextMenuButtonItem(
                      label: '🎨 Alıntı Kartı Yap',
                      onPressed: () {
                        final selected = editableTextState.textEditingValue.selection
                            .textInside(editableTextState.textEditingValue.text);
                        editableTextState.hideToolbar();
                        onOpenQuoteStudio!(selected);
                      },
                    ),
                  if (onAddHighlight != null)
                    ContextMenuButtonItem(
                      label: '✍️ Şerh & Vurgu',
                      onPressed: () {
                        final selected = editableTextState.textEditingValue.selection
                            .textInside(editableTextState.textEditingValue.text);
                        editableTextState.hideToolbar();
                        onAddHighlight!(selected);
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
                  final barColor = _parseHexColor(h.colorHex, theme.colorScheme.primary);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: barColor.withOpacity(0.10),
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
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: barColor.withOpacity(0.22),
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
                                  color: theme.colorScheme.onSurface.withOpacity(0.75),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (h.userNote != null && h.userNote!.trim().isNotEmpty) ...[
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
                  final footnoteContent = anchor.content ??
                      'Dipnot ${anchor.key}: Bu sayfadaki ilgili izahat.';
                  return ActionChip(
                    avatar: const Icon(Icons.bookmark_outline, size: 14),
                    label: Text(
                      'Dipnot ${anchor.key}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
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
    );
  }
}

