import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/utils/share_utils.dart';
import 'irfan_share_card.dart';

/// İrfan Meydanı Hikmet Kartı Önizleme ve Paylaşım Stüdyosu (9:16 Story & 1:1 Kare).
class IrfanSharePreviewModal extends StatefulWidget {
  final String sessionTitle;
  final int correctCount;
  final int totalQuestions;
  final int streakDays;
  final String hikmetQuote;
  final String sourceRef;

  const IrfanSharePreviewModal({
    super.key,
    required this.sessionTitle,
    required this.correctCount,
    required this.totalQuestions,
    required this.streakDays,
    required this.hikmetQuote,
    required this.sourceRef,
  });

  static Future<void> show({
    required BuildContext context,
    required String sessionTitle,
    required int correctCount,
    required int totalQuestions,
    required int streakDays,
    required String hikmetQuote,
    required String sourceRef,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => IrfanSharePreviewModal(
        sessionTitle: sessionTitle,
        correctCount: correctCount,
        totalQuestions: totalQuestions,
        streakDays: streakDays,
        hikmetQuote: hikmetQuote,
        sourceRef: sourceRef,
      ),
    );
  }

  @override
  State<IrfanSharePreviewModal> createState() => _IrfanSharePreviewModalState();
}

class _IrfanSharePreviewModalState extends State<IrfanSharePreviewModal> {
  final GlobalKey _repaintKey = GlobalKey();
  IrfanShareFormat _format = IrfanShareFormat.story9x16;
  IrfanShareTheme _theme = IrfanShareTheme.seljukEmerald;
  bool _isSharing = false;

  Future<void> _exportAndShare(BuildContext buttonContext) async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    HapticService.lightImpact();

    final isTr = context.l10n.isTurkish;
    final origin = ShareUtils.resolveSharePositionOrigin(buttonContext);

    try {
      await WidgetsBinding.instance.endOfFrame;
      final boundary = _repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        if (mounted) setState(() => _isSharing = false);
        return;
      }

      final ui.Image image = await boundary.toImage(pixelRatio: 3.5);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();

      if (byteData == null) {
        if (mounted) setState(() => _isSharing = false);
        return;
      }

      final Uint8List pngBytes = byteData.buffer.asUint8List();
      final String fileName =
          'zikirce_irfan_${DateTime.now().millisecondsSinceEpoch}.png';

      final String caption = isTr
          ? '“${widget.hikmetQuote}” (${widget.sourceRef})\n— Zikirce İrfan Meydanı'
          : '“${widget.hikmetQuote}” (${widget.sourceRef})\n— Zikirce Wisdom Plaza';

      await ShareUtils.shareXFiles(
        [
          XFile.fromData(
            pngBytes,
            mimeType: 'image/png',
            name: fileName,
          ),
        ],
        text: caption,
        subject: '${widget.sessionTitle} - Zikirce',
        sharePositionOrigin: origin,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isTr
                  ? 'Paylaşım kartı hazırlanamadı.'
                  : 'Could not generate share card.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isTr = context.l10n.isTurkish;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.90,
      ),
      decoration: BoxDecoration(
        color: colors.bottomSheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.secondaryTextAlt.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      isTr ? 'İrfan Hikmet Kartı Paylaş' : 'Share Wisdom Card',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: colors.primaryText,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: colors.primaryText),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Format Seçici: 9:16 Story / 1:1 Kare
              Row(
                children: [
                  Expanded(
                    child: _FormatSegmentButton(
                      label: isTr ? 'Story (9:16)' : 'Story (9:16)',
                      icon: Icons.stay_current_portrait_rounded,
                      isSelected: _format == IrfanShareFormat.story9x16,
                      onTap: () {
                        HapticService.selectionClick();
                        setState(() => _format = IrfanShareFormat.story9x16);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _FormatSegmentButton(
                      label: isTr ? 'Kare (1:1)' : 'Square (1:1)',
                      icon: Icons.crop_square_rounded,
                      isSelected: _format == IrfanShareFormat.square1x1,
                      onTap: () {
                        HapticService.selectionClick();
                        setState(() => _format = IrfanShareFormat.square1x1);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Tema Seçici
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ThemeDotButton(
                    label: isTr ? 'Zümrüt' : 'Emerald',
                    color: const Color(0xFF1B5E49),
                    isSelected: _theme == IrfanShareTheme.seljukEmerald,
                    onTap: () {
                      HapticService.selectionClick();
                      setState(() => _theme = IrfanShareTheme.seljukEmerald);
                    },
                  ),
                  const SizedBox(width: 12),
                  _ThemeDotButton(
                    label: isTr ? 'Gece Altın' : 'Night Gold',
                    color: const Color(0xFF1F2738),
                    isSelected: _theme == IrfanShareTheme.royalNightGold,
                    onTap: () {
                      HapticService.selectionClick();
                      setState(() => _theme = IrfanShareTheme.royalNightGold);
                    },
                  ),
                  const SizedBox(width: 12),
                  _ThemeDotButton(
                    label: isTr ? 'Ferman' : 'Parchment',
                    color: const Color(0xFFE9D9BE),
                    isSelected: _theme == IrfanShareTheme.parchmentNoor,
                    onTap: () {
                      HapticService.selectionClick();
                      setState(() => _theme = IrfanShareTheme.parchmentNoor);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Canlı Kart Önizleme (RepaintBoundary)
              Flexible(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: RepaintBoundary(
                        key: _repaintKey,
                        child: IrfanShareCard(
                          format: _format,
                          theme: _theme,
                          sessionTitle: widget.sessionTitle,
                          correctCount: widget.correctCount,
                          totalQuestions: widget.totalQuestions,
                          streakDays: widget.streakDays,
                          hikmetQuote: widget.hikmetQuote,
                          sourceRef: widget.sourceRef,
                          isTurkish: isTr,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Builder(
                builder: (btnContext) => SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSharing
                        ? null
                        : () => _exportAndShare(btnContext),
                    icon: _isSharing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.ios_share_rounded,
                            color: Colors.white,
                            size: 19,
                          ),
                    label: Text(
                      isTr ? 'Yüksek Çözünürlüklü Paylaş' : 'Share High-Res Card',
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.accent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
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

class _FormatSegmentButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _FormatSegmentButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: isSelected ? colors.accent : colors.cardBackgroundAlt,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: isSelected ? colors.accent : colors.borderStroke,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : colors.secondaryTextAlt,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : colors.primaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeDotButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeDotButton({
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? colors.accent.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? colors.accent : colors.borderStroke,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white54),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: colors.primaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
