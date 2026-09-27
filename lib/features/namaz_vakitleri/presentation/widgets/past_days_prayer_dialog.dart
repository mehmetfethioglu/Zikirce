import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/database_provider.dart';
import '../../../../core/services/prayer_tracking_service.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../providers/prayer_providers.dart';

class PastDaysPrayerDialog extends ConsumerStatefulWidget {
  final PastUnansweredDay day;

  const PastDaysPrayerDialog({
    super.key,
    required this.day,
  });

  /// Shows the past day prayer confirmation dialog.
  /// Returns `true` if saved, `false` if user chose "Daha Sonra" / postponed, `null` if cancelled.
  static Future<bool?> show(
    BuildContext context, {
    required PastUnansweredDay day,
  }) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (ctx) => PastDaysPrayerDialog(day: day),
    );
  }

  @override
  ConsumerState<PastDaysPrayerDialog> createState() => _PastDaysPrayerDialogState();
}

class _PastDaysPrayerDialogState extends ConsumerState<PastDaysPrayerDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  final Map<String, bool> _selectedPrayers = {};
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Default all unanswered prayers to false (uncompleted)
    for (final p in widget.day.unansweredPrayers) {
      _selectedPrayers[p] = false;
    }

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
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

  void _toggleAll(bool selectAll) {
    setState(() {
      for (final p in widget.day.unansweredPrayers) {
        _selectedPrayers[p] = selectAll;
      }
    });
  }

  Future<void> _handleSave() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      final db = ref.read(databaseProvider);
      await PrayerTrackingService.savePastDayPrayerAnswers(
        db,
        widget.day.dateStr,
        _selectedPrayers,
      );

      // Invalidate providers
      ref.invalidate(todayPrayersProvider);
      ref.invalidate(kazaPrayersStreamProvider);
      ref.invalidate(kazaSummaryProvider);
      ref.invalidate(namazStreakProvider);
      ref.invalidate(pendingPastDaysProvider);

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(true);
      }
    } catch (e) {
      debugPrint('[PastDaysPrayerDialog] Save error: $e');
      setState(() => _isSubmitting = false);
    }
  }

  void _handleDefer() {
    Navigator.of(context, rootNavigator: true).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allSelected = widget.day.unansweredPrayers.every((p) => _selectedPrayers[p] == true);

    return PopScope(
      canPop: false,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Center(
          child: ScaleTransition(
            scale: _scaleAnim,
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Dialog(
                backgroundColor: Colors.transparent,
                insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
                child: Container(
                  width: 360,
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.85,
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  decoration: BoxDecoration(
                    color: colors.cardBackground,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: colors.borderStroke.withValues(alpha: 0.5),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.18),
                        blurRadius: 28,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header Badge & Date
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: colors.accent.withValues(alpha: isDark ? 0.25 : 0.14),
                              border: Border.all(
                                color: colors.accent.withValues(alpha: 0.35),
                                width: 1.2,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: const Text(
                              '📅',
                              style: TextStyle(fontSize: 22),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.day.formattedDate,
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: colors.primaryText,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Cevapsız Vakit Namazları',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: colors.secondaryTextAlt,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Explanation note
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: colors.streakBg.withValues(alpha: isDark ? 0.3 : 0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: colors.borderStroke.withValues(alpha: 0.3),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 16,
                              color: colors.accent,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Kıldığınız vakitleri işaretleyiniz. İşaretlenmeyenler kaza borcunuza eklenecektir.',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: colors.secondaryText,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // "Hepsini Kıldım" Quick Toggle
                      Align(
                        alignment: Alignment.centerRight,
                        child: InkWell(
                          onTap: () => _toggleAll(!allSelected),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  allSelected
                                      ? Icons.check_box_rounded
                                      : Icons.check_box_outline_blank_rounded,
                                  size: 17,
                                  color: colors.accent,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  allSelected ? 'Tümünü Kaldır' : 'Hepsini Kıldım',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: colors.accent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Prayer List (Scrollable if many)
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: widget.day.unansweredPrayers.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final prayer = widget.day.unansweredPrayers[index];
                            final isChecked = _selectedPrayers[prayer] ?? false;
                            final meta = PrayerTrackingService.prayerMeta[prayer] ?? ('🕌', '#D4A574');

                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _selectedPrayers[prayer] = !isChecked;
                                  });
                                },
                                borderRadius: BorderRadius.circular(14),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isChecked
                                        ? const Color(0xFF2E7D32).withValues(alpha: isDark ? 0.18 : 0.1)
                                        : colors.cardBackgroundAlt.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isChecked
                                          ? const Color(0xFF2E7D32).withValues(alpha: 0.5)
                                          : colors.borderStroke.withValues(alpha: 0.35),
                                      width: isChecked ? 1.4 : 1.0,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      // Emoji Icon
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: colors.accent.withValues(alpha: 0.1),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          meta.$1,
                                          style: const TextStyle(fontSize: 18),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      // Prayer Name & Status
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '$prayer Namazı',
                                              style: TextStyle(
                                                fontSize: 14.5,
                                                fontWeight: FontWeight.w600,
                                                color: colors.primaryText,
                                              ),
                                            ),
                                            const SizedBox(height: 1),
                                            Text(
                                              isChecked ? 'Kılındı' : 'Kılınmadı (Kazaya eklenecek)',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: isChecked ? FontWeight.w600 : FontWeight.normal,
                                                color: isChecked
                                                    ? const Color(0xFF2E7D32)
                                                    : colors.secondaryTextAlt,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Custom Checkbox
                                      AnimatedContainer(
                                        duration: const Duration(milliseconds: 180),
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isChecked
                                              ? const Color(0xFF2E7D32)
                                              : Colors.transparent,
                                          border: Border.all(
                                            color: isChecked
                                                ? const Color(0xFF2E7D32)
                                                : colors.secondaryTextAlt.withValues(alpha: 0.6),
                                            width: 2,
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: isChecked
                                            ? const Icon(
                                                Icons.check_rounded,
                                                size: 16,
                                                color: Colors.white,
                                              )
                                            : null,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Action Buttons: Kaydet & Daha Sonra
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ElevatedButton(
                            onPressed: _isSubmitting ? null : _handleSave,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2E7D32),
                              foregroundColor: Colors.white,
                              elevation: 3,
                              shadowColor: const Color(0xFF2E7D32).withValues(alpha: 0.4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Kaydet ve Tamamla',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 6),
                          TextButton(
                            onPressed: _isSubmitting ? null : _handleDefer,
                            style: TextButton.styleFrom(
                              foregroundColor: colors.secondaryTextAlt,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            child: const Text(
                              'Daha Sonra Hatırlat',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
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
