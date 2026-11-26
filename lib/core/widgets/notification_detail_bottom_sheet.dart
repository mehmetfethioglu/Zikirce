import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/router/app_deep_link_router.dart';
import '../../features/gamification/providers/gamification_providers.dart';
import '../../features/namaz_vakitleri/presentation/screens/fiqh_library_screen.dart';
import '../../features/namaz_vakitleri/presentation/widgets/prayer_notification_settings_sheet.dart';
import '../../features/namaz_vakitleri/providers/prayer_providers.dart';
import '../localization/app_localizations.dart';
import '../providers/database_provider.dart';
import '../services/haptic_service.dart';
import '../services/notification_db_service.dart';
import '../services/prayer_tracking_service.dart';
import '../theme/app_theme_colors.dart';

/// Presents the notification detail bottom sheet on top of the active target route.
class NotificationDetailBottomSheet {
  const NotificationDetailBottomSheet._();

  static Future<void> show(
    BuildContext context, {
    required NotificationDetailSpec spec,
  }) async {
    if (!context.mounted) return;

    switch (spec.kind) {
      case NotificationDetailKind.specialSpiritual:
        await PrayerNotificationSettingsSheet.showVirtueSheet(
          context,
          initialTab: spec.spiritualVirtueTab ?? 'feraciye',
        );
        return;
      case NotificationDetailKind.prayerTimeFarz:
        if (spec.farzId != null) {
          final shown = await FiqhLibraryScreen.showFarzDetailSheet(
            context,
            farzId: spec.farzId!,
            prayerName: spec.prayerName,
          );
          if (shown || !context.mounted) return;
        }
        await _showInfoSheet(context, spec);
        return;
      case NotificationDetailKind.prayerQuestion:
        await showModalBottomSheet<void>(
          context: context,
          useRootNavigator: true,
          useSafeArea: true,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _PrayerQuestionBottomSheet(
            prayerName: spec.prayerName ?? 'Namaz',
            dateStr: spec.dateStr,
          ),
        );
        return;
      case NotificationDetailKind.quranReminder:
      case NotificationDetailKind.quranAudioDownload:
      case NotificationDetailKind.zikirReminder:
      case NotificationDetailKind.kazaReminder:
      case NotificationDetailKind.irfanReminder:
      case NotificationDetailKind.statsReminder:
        await _showInfoSheet(context, spec);
        return;
    }
  }

  static Future<void> _showInfoSheet(
    BuildContext context,
    NotificationDetailSpec spec,
  ) async {
    HapticService.selectionClick();
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NotificationInfoBottomSheet(spec: spec),
    );
  }
}

class _SheetHeaderHandle extends StatelessWidget {
  final Color borderColor;

