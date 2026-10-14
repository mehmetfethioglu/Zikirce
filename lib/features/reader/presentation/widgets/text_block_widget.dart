import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../domain/content_block.dart';
import '../../engine/text_segmenter.dart';
import 'arabic_text_card.dart';
import 'inline_footnote_modal.dart';

/// Temiz Türkçe/İngilizce gövde metni ve başlıkları render eden performanslı tipografi widget'ı
class TextBlockWidget extends StatelessWidget {
  final TextBlock block;
  final ReaderThemeState themeState;
  final VoidCallback? onPlayTts;
  final void Function(String selectedText)? onOpenDictionary;
  final void Function(String selectedText)? onOpenQuoteStudio;
  final void Function(String selectedText)? onAddHighlight;

  const TextBlockWidget({
    super.key,
    required this.block,
    required this.themeState,
    this.onPlayTts,
    this.onOpenDictionary,
    this.onOpenQuoteStudio,
    this.onAddHighlight,
  });

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

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText.rich(
            TextSpan(
              children: themeState.bionicReadingEnabled
                  ? TextSegmenter.buildBionicSpans(
                      block.text,
                      normalStyle: normalTextStyle,
                      boldStyle: boldTextStyle,
                    )
                  : [
                      TextSpan(
                        text: block.text,
                        style: normalTextStyle,
                      ),
                    ],
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
