import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/database_provider.dart';
import '../../../../core/services/prayer_tracking_service.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../providers/prayer_providers.dart';

class BulkKazaPromptDialog extends ConsumerStatefulWidget {
  final List<String> olderDates;

  const BulkKazaPromptDialog({
    super.key,
    required this.olderDates,
  });

  /// Shows the bulk kaza prompt dialog for dates > 3 days ago.
  static Future<void> show(
    BuildContext context, {
    required List<String> olderDates,
  }) async {
    if (olderDates.isEmpty) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (ctx) => BulkKazaPromptDialog(olderDates: olderDates),
    );
  }

  @override
  ConsumerState<BulkKazaPromptDialog> createState() => _BulkKazaPromptDialogState();
}

class _BulkKazaPromptDialogState extends ConsumerState<BulkKazaPromptDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  bool _isStepTwo = false;
  bool _isSubmitting = false;

  static const List<String> _kazaPrayerTypes = [
    'Sabah',
    'Öğle',
    'İkindi',
    'Akşam',
    'Yatsı',
    'Vitir',
  ];

  static const Map<String, (String icon, String color)> _kazaPrayerMeta = {
    'Sabah': ('🌙', '#C1D9F9'),
    'Öğle': ('☀️', '#F7D6A7'),
    'İkindi': ('🌤️', '#F3B29B'),
    'Akşam': ('🌆', '#D0C4DF'),
    'Yatsı': ('🌃', '#E1C5ED'),
    'Vitir': ('✨', '#F4E2C7'),
  };

  final Map<String, int> _kazaCounts = {};

  @override
  void initState() {
    super.initState();
    // Default initial counter to the number of missing days
    for (final p in _kazaPrayerTypes) {
      _kazaCounts[p] = widget.olderDates.length;
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

  Future<void> _handleRejectOlderDays() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      final db = ref.read(databaseProvider);
      await PrayerTrackingService.resolveOlderDaysAsCompleted(db, widget.olderDates);

      // Invalidate providers
      ref.invalidate(pendingPastDaysProvider);
      ref.invalidate(todayPrayersProvider);

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    } catch (e) {
      debugPrint('[BulkKazaPromptDialog] Reject error: $e');
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _handleSaveBulkKaza() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      final db = ref.read(databaseProvider);
      await PrayerTrackingService.applyBulkKazaForOlderDays(
        db,
        widget.olderDates,
        _kazaCounts,
      );

      // Invalidate providers
      ref.invalidate(kazaPrayersStreamProvider);
      ref.invalidate(kazaSummaryProvider);
      ref.invalidate(pendingPastDaysProvider);
      ref.invalidate(todayPrayersProvider);

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    } catch (e) {
      debugPrint('[BulkKazaPromptDialog] Save bulk kaza error: $e');
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                  padding: const EdgeInsets.all(22),
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
                  child: AnimatedCrossFade(
                    duration: const Duration(milliseconds: 250),
                    crossFadeState: _isStepTwo ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                    firstChild: _buildStepOne(colors, isDark),
                    secondChild: _buildStepTwo(colors, isDark),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Step 1: Initial Yes / No question
  Widget _buildStepOne(AppThemeColors colors, bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Badge Icon
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.accent.withValues(alpha: isDark ? 0.25 : 0.14),
            border: Border.all(
              color: colors.accent.withValues(alpha: 0.35),
              width: 1.2,
            ),
          ),
          alignment: Alignment.center,
          child: const Text('⏳', style: TextStyle(fontSize: 26)),
        ),
        const SizedBox(height: 16),

        // Title
        Text(
          'Eski Günler Tespit Edildi',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: colors.primaryText,
            letterSpacing: -0.3,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),

        // Description
        Text(
          '3 günden daha eski (${widget.olderDates.length} gün) eksik kayıtlarınız bulunmaktadır.\n\nBu günler için kaza borcu eklemek ister misiniz?',
          style: TextStyle(
            fontSize: 13.5,
            color: colors.secondaryText,
            height: 1.45,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),

        // Action Buttons: Hayır & Evet
        Row(
          children: [
            // Hayır Butonu (Eski günleri kılındı sayıp kapatır)
            Expanded(
              child: OutlinedButton(
                onPressed: _isSubmitting ? null : _handleRejectOlderDays,
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.secondaryText,
                  side: BorderSide(
                    color: colors.borderStroke.withValues(alpha: 0.6),
                    width: 1.2,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                child: const Text(
                  'Hayır, Ekleme',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Evet Butonu (Sayaç ekranına geçer)
            Expanded(
              child: ElevatedButton(
                onPressed: _isSubmitting
                    ? null
                    : () {
                        setState(() => _isStepTwo = true);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.accent,
                  foregroundColor: colors.accentText,
                  elevation: 3,
                  shadowColor: colors.accent.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                child: const Text(
                  'Evet, Kaza Ekle',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Step 2: Configure +/- per prayer
  Widget _buildStepTwo(AppThemeColors colors, bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, size: 20),
              onPressed: () => setState(() => _isStepTwo = false),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Toplu Kaza Ekle',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: colors.primaryText,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Her vakit için eklemek istediğiniz miktarı ayarlayabilirsiniz:',
          style: TextStyle(
            fontSize: 12,
            color: colors.secondaryTextAlt,
          ),
        ),
        const SizedBox(height: 12),

        // List of + / - counters for each prayer
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            itemCount: _kazaPrayerTypes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final prayer = _kazaPrayerTypes[index];
              final count = _kazaCounts[prayer] ?? 0;
              final meta = _kazaPrayerMeta[prayer] ?? ('🕌', '#D4A574');

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: colors.cardBackgroundAlt.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colors.borderStroke.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Text(meta.$1, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        prayer,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: colors.primaryText,
                        ),
                      ),
                    ),
                    // Decrement Button
                    _buildStepperBtn(
                      icon: Icons.remove_rounded,
                      onTap: count > 0
                          ? () => setState(() => _kazaCounts[prayer] = count - 1)
                          : null,
                      colors: colors,
                    ),
                    // Count Badge
                    Container(
                      constraints: const BoxConstraints(minWidth: 36),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      alignment: Alignment.center,
                      child: Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: count > 0 ? colors.accent : colors.secondaryTextAlt,
                        ),
                      ),
                    ),
                    // Increment Button
                    _buildStepperBtn(
                      icon: Icons.add_rounded,
                      onTap: () => setState(() => _kazaCounts[prayer] = count + 1),
                      colors: colors,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),

        // Submit Button
        ElevatedButton(
          onPressed: _isSubmitting ? null : _handleSaveBulkKaza,
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
                  'Kaza Borcuna Ekle ve Tamamla',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildStepperBtn({
    required IconData icon,
    required VoidCallback? onTap,
    required AppThemeColors colors,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: colors.streakBg.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: colors.borderStroke.withValues(alpha: 0.4),
              width: 0.8,
            ),
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 16,
            color: onTap != null ? colors.primaryText : colors.secondaryTextAlt.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}