  const _SheetHeaderHandle({required this.borderColor});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: borderColor,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _PrayerQuestionBottomSheet extends ConsumerStatefulWidget {
  final String prayerName;
  final String? dateStr;

  const _PrayerQuestionBottomSheet({
    required this.prayerName,
    this.dateStr,
  });

  @override
  ConsumerState<_PrayerQuestionBottomSheet> createState() =>
      _PrayerQuestionBottomSheetState();
}

class _PrayerQuestionBottomSheetState
    extends ConsumerState<_PrayerQuestionBottomSheet> {
  bool _isSubmitting = false;

  String get _effectiveDateStr {
    final trimmed = widget.dateStr?.trim() ?? '';
    if (trimmed.isNotEmpty) return trimmed;
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _handleAnswer(bool answeredYes) async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      final db = ref.read(databaseProvider);
      await PrayerTrackingService.answerPrayerQuestion(
        db,
        _effectiveDateStr,
        widget.prayerName,
        answeredYes,
      );
      ref.invalidate(todayPrayersProvider);
      ref.invalidate(kazaPrayersStreamProvider);
      ref.invalidate(kazaSummaryProvider);
      ref.invalidate(namazStreakProvider);
      ref.invalidate(dailyGoalsStatusProvider);
    } catch (e) {
      debugPrint('[_PrayerQuestionBottomSheet] answer error: $e');
    } finally {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isTr = context.l10n.isTurkish;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.78,
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      decoration: BoxDecoration(
        color: colors.bottomSheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        bottom: true,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SheetHeaderHandle(borderColor: colors.borderStroke),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: colors.accent.withValues(alpha: isDark ? 0.2 : 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _effectiveDateStr,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: colors.accent,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: colors.secondaryText),
                    onPressed:
                        _isSubmitting ? null : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Center(
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.accent.withValues(alpha: isDark ? 0.2 : 0.12),
                    border: Border.all(
                      color: colors.accent.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const Text('🕌', style: TextStyle(fontSize: 28)),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                isTr
                    ? '${widget.prayerName} Namazı'
                    : '${widget.prayerName} Prayer',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: colors.primaryText,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isTr
                    ? '${widget.prayerName} namazınızı kıldınız mı?'
                    : 'Have you performed your ${widget.prayerName} prayer?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: colors.secondaryTextAlt,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _isSubmitting ? null : () => _handleAnswer(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFFF5252),
                        side: const BorderSide(
                          color: Color(0xFFFF5252),
                          width: 1.5,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        isTr ? 'Hayır, Kazaya Ekle' : 'No, Add to Kaza',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed:
                          _isSubmitting ? null : () => _handleAnswer(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        isTr ? 'Evet, Kıldım' : 'Yes, Prayed',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationSheetContent {
  final String badge;
  final String icon;
  final String title;
  final String body;
  final String ctaLabel;
  final bool allowCopy;

  const _NotificationSheetContent({
    required this.badge,
    required this.icon,
    required this.title,
    required this.body,
    required this.ctaLabel,
    this.allowCopy = false,
  });
}

class _NotificationInfoBottomSheet extends ConsumerWidget {
  final NotificationDetailSpec spec;

  const _NotificationInfoBottomSheet({required this.spec});

  _NotificationSheetContent _resolveContent(bool isTr) {
    switch (spec.kind) {
      case NotificationDetailKind.quranReminder:
        return _NotificationSheetContent(
          badge: isTr ? 'Kur\'an-ı Kerim' : 'Qur\'an',
          icon: '📖',
          title: isTr
              ? 'Günlük Kur\'an Hatırlatması'
              : 'Daily Qur\'an Reminder',
          body: isTr
              ? 'Günün Kur\'an tilavetini tamamlayıp manevi hedefine bir adım daha yaklaş.'
              : 'Complete your daily Qur\'an recitation and move closer to your spiritual goal.',
          ctaLabel: isTr ? 'Kur\'an Sayfasına Geç' : 'Go to Qur\'an Page',
        );
      case NotificationDetailKind.quranAudioDownload:
        return _NotificationSheetContent(
          badge: isTr ? 'Kur\'an Ses Kütüphanesi' : 'Qur\'an Audio Library',
          icon: '🎧',
          title: spec.customTitle ??
              (isTr ? 'Kur\'an Ses Dosyaları' : 'Qur\'an Audio Files'),
          body: spec.customBody ??
              (isTr
                  ? 'İndirilen Kur\'an ses dosyalarını Kur\'an sayfasından çevrimdışı dinleyebilirsiniz.'
                  : 'You can listen to downloaded Qur\'an audio files offline from the Qur\'an page.'),
          ctaLabel: isTr ? 'Kur\'an Sayfasına Geç' : 'Go to Qur\'an Page',
        );
      case NotificationDetailKind.zikirReminder:
        final item = spec.reminderItemId != null
            ? NotificationDbService.getNotificationById(spec.reminderItemId!)
            : null;
        return _NotificationSheetContent(
          badge: item != null && item.category.trim().isNotEmpty
              ? item.category.trim()
              : (isTr ? 'Zikir' : 'Dhikr'),
          icon: '📿',
          title: item != null && item.title.trim().isNotEmpty
              ? item.title.trim()
              : (isTr
                  ? 'Günlük Zikir Hatırlatması'
                  : 'Daily Dhikr Reminder'),
          body: item != null && item.content.trim().isNotEmpty
              ? item.content.trim()
              : (isTr
                  ? 'Günlük zikir hedefini tamamlayıp manevi serini koru.'
                  : 'Complete your daily dhikr goal and keep your spiritual streak alive.'),
          ctaLabel: isTr ? 'Zikre Başla' : 'Start Dhikr',
          allowCopy: true,
        );
      case NotificationDetailKind.kazaReminder:
        return _NotificationSheetContent(
          badge: isTr ? 'Namaz & Kaza' : 'Prayer & Kaza',
          icon: '🕌',
          title:
              isTr ? 'Kaza Namazı Hatırlatması' : 'Kaza Prayer Reminder',
          body: isTr
              ? 'Kaza borçlarınızı düzenli olarak takip edip namaz sayfasından güncelleyebilirsiniz.'
              : 'Track and update your remaining kaza prayers right from the prayers page.',
          ctaLabel: isTr ? 'Namaz Sayfasına Geç' : 'Go to Prayers Page',
        );
      case NotificationDetailKind.prayerTimeFarz:
        final pName = spec.prayerName?.trim();
        return _NotificationSheetContent(
          badge: isTr ? 'Vakit Bildirimi' : 'Prayer Time',
          icon: '🕌',
          title: (pName != null && pName.isNotEmpty)
              ? (isTr ? '$pName Vakti' : '$pName Time')
              : (isTr ? 'Namaz Vakti' : 'Prayer Time'),
          body: isTr
              ? 'Namaz vakti girdi. Vakit bilgilerini ve namaz takibini bu sayfadan görüntüleyebilirsiniz.'
              : 'Prayer time has arrived. View timings and track your prayers on this page.',
          ctaLabel: isTr ? 'Namaz Sayfasına Geç' : 'Go to Prayers Page',
        );
      case NotificationDetailKind.irfanReminder:
        return _NotificationSheetContent(
          badge: isTr ? 'İrfan Meydanı' : 'Irfan Plaza',
          icon: '✨',
          title:
              isTr ? 'İrfan Meydanı Hatırlatması' : 'Irfan Plaza Reminder',
          body: isTr
              ? 'Günün İrfan halkasını ve 32 Farz ilmihal okumalarını tamamlamak için hazırsınız.'
              : 'You are ready to continue today\'s Irfan quiz and 32 Farz readings.',
          ctaLabel: isTr ? 'İrfan Meydanına Geç' : 'Go to Irfan Plaza',
        );
      case NotificationDetailKind.statsReminder:
        return _NotificationSheetContent(
          badge: isTr ? 'İstatistikler' : 'Statistics',
          icon: '📊',
          title: isTr
              ? 'İbadet İstatistik Özeti'
              : 'Worship Statistics Summary',
          body: isTr
              ? 'Günlük ve haftalık ibadet ilerlemenizi detaylı istatistikler ekranından inceleyebilirsiniz.'
              : 'Inspect your daily and weekly worship progress on the detailed statistics page.',
          ctaLabel: isTr ? 'İstatistikleri İncele' : 'View Statistics',
        );
      case NotificationDetailKind.prayerQuestion:
      case NotificationDetailKind.specialSpiritual:
        return _NotificationSheetContent(
          badge: isTr ? 'Bildirim Detayı' : 'Notification Detail',
          icon: '🔔',
          title: isTr ? 'Hatırlatma' : 'Reminder',
          body: isTr
              ? 'İlgili bölüm açıldı.'
              : 'The related section has been opened.',
          ctaLabel: isTr ? 'Tamam' : 'Done',
        );
    }
  }

  void _copyContent(BuildContext context, _NotificationSheetContent content) {
    final text = '${content.title}\n\n${content.body}';
    Clipboard.setData(ClipboardData(text: text));
    HapticService.selectionClick();
    final isTr = context.l10n.isTurkish;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isTr ? 'Hatırlatma metni kopyalandı' : 'Reminder text copied',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final isTr = context.l10n.isTurkish;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final content = _resolveContent(isTr);

    final goalsStatus = (spec.kind == NotificationDetailKind.quranReminder ||
            spec.kind == NotificationDetailKind.zikirReminder)
        ? ref.watch(dailyGoalsStatusProvider.select((a) => a.valueOrNull))
        : null;

    final remainingKaza = spec.kind == NotificationDetailKind.kazaReminder
        ? ref.watch(kazaSummaryProvider.select((s) => s.totalRemaining))
        : null;

    String? goalText;
    if (spec.kind == NotificationDetailKind.quranReminder &&
        goalsStatus != null) {
      goalText = isTr
          ? 'Bugünkü Hedef: ${goalsStatus.todayKuranPages} / ${goalsStatus.kuranGoal} sayfa'
          : 'Today\'s Goal: ${goalsStatus.todayKuranPages} / ${goalsStatus.kuranGoal} pages';
    } else if (spec.kind == NotificationDetailKind.zikirReminder &&
        goalsStatus != null) {
      goalText = isTr
          ? 'Bugünkü Hedef: ${goalsStatus.todayZikirCount} / ${goalsStatus.zikirGoal} zikir'
          : 'Today\'s Goal: ${goalsStatus.todayZikirCount} / ${goalsStatus.zikirGoal} dhikr';
    } else if (spec.kind == NotificationDetailKind.kazaReminder &&
        remainingKaza != null) {
      goalText = isTr
          ? 'Toplam Kalan Kaza: $remainingKaza vakit'
          : 'Remaining Kaza: $remainingKaza prayers';
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      decoration: BoxDecoration(
        color: colors.bottomSheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        bottom: true,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SheetHeaderHandle(borderColor: colors.borderStroke),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: colors.accent.withValues(alpha: isDark ? 0.2 : 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      content.badge,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: colors.accent,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (content.allowCopy)
                    IconButton(
                      icon: Icon(
                        Icons.copy_rounded,
                        color: colors.secondaryText,
                        size: 20,
                      ),
                      onPressed: () => _copyContent(context, content),
                      tooltip: isTr ? 'Metni Kopyala' : 'Copy Text',
                    ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: colors.secondaryText),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: colors.accent.withValues(alpha: isDark ? 0.2 : 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child:
                        Text(content.icon, style: const TextStyle(fontSize: 24)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      content.title,
                      style: TextStyle(
                        fontSize: 18.5,
                        fontWeight: FontWeight.bold,
                        color: colors.primaryText,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.cardBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.borderStroke),
                ),
                child: Text(
                  content.body,
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 1.5,
                    color: colors.primaryText,
                  ),
                ),
              ),
              if (goalText != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: colors.accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colors.accent.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.track_changes_rounded,
                        size: 18,
                        color: colors.accent,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          goalText,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colors.primaryText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.accent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  content.ctaLabel,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
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
