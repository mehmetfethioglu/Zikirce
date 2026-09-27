import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/database_provider.dart';
import '../../../../core/services/prayer_tracking_service.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../providers/prayer_providers.dart';

class PendingPrayerDialog extends ConsumerStatefulWidget {
  final String prayerName;
  final String dateStr;
  final VoidCallback? onAnswered;

  const PendingPrayerDialog({
    super.key,
    required this.prayerName,
    required this.dateStr,
    this.onAnswered,
  });

  /// Shows the pending prayer dialog modal
  static Future<void> show(
    BuildContext context, {
    required String prayerName,
    required String dateStr,
    VoidCallback? onAnswered,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (ctx) => PendingPrayerDialog(
        prayerName: prayerName,
        dateStr: dateStr,
        onAnswered: onAnswered,
      ),
    );
  }

  @override
  ConsumerState<PendingPrayerDialog> createState() => _PendingPrayerDialogState();
}

class _PendingPrayerDialogState extends ConsumerState<PendingPrayerDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleAnswer(bool answeredYes) async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    final db = ref.read(databaseProvider);
    await PrayerTrackingService.answerPrayerQuestion(
      db,
      widget.dateStr,
      widget.prayerName,
      answeredYes,
    );

    // Refresh providers
    ref.invalidate(todayPrayersProvider);
    ref.invalidate(kazaPrayersStreamProvider);
    ref.invalidate(kazaSummaryProvider);

    widget.onAnswered?.call();

    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();

      // Check if another unanswered prayer exists for today
      final timings = ref.read(prayerTimingsProvider).valueOrNull;
      if (timings != null) {
        final nextUnanswered = await PrayerTrackingService.checkUnansweredPrayerForToday(db, timings);
        if (nextUnanswered != null && mounted) {
          await Future.delayed(const Duration(milliseconds: 250));
          if (mounted) {
            PendingPrayerDialog.show(
              context,
              prayerName: nextUnanswered.prayerName,
              dateStr: nextUnanswered.dateStr,
              onAnswered: widget.onAnswered,
            );
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Center(
          child: ScaleTransition(
            scale: _scaleAnim,
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Dialog(
                backgroundColor: Colors.transparent,
                insetPadding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  width: 320,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: colors.cardBackground,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: colors.borderStroke.withValues(alpha: 0.5),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Icon Badge
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.accent.withValues(alpha: isDark ? 0.2 : 0.12),
                          border: Border.all(
                            color: colors.accent.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          '🕌',
                          style: TextStyle(fontSize: 30),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Title
                      Text(
                        '${widget.prayerName} Namazı',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: colors.primaryText,
                          letterSpacing: -0.3,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),

                      // Subtitle / Question
                      Text(
                        'Bu vakit namazınızı kıldınız mı?',
                        style: TextStyle(
                          fontSize: 14,
                          color: colors.secondaryTextAlt,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),

                      // Action Buttons
                      Row(
                        children: [
                          // Hayır Butonu (Kırmızı Çerçeveli)
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isSubmitting ? null : () => _handleAnswer(false),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFFF5252),
                                side: const BorderSide(
                                  color: Color(0xFFFF5252),
                                  width: 1.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 13),
                              ),
                              child: const Text(
                                'Hayır, kılmadım',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Evet Butonu (Yeşil Dolgulu)
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isSubmitting ? null : () => _handleAnswer(true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2E7D32),
                                foregroundColor: Colors.white,
                                elevation: 4,
                                shadowColor: const Color(0xFF2E7D32).withValues(alpha: 0.4),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 13),
                              ),
                              child: const Text(
                                'Evet, kıldım',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
