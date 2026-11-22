import 'package:flutter/material.dart';
import '../../../../core/services/haptic_service.dart';

/// Tilâvet secdesi borcu hatırlatmasını Kur'ân metninin üstünde gösterir.
///
/// Rehber açma alanı ile kapatma (`✕`) butonu ayrı kardeş etkileşim
/// alanları olarak düzenlenmiştir; kapatma dokunuşları rehber ekranını açmaz.
class TilavetSecdesiDebtReminderBanner extends StatelessWidget {
  final int debtCount;
  final VoidCallback onOpenGuide;
  final VoidCallback onDismiss;
  final EdgeInsetsGeometry padding;

  const TilavetSecdesiDebtReminderBanner({
    super.key,
    required this.debtCount,
    required this.onOpenGuide,
    required this.onDismiss,
    this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 6),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
        isDark ? const Color(0xFF2C2216) : const Color(0xFFFFF8E7);
    const borderColor = Color(0xFFD97706);
    final textColor =
        isDark ? const Color(0xFFFFD56B) : const Color(0xFF8C5400);
    final actionTextColor =
        isDark ? Colors.white : const Color(0xFF8C5400);
    final actionBg = borderColor.withValues(alpha: isDark ? 0.24 : 0.14);
    final closeBg = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : borderColor.withValues(alpha: 0.12);
    final closeIconColor =
        isDark ? Colors.white70 : const Color(0xFF6B4E16);

    return Padding(
      padding: padding,
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Material(
            color: Colors.transparent,
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    key: const Key('tilavet_debt_banner_guide_tap'),
                    onTap: () {
                      HapticService.tapClick();
                      onOpenGuide();
                    },
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 9, 10, 9),
                      child: Row(
                        children: [
                          const Text('📌', style: TextStyle(fontSize: 15)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '$debtCount adet tilâvet secdesi borcunuz bulunuyor.',
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                height: 1.25,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            key: const Key('tilavet_debt_banner_guide_chip'),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: actionBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: borderColor.withValues(
                                  alpha: isDark ? 0.45 : 0.35,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Rehber',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: actionTextColor,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 13,
                                  color: actionTextColor,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  height: 26,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  color: borderColor.withValues(alpha: isDark ? 0.32 : 0.25),
                ),
                Semantics(
                  button: true,
                  label: 'Kapat',
                  child: Tooltip(
                    message: 'Kapat',
                    child: InkWell(
                      key: const Key('tilavet_debt_banner_close_button'),
                      onTap: () {
                        HapticService.selectionClick();
                        onDismiss();
                      },
                      borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(13),
                      ),
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: Center(
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: closeBg,
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              size: 17,
                              color: closeIconColor,
                            ),
                          ),
                        ),
                      ),
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
