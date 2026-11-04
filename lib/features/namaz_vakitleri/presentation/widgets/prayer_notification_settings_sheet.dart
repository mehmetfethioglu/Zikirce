import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/battery_optimization_service.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../../core/services/local_notification_service.dart';
import '../../../../core/services/sound_pool_service.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/utils/quran_word_highlighter.dart';
import '../../../kuran/presentation/widgets/zikirce_ayah_stop_marker.dart';
import '../../../kuran/providers/kuran_providers.dart';
import '../../../settings/providers/settings_provider.dart';

class PrayerNotificationSettingsSheet extends ConsumerWidget {
  const PrayerNotificationSettingsSheet({super.key});

  static Future<void> show(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const PrayerNotificationSettingsSheet(),
    );
    await SoundPoolService.stopPreview();
  }

  static Future<void> showVirtueSheet(BuildContext context, {String initialTab = 'feraciye'}) async {
    await showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SpiritualVirtueSheet(initialTab: initialTab),
    );
    await SoundPoolService.stopPreview();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);

    final isMasterEnabled = settings.isNamazReminderEnabled;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: colors.bottomSheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        bottom: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.borderStroke,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: colors.accent.withValues(alpha: isDark ? 0.2 : 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: const Text('🔔', style: TextStyle(fontSize: 18)),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      l10n.isTurkish ? 'Bildirim Ayarları' : 'Notification Settings',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colors.primaryText,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  color: colors.secondaryText,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Flexible(
              child: ListView(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                children: [
                  // 1. GENEL MASTER SWITCH (Ana Aç/Kapa Şalteri)
                  Container(
                    decoration: BoxDecoration(
                      color: colors.cardBackground,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isMasterEnabled
                            ? colors.accent.withValues(alpha: 0.5)
                            : colors.borderStroke,
                        width: 1.0,
                      ),
                    ),
                    child: SwitchListTile(
                      secondary: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: isMasterEnabled
                              ? colors.accent.withValues(alpha: isDark ? 0.25 : 0.12)
                              : colors.pageBackground,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          isMasterEnabled ? '🔔' : '🔕',
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                      title: Text(
                        l10n.isTurkish ? 'Namaz Vakti Bildirimleri' : 'Prayer Time Notifications',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: colors.primaryText,
                        ),
                      ),
                      subtitle: Text(
                        isMasterEnabled
                            ? (l10n.isTurkish
                                ? 'Vakit girişlerinde ve hatırlatmalarda bildirim alırsınız'
                                : 'Receive notifications at prayer times')
                            : (l10n.isTurkish
                                ? 'Tüm namaz vakti bildirimleri kapalı'
                                : 'All prayer notifications are silenced'),
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isMasterEnabled ? colors.accent : colors.secondaryTextAlt,
                        ),
                      ),
                      value: isMasterEnabled,
                      activeThumbColor: colors.accent,
                      onChanged: (val) {
                        HapticService.selectionClick();
                        settingsNotifier.toggleNamazReminder(val);
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2. DETAYLAR (Master Switch kapalıyken soluklaşır ve tıklanamaz olur)
                  AnimatedOpacity(
                    opacity: isMasterEnabled ? 1.0 : 0.45,
                    duration: const Duration(milliseconds: 200),
                    child: IgnorePointer(
                      ignoring: !isMasterEnabled,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Section: Bildirim Sesi Seçimi (Ezan, Salâ, Feraciye, Kumru, Bülbül)
                          Text(
                            l10n.isTurkish
                                ? 'VAKİT BİLDİRİM SESİ'
                                : 'PRAYER NOTIFICATION SOUND',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: colors.secondaryTextAlt,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildPrayerSoundPickerCard(
                            context: context,
                            settings: settings,
                            settingsNotifier: settingsNotifier,
                            colors: colors,
                            isTr: l10n.isTurkish,
                          ),
                          const SizedBox(height: 20),

                          // Section: Vakit Namazları Bildirimleri
                          Text(
                            l10n.isTurkish
                                ? 'VAKİT GİRİŞ BİLDİRİMLERİ VE SAAT AYARI'
                                : 'PRAYER ENTRY NOTIFICATIONS & TIMING',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: colors.secondaryTextAlt,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),

                          Container(
                            decoration: BoxDecoration(
                              color: colors.cardBackground,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: colors.borderStroke, width: 0.8),
                            ),
                            child: Column(
                              children: [
                                _buildPrayerTimingSwitchTile(
                                  context: context,
                                  prayerKey: 'İmsak',
                                  title: l10n.isTurkish ? 'İmsak' : 'Fajr (Imsak)',
                                  emoji: '🌙',
                                  value: settings.prayerNotifications['İmsak'] ?? true,
                                  offsetMins: settings.prayerOffsets['İmsak'] ?? 0,
                                  customTime: settings.prayerCustomTimes['İmsak'] ?? '',
                                  onChanged: (val) {
                                    HapticService.selectionClick();
                                    settingsNotifier.togglePrayerNotification('İmsak', val);
                                  },
                                  onTimingSelected: (mins, custom) {
                                    settingsNotifier.setPrayerTiming('İmsak', offsetMinutes: mins, customTime: custom);
                                  },
                                  colors: colors,
                                  isTr: l10n.isTurkish,
                                ),
                                const Divider(height: 1, indent: 48),
                                _buildPrayerTimingSwitchTile(
                                  context: context,
                                  prayerKey: 'Güneş',
                                  title: l10n.isTurkish ? 'Güneş' : 'Sunrise',
                                  emoji: '🌅',
                                  value: settings.prayerNotifications['Güneş'] ?? true,
                                  offsetMins: settings.prayerOffsets['Güneş'] ?? 0,
                                  customTime: settings.prayerCustomTimes['Güneş'] ?? '',
                                  onChanged: (val) {
                                    HapticService.selectionClick();
                                    settingsNotifier.togglePrayerNotification('Güneş', val);
                                  },
                                  onTimingSelected: (mins, custom) {
                                    settingsNotifier.setPrayerTiming('Güneş', offsetMinutes: mins, customTime: custom);
                                  },
                                  colors: colors,
                                  isTr: l10n.isTurkish,
                                ),
                                const Divider(height: 1, indent: 48),
                                _buildPrayerTimingSwitchTile(
                                  context: context,
                                  prayerKey: 'Öğle',
                                  title: l10n.isTurkish ? 'Öğle' : 'Dhuhr',
                                  emoji: '☀️',
                                  value: settings.prayerNotifications['Öğle'] ?? true,
                                  offsetMins: settings.prayerOffsets['Öğle'] ?? 0,
                                  customTime: settings.prayerCustomTimes['Öğle'] ?? '',
                                  onChanged: (val) {
                                    HapticService.selectionClick();
                                    settingsNotifier.togglePrayerNotification('Öğle', val);
                                  },
                                  onTimingSelected: (mins, custom) {
                                    settingsNotifier.setPrayerTiming('Öğle', offsetMinutes: mins, customTime: custom);
                                  },
                                  colors: colors,
                                  isTr: l10n.isTurkish,
                                ),
                                const Divider(height: 1, indent: 48),
                                _buildPrayerTimingSwitchTile(
                                  context: context,
                                  prayerKey: 'İkindi',
                                  title: l10n.isTurkish ? 'İkindi' : 'Asr',
                                  emoji: '🌤️',
                                  value: settings.prayerNotifications['İkindi'] ?? true,
                                  offsetMins: settings.prayerOffsets['İkindi'] ?? 0,
                                  customTime: settings.prayerCustomTimes['İkindi'] ?? '',
                                  onChanged: (val) {
                                    HapticService.selectionClick();
                                    settingsNotifier.togglePrayerNotification('İkindi', val);
                                  },
                                  onTimingSelected: (mins, custom) {
                                    settingsNotifier.setPrayerTiming('İkindi', offsetMinutes: mins, customTime: custom);
                                  },
                                  colors: colors,
                                  isTr: l10n.isTurkish,
                                ),
                                const Divider(height: 1, indent: 48),
                                _buildPrayerTimingSwitchTile(
                                  context: context,
                                  prayerKey: 'Akşam',
                                  title: l10n.isTurkish ? 'Akşam' : 'Maghrib',
                                  emoji: '🌆',
                                  value: settings.prayerNotifications['Akşam'] ?? true,
                                  offsetMins: settings.prayerOffsets['Akşam'] ?? 0,
                                  customTime: settings.prayerCustomTimes['Akşam'] ?? '',
                                  onChanged: (val) {
                                    HapticService.selectionClick();
                                    settingsNotifier.togglePrayerNotification('Akşam', val);
                                  },
                                  onTimingSelected: (mins, custom) {
                                    settingsNotifier.setPrayerTiming('Akşam', offsetMinutes: mins, customTime: custom);
                                  },
                                  colors: colors,
                                  isTr: l10n.isTurkish,
                                ),
                                const Divider(height: 1, indent: 48),
                                _buildPrayerTimingSwitchTile(
                                  context: context,
                                  prayerKey: 'Yatsı',
                                  title: l10n.isTurkish ? 'Yatsı' : 'Isha',
                                  emoji: '🌃',
                                  value: settings.prayerNotifications['Yatsı'] ?? true,
                                  offsetMins: settings.prayerOffsets['Yatsı'] ?? 0,
                                  customTime: settings.prayerCustomTimes['Yatsı'] ?? '',
                                  onChanged: (val) {
                                    HapticService.selectionClick();
                                    settingsNotifier.togglePrayerNotification('Yatsı', val);
                                  },
                                  onTimingSelected: (mins, custom) {
                                    settingsNotifier.setPrayerTiming('Yatsı', offsetMinutes: mins, customTime: custom);
                                  },
                                  colors: colors,
                                  isTr: l10n.isTurkish,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Section: Namazınızı Kıldınız mı? Hatırlatıcısı
                          Text(
                            l10n.isTurkish
                                ? 'NAMAZ TAKİP VE HATIRLATMA BİLDİRİMİ SAATİ'
                                : 'PRAYER TRACKING & REMINDER TIMING',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: colors.secondaryTextAlt,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),

                          Container(
                            decoration: BoxDecoration(
                              color: colors.cardBackground,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: colors.borderStroke, width: 0.8),
                            ),
                            child: Column(
                              children: [
                                SwitchListTile(
                                  secondary: const Text('🕌', style: TextStyle(fontSize: 20)),
                                  title: Text(
                                    l10n.isTurkish ? 'Namazınızı Kıldınız mı?' : 'Did you pray?',
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.bold,
                                      color: colors.primaryText,
                                    ),
                                  ),
                                  subtitle: Text(
                                    settings.kazaQuestionCustomTime.isNotEmpty
                                        ? (l10n.isTurkish
                                            ? 'Vakit çıkmadan ${settings.kazaQuestionMinutesBefore} dk önce (Yatsı: ${settings.kazaQuestionCustomTime}) hatırlatır.'
                                            : 'Reminds ${settings.kazaQuestionMinutesBefore} min before prayer ends (Isha: ${settings.kazaQuestionCustomTime}).')
                                        : (l10n.isTurkish
                                            ? 'Vakit çıkmadan ${settings.kazaQuestionMinutesBefore} dakika önce hatırlatır ve kaza takibini kolaylaştırır.'
                                            : 'Reminds ${settings.kazaQuestionMinutesBefore} minutes before prayer ends to facilitate tracking.'),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colors.secondaryTextAlt,
                                    ),
                                  ),
                                  value: settings.isKazaQuestionEnabled,
                                  activeThumbColor: colors.accent,
                                  onChanged: (val) {
                                    HapticService.selectionClick();
                                    settingsNotifier.toggleKazaQuestion(val);
                                  },
                                ),
                                if (settings.isKazaQuestionEnabled)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                                    child: Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: [
                                        ...[15, 30, 45, 60].map((mins) {
                                          final isSelected = settings.kazaQuestionMinutesBefore == mins;
                                          return InkWell(
                                            borderRadius: BorderRadius.circular(10),
                                            onTap: () {
                                              HapticService.selectionClick();
                                              settingsNotifier.setKazaQuestionTiming(minutesBefore: mins);
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: isSelected
                                                    ? colors.accent.withValues(alpha: 0.16)
                                                    : colors.pageBackground,
                                                borderRadius: BorderRadius.circular(10),
                                                border: Border.all(
                                                  color: isSelected ? colors.accent : colors.borderStroke,
                                                  width: isSelected ? 1.3 : 0.8,
                                                ),
                                              ),
                                              child: Text(
                                                l10n.isTurkish
                                                    ? '$mins dk önce'
                                                    : '$mins min before',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                                  color: isSelected ? colors.accent : colors.primaryText,
                                                ),
                                              ),
                                            ),
                                          );
                                        }),
                                        InkWell(
                                          borderRadius: BorderRadius.circular(10),
                                          onTap: () async {
                                            HapticService.selectionClick();
                                            int initH = 22;
                                            int initM = 0;
                                            if (settings.kazaQuestionCustomTime.contains(':')) {
                                              final p = settings.kazaQuestionCustomTime.split(':');
                                              initH = int.tryParse(p[0]) ?? 22;
                                              initM = int.tryParse(p[1]) ?? 0;
                                            }
                                            final picked = await showTimePicker(
                                              context: context,
                                              initialTime: TimeOfDay(hour: initH, minute: initM),
                                            );
                                            if (picked != null) {
                                              final hhmm =
                                                  '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                                              settingsNotifier.setKazaQuestionTiming(customTime: hhmm);
                                            }
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: settings.kazaQuestionCustomTime.isNotEmpty
                                                  ? colors.accent.withValues(alpha: 0.16)
                                                  : colors.pageBackground,
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(
                                                color: settings.kazaQuestionCustomTime.isNotEmpty
                                                    ? colors.accent
                                                    : colors.borderStroke,
                                                width: settings.kazaQuestionCustomTime.isNotEmpty ? 1.3 : 0.8,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.schedule_rounded,
                                                  size: 13,
                                                  color: settings.kazaQuestionCustomTime.isNotEmpty
                                                      ? colors.accent
                                                      : colors.secondaryTextAlt,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  settings.kazaQuestionCustomTime.isNotEmpty
                                                      ? (l10n.isTurkish
                                                          ? 'Yatsı: ${settings.kazaQuestionCustomTime}'
                                                          : 'Isha: ${settings.kazaQuestionCustomTime}')
                                                      : (l10n.isTurkish
                                                          ? 'Yatsı Saati'
                                                          : 'Isha Time'),
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: settings.kazaQuestionCustomTime.isNotEmpty
                                                        ? FontWeight.bold
                                                        : FontWeight.w500,
                                                    color: settings.kazaQuestionCustomTime.isNotEmpty
                                                        ? colors.accent
                                                        : colors.primaryText,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Section: Perşembe Feraciye Duası & Cuma/Perşembe Salâ Vakitleri
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  l10n.isTurkish
                                      ? 'CUMA GECESİ & CUMA SALÂ / FERACİYE VAKİTLERİ'
                                      : 'THURSDAY & FRIDAY FERACIYE / SALA RECITATIONS',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: colors.secondaryTextAlt,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              InkWell(
                                onTap: () {
                                  HapticService.selectionClick();
                                  showVirtueSheet(context);
                                },
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: colors.accent.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: colors.accent.withValues(alpha: 0.35),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text('📖', style: TextStyle(fontSize: 12)),
                                      const SizedBox(width: 4),
                                      Text(
                                        l10n.isTurkish ? 'Fazileti ve Anlamı' : 'Virtue & Meaning',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: colors.accent,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          _buildSpecialSpiritualSection(
                            context: context,
                            settings: settings,
                            settingsNotifier: settingsNotifier,
                            colors: colors,
                            isTr: l10n.isTurkish,
                          ),
                          const SizedBox(height: 16),

                          // Test Notification Button
                          OutlinedButton.icon(
                            onPressed: () async {
                              HapticService.selectionClick();
                              await LocalNotificationService.showTestNotification(
                                  sound: settings.selectedPrayerSound);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(l10n.isTurkish
                                        ? 'Test bildirimi gönderildi! 🔔 (${settings.selectedPrayerSound})'
                                        : 'Test notification sent! 🔔 (${settings.selectedPrayerSound})'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.notifications_active_outlined, size: 18),
                            label: Text(l10n.isTurkish ? 'Bildirimi Test Et' : 'Test Notification'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: colors.accent,
                              side: BorderSide(color: colors.accent.withValues(alpha: 0.4)),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ),
                    ),
                  ),

                  // Xiaomi / Android 14 Exact Alarm & Background Guide (Always accessible)
                  InkWell(
                    onTap: () async {
                      await BatteryOptimizationService.openExactAlarmSettings();
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: colors.pageBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colors.borderStroke.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        children: [
                          const Text('⏰', style: TextStyle(fontSize: 15)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              l10n.isTurkish
                                  ? 'Xiaomi / Android 14 için Alarmlar ve Hatırlatıcılar İznini Kontrol Edin'
                                  : 'Check Alarms & Reminders Permission for Xiaomi / Android 14',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: colors.secondaryTextAlt,
                              ),
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded,
                              size: 16, color: colors.secondaryTextAlt),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrayerTimingSwitchTile({
    required BuildContext context,
    required String prayerKey,
    required String title,
    required String emoji,
    required bool value,
    required int offsetMins,
    required String customTime,
    required ValueChanged<bool> onChanged,
    required void Function(int offsetMinutes, String customTime) onTimingSelected,
    required AppThemeColors colors,
    required bool isTr,
  }) {
    String timingLabel;
    if (customTime.isNotEmpty) {
      timingLabel = isTr ? 'Saat: $customTime' : 'At $customTime';
    } else if (offsetMins > 0) {
      timingLabel = isTr ? '$offsetMins dk önce' : '$offsetMins min before';
    } else {
      timingLabel = isTr ? 'Tam Vaktinde' : 'On Time';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 19)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colors.primaryText,
              ),
            ),
          ),
          if (value)
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _showPrayerTimingDialog(
                context: context,
                title: title,
                currentOffset: offsetMins,
                currentCustomTime: customTime,
                colors: colors,
                isTr: isTr,
                onSelected: onTimingSelected,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: colors.pageBackground,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colors.borderStroke),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.schedule_rounded, size: 13, color: colors.accent),
                    const SizedBox(width: 4),
                    Text(
                      timingLabel,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: colors.primaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(width: 4),
          Switch(
            value: value,
            activeThumbColor: colors.accent,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Future<void> _showPrayerTimingDialog({
    required BuildContext context,
    required String title,
    required int currentOffset,
    required String currentCustomTime,
    required AppThemeColors colors,
    required bool isTr,
    required void Function(int offsetMinutes, String customTime) onSelected,
  }) async {
    HapticService.selectionClick();
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          decoration: BoxDecoration(
            color: colors.bottomSheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  isTr ? '$title Bildirim & Hatırlatma Saati' : '$title Notification Timing',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colors.primaryText,
                  ),
                ),
                const SizedBox(height: 12),
                ...[
                  (mins: 0, labelTr: '🕌 Tam Vaktinde (Ezan Vakti)', labelEn: '🕌 On Exact Prayer Time'),
                  (mins: 15, labelTr: '⏰ Vaktinden 15 Dakika Önce', labelEn: '⏰ 15 Minutes Before'),
                  (mins: 30, labelTr: '⏰ Vaktinden 30 Dakika Önce', labelEn: '⏰ 30 Minutes Before'),
                  (mins: 45, labelTr: '⏰ Vaktinden 45 Dakika Önce', labelEn: '⏰ 45 Minutes Before'),
                ].map((opt) {
                  final selected = currentCustomTime.isEmpty && currentOffset == opt.mins;
                  return ListTile(
                    dense: true,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    title: Text(
                      isTr ? opt.labelTr : opt.labelEn,
                      style: TextStyle(
                        fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                        color: selected ? colors.accent : colors.primaryText,
                      ),
                    ),
                    trailing: selected
                        ? Icon(Icons.check_circle_rounded, color: colors.accent)
                        : null,
                    onTap: () {
                      Navigator.of(ctx).pop();
                      onSelected(opt.mins, '');
                    },
                  );
                }),
                ListTile(
                  dense: true,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  leading: Icon(Icons.access_time_filled_rounded, color: colors.accent),
                  title: Text(
                    currentCustomTime.isNotEmpty
                        ? (isTr ? 'Özel Saat Seçildi: $currentCustomTime (Değiştir)' : 'Custom Time: $currentCustomTime (Change)')
                        : (isTr ? 'Özel Saat Seç (Saat:Dakika)' : 'Pick Custom Clock Time (HH:mm)'),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: colors.primaryText,
                    ),
                  ),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    int initH = 12;
                    int initM = 0;
                    if (currentCustomTime.contains(':')) {
                      final parts = currentCustomTime.split(':');
                      initH = int.tryParse(parts[0]) ?? 12;
                      initM = int.tryParse(parts[1]) ?? 0;
                    }
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(hour: initH, minute: initM),
                    );
                    if (picked != null) {
                      final hhmm =
                          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                      onSelected(0, hhmm);
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPrayerSoundPickerCard({
    required BuildContext context,
    required SettingsState settings,
    required SettingsNotifier settingsNotifier,
    required AppThemeColors colors,
    required bool isTr,
  }) {
    const soundOptions = [
      (raw: 'Ezan Sesi', labelTr: '🕌 Ezan Sesi', labelEn: '🕌 Adhan Sound', previewKey: 'ezan'),
      (raw: 'Salâ Sesi', labelTr: '🕋 Salâ Sesi', labelEn: '🕋 Sala Sound', previewKey: 'sela'),
      (raw: 'Feraciye Duası', labelTr: '🤲 Feraciye Duası', labelEn: '🤲 Feraciye Prayer', previewKey: 'feraciye'),
      (raw: 'Kumru Sesi', labelTr: '🕊️ Kumru Sesi', labelEn: '🕊️ Dove Sound', previewKey: 'kumru'),
      (raw: 'Bülbül Sesi', labelTr: '🐦 Bülbül Sesi', labelEn: '🐦 Nightingale Sound', previewKey: 'bulbul'),
      (raw: 'Varsayılan (Tıklama Sesi)', labelTr: '🔔 Standart', labelEn: '🔔 Default', previewKey: 'default'),
      (raw: 'Sessiz', labelTr: '🔕 Sessiz', labelEn: '🔕 Silent', previewKey: 'none'),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.borderStroke, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🔊', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isTr
                      ? 'Namaz vakitlerinde çalacak bildirim sesini seçin ve dinleyin'
                      : 'Choose and preview prayer notification sound',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.secondaryTextAlt,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ValueListenableBuilder<String?>(
            valueListenable: SoundPoolService.activePreviewSound,
            builder: (context, activePreview, _) {
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: soundOptions.map((opt) {
                  final isSelected = settings.selectedPrayerSound == opt.raw;
                  final isPlaying = activePreview == opt.previewKey;
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      HapticService.selectionClick();
                      settingsNotifier.setSelectedPrayerSound(opt.raw);
                      if (opt.previewKey == 'ezan' ||
                          opt.previewKey == 'sela' ||
                          opt.previewKey == 'feraciye') {
                        SoundPoolService.togglePreviewSound(opt.previewKey);
                      } else {
                        SoundPoolService.playSoundByName(opt.raw);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colors.accent.withValues(alpha: 0.16)
                            : colors.pageBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? colors.accent : colors.borderStroke,
                          width: isSelected ? 1.5 : 0.9,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isTr ? opt.labelTr : opt.labelEn,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                              color: isSelected ? colors.accent : colors.primaryText,
                            ),
                          ),
                          if (opt.previewKey == 'ezan' ||
                              opt.previewKey == 'sela' ||
                              opt.previewKey == 'feraciye') ...[
                            const SizedBox(width: 6),
                            Icon(
                              isPlaying
                                  ? Icons.stop_circle_rounded
                                  : Icons.play_circle_fill_rounded,
                              size: 16,
                              color: isPlaying ? Colors.orangeAccent : colors.accent,
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSpecialSpiritualSection({
    required BuildContext context,
    required SettingsState settings,
    required SettingsNotifier settingsNotifier,
    required AppThemeColors colors,
    required bool isTr,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.borderStroke, width: 0.8),
      ),
      child: Column(
        children: [
          // 1. Perşembe Feraciye Duası
          _buildSpiritualItemCard(
            context: context,
            colors: colors,
            isTr: isTr,
            emoji: '🤲',
            title: isTr ? 'Perşembe Feraciye Duası' : 'Thursday Feraciye Prayer',
            subtitle: settings.feraciyeCustomTime.isNotEmpty
                ? (isTr
                    ? 'Her Perşembe saat ${settings.feraciyeCustomTime}\'da okunur'
                    : 'Every Thursday at ${settings.feraciyeCustomTime}')
                : (isTr
                    ? 'Perşembe akşam namazından ${settings.feraciyeMinutesBefore} dk önce okunur'
                    : 'Thursday ${settings.feraciyeMinutesBefore} min before Maghrib'),
            isEnabled: settings.isFeraciyeEnabled,
            onToggle: (val) {
              HapticService.selectionClick();
              settingsNotifier.toggleFeraciyeNotification(val);
            },
            minutesBefore: settings.feraciyeMinutesBefore,
            customTime: settings.feraciyeCustomTime,
            minutePresets: const [15, 30, 45],
            prayerLabelTr: 'Akşamdan',
            prayerLabelEn: 'before Maghrib',
            previewKey: 'feraciye',
            virtueTab: 'feraciye',
            onSelectMinutes: (mins) {
              HapticService.selectionClick();
              settingsNotifier.setFeraciyeTiming(minutesBefore: mins, customTime: '');
            },
            onSelectCustomTime: (hhmm) {
              settingsNotifier.setFeraciyeTiming(customTime: hhmm);
            },
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),

          // 2. Perşembe Yatsı Öncesi Salâ
          _buildSpiritualItemCard(
            context: context,
            colors: colors,
            isTr: isTr,
            emoji: '🕌',
            title: isTr ? 'Perşembe Yatsı Öncesi Salâ' : 'Thursday Night Sala',
            subtitle: settings.thursdaySelaCustomTime.isNotEmpty
                ? (isTr
                    ? 'Her Perşembe saat ${settings.thursdaySelaCustomTime}\'da salâ okunur'
                    : 'Every Thursday at ${settings.thursdaySelaCustomTime}')
                : (isTr
                    ? 'Perşembe yatsı namazından ${settings.thursdaySelaMinutesBefore} dk önce salâ okunur'
                    : 'Thursday ${settings.thursdaySelaMinutesBefore} min before Isha'),
            isEnabled: settings.isThursdaySelaEnabled,
            onToggle: (val) {
              HapticService.selectionClick();
              settingsNotifier.toggleThursdaySelaNotification(val);
            },
            minutesBefore: settings.thursdaySelaMinutesBefore,
            customTime: settings.thursdaySelaCustomTime,
            minutePresets: const [15, 30, 45],
            prayerLabelTr: 'Yatsıdan',
            prayerLabelEn: 'before Isha',
            previewKey: 'sela',
            virtueTab: 'sela',
            onSelectMinutes: (mins) {
              HapticService.selectionClick();
              settingsNotifier.setThursdaySelaTiming(minutesBefore: mins, customTime: '');
            },
            onSelectCustomTime: (hhmm) {
              settingsNotifier.setThursdaySelaTiming(customTime: hhmm);
            },
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),

          // 3. Cuma Namazı Öncesi Salâ
          _buildSpiritualItemCard(
            context: context,
            colors: colors,
            isTr: isTr,
            emoji: '🕋',
            title: isTr ? 'Cuma Namazı Öncesi Salâ' : 'Friday Jumu\'ah Sala',
            subtitle: settings.fridaySelaCustomTime.isNotEmpty
                ? (isTr
                    ? 'Her Cuma saat ${settings.fridaySelaCustomTime}\'da salâ okunur'
                    : 'Every Friday at ${settings.fridaySelaCustomTime}')
                : (isTr
                    ? 'Cuma namazından ${settings.fridaySelaMinutesBefore} dk önce salâ okunur'
                    : 'Friday ${settings.fridaySelaMinutesBefore} min before Jumu\'ah'),
            isEnabled: settings.isFridaySelaEnabled,
            onToggle: (val) {
              HapticService.selectionClick();
              settingsNotifier.toggleFridaySelaNotification(val);
            },
            minutesBefore: settings.fridaySelaMinutesBefore,
            customTime: settings.fridaySelaCustomTime,
            minutePresets: const [30, 45, 60],
            prayerLabelTr: 'Cumadan',
            prayerLabelEn: 'before Jumu\'ah',
            previewKey: 'sela',
            virtueTab: 'sela',
            onSelectMinutes: (mins) {
              HapticService.selectionClick();
              settingsNotifier.setFridaySelaTiming(minutesBefore: mins, customTime: '');
            },
            onSelectCustomTime: (hhmm) {
              settingsNotifier.setFridaySelaTiming(customTime: hhmm);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSpiritualItemCard({
    required BuildContext context,
    required AppThemeColors colors,
    required bool isTr,
    required String emoji,
    required String title,
    required String subtitle,
    required bool isEnabled,
    required ValueChanged<bool> onToggle,
    required int minutesBefore,
    required String customTime,
    required List<int> minutePresets,
    required String prayerLabelTr,
    required String prayerLabelEn,
    required String previewKey,
    required String virtueTab,
    required ValueChanged<int> onSelectMinutes,
    required ValueChanged<String> onSelectCustomTime,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    HapticService.selectionClick();
                    showVirtueSheet(context, initialTab: virtueTab);
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: colors.primaryText,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: isEnabled ? colors.accent : colors.secondaryTextAlt,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              ValueListenableBuilder<String?>(
                valueListenable: SoundPoolService.activePreviewSound,
                builder: (context, activePreview, _) {
                  final isPlaying = activePreview == previewKey;
                  return IconButton(
                    tooltip: isTr ? 'Sesi Dinle / Durdur' : 'Listen / Stop',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      isPlaying ? Icons.stop_circle_rounded : Icons.volume_up_rounded,
                      color: isPlaying ? Colors.orangeAccent : colors.accent,
                      size: 20,
                    ),
                    onPressed: () {
                      HapticService.selectionClick();
                      SoundPoolService.togglePreviewSound(previewKey);
                    },
                  );
                },
              ),
              Switch(
                value: isEnabled,
                activeThumbColor: colors.accent,
                onChanged: onToggle,
              ),
            ],
          ),
          if (isEnabled) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ...minutePresets.map((mins) {
                  final isSelected = customTime.isEmpty && minutesBefore == mins;
                  return InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => onSelectMinutes(mins),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colors.accent.withValues(alpha: 0.16)
                            : colors.pageBackground,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? colors.accent : colors.borderStroke,
                          width: isSelected ? 1.3 : 0.8,
                        ),
                      ),
                      child: Text(
                        isTr ? '$mins dk önce' : '$mins min before',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? colors.accent : colors.primaryText,
                        ),
                      ),
                    ),
                  );
                }),
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () async {
                    HapticService.selectionClick();
                    int initHour = 17;
                    int initMin = 0;
                    if (customTime.contains(':')) {
                      final parts = customTime.split(':');
                      initHour = int.tryParse(parts[0]) ?? 17;
                      initMin = int.tryParse(parts[1]) ?? 0;
                    }
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(hour: initHour, minute: initMin),
                    );
                    if (picked != null) {
                      final hhmm =
                          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                      onSelectCustomTime(hhmm);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: customTime.isNotEmpty
                          ? colors.accent.withValues(alpha: 0.16)
                          : colors.pageBackground,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: customTime.isNotEmpty ? colors.accent : colors.borderStroke,
                        width: customTime.isNotEmpty ? 1.3 : 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 13,
                          color: customTime.isNotEmpty ? colors.accent : colors.secondaryTextAlt,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          customTime.isNotEmpty
                              ? (isTr ? 'Saat: $customTime' : 'Time: $customTime')
                              : (isTr ? 'Özel Saat' : 'Custom Time'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: customTime.isNotEmpty ? FontWeight.bold : FontWeight.w500,
                            color: customTime.isNotEmpty ? colors.accent : colors.primaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SpiritualVirtueSheet extends ConsumerStatefulWidget {
  final String initialTab;
  const _SpiritualVirtueSheet({required this.initialTab});

  @override
  ConsumerState<_SpiritualVirtueSheet> createState() => _SpiritualVirtueSheetState();
}

class _SpiritualVirtueSheetState extends ConsumerState<_SpiritualVirtueSheet> {
  late String _selectedTab;

  static const List<String> _feraciyeClauses = [
    'اللّٰهُمَّ صَلِّ عَلٰى سَيِّدِنَا مُحَمَّدٍ وَعَلٰى اٰلِ سَيِّدِنَا مُحَمَّدٍ',
    'صَلَاةً تُنَجّٖينَا بِهَا مِنْ جَمٖيعِ الْاَهْوَالِ وَالْاٰفَاتِ',
    'وَتَقْضٖي لَنَا بِهَا جَمٖيعَ الْحَاجَاتِ',
    'وَتُطَهِّرُنَا بِهَا مِنْ جَمٖيعِ السَّيِّئَاتِ',
    'وَتَرْفَعُنَا بِهَا عِنْدَكَ اَعْلَى الدَّرَجَاتِ',
    'وَتُبَلِّغُنَا بِهَا اَقْصَى الْغَايَاتِ مِنْ جَمٖيعِ الْخَيْرَاتِ فِي الْحَيَاةِ وَبَعْدَ الْمَمَاتِ',
  ];

  static const List<String> _selaClauses = [
    'اَلصَّلَاةُ وَالسَّلَامُ عَلَيْكَ يَا رَسُولَ اللّٰهِ',
    'اَلصَّلَاةُ وَالسَّلَامُ عَلَيْكَ يَا حَبٖيبَ اللّٰهِ',
    'اَلصَّلَاةُ وَالسَّلَامُ عَلَيْكَ يَا سَيِّدَ الْاَوَّلٖينَ وَالْاٰخِرٖينَ',
    'وَالْحَمْدُ لِلّٰهِ رَبِّ الْعَالَمٖينَ',
  ];

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab == 'sela' ? 'sela' : 'feraciye';
  }

  static String _toArabicDigits(int number) {
    const digits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return number
        .toString()
        .split('')
        .map((ch) => digits[int.tryParse(ch) ?? 0])
        .join();
  }

  Widget _buildQuranStyleArabicBox({
    required List<String> clauses,
    required String arabicFont,
    required bool isBoldArabic,
    required bool highlightDivineWords,
    required bool isDark,
  }) {
    final textColor = isDark ? const Color(0xFFF3EFE6) : const Color(0xFF1B1917);
    final baseArabicStyle = TextStyle(
      fontFamily: arabicFont,
      fontSize: 24,
      height: 2.0,
      fontWeight: isBoldArabic ? FontWeight.bold : FontWeight.normal,
      color: textColor,
    );

    final spans = <InlineSpan>[];
    for (int i = 0; i < clauses.length; i++) {
      spans.addAll(
        QuranWordHighlighter.buildHighlightedSpans(
          rawText: clauses[i],
          baseStyle: baseArabicStyle,
          isDark: isDark,
          enabled: highlightDivineWords,
        ),
      );
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: ZikirceAyahStopMarker(
              number: _toArabicDigits(i + 1),
              isDark: isDark,
              isHighlight: false,
              fontFamily: arabicFont,
              size: 25,
            ),
          ),
        ),
      );
      if (i < clauses.length - 1) {
        spans.add(TextSpan(text: ' ', style: baseArabicStyle));
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A221E) : const Color(0xFFFDFBF5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFD4AF37).withValues(alpha: 0.38),
          width: 1.0,
        ),
      ),
      child: Text.rich(
        TextSpan(children: spans),
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.justify,
        strutStyle: StrutStyle(
          fontFamily: arabicFont,
          fontSize: 24,
          height: 2.0,
          forceStrutHeight: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isTr = context.l10n.isTurkish;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final arabicFont = ref.watch(arabicFontFamilyProvider);
    final isBoldArabic = ref.watch(isBoldArabicProvider);
    final highlightDivineWords = ref.watch(highlightDivineWordsProvider);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.86,
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      decoration: BoxDecoration(
        color: colors.bottomSheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        bottom: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.borderStroke,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text('✨', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Text(
                      isTr ? 'Feraciye Duası & Salâ Fazileti' : 'Virtue of Feraciye & Sala',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: colors.primaryText,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  color: colors.secondaryText,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildTabButton(
                    title: isTr ? '🤲 Feraciye Duası' : '🤲 Feraciye Prayer',
                    isSelected: _selectedTab == 'feraciye',
                    colors: colors,
                    onTap: () => setState(() => _selectedTab = 'feraciye'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildTabButton(
                    title: isTr ? '🕌 Perşembe & Cuma Salâsı' : '🕌 Thursday & Friday Sala',
                    isSelected: _selectedTab == 'sela',
                    colors: colors,
                    onTap: () => setState(() => _selectedTab = 'sela'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: _selectedTab == 'feraciye'
                    ? _buildFeraciyeContent(
                        colors: colors,
                        isTr: isTr,
                        arabicFont: arabicFont,
                        isBoldArabic: isBoldArabic,
                        highlightDivineWords: highlightDivineWords,
                        isDark: isDark,
                      )
                    : _buildSelaContent(
                        colors: colors,
                        isTr: isTr,
                        arabicFont: arabicFont,
                        isBoldArabic: isBoldArabic,
                        highlightDivineWords: highlightDivineWords,
                        isDark: isDark,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton({
    required String title,
    required bool isSelected,
    required AppThemeColors colors,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? colors.accent : colors.cardBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? colors.accent : colors.borderStroke,
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            title,
            maxLines: 1,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : colors.primaryText,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeraciyeContent({
    required AppThemeColors colors,
    required bool isTr,
    required String arabicFont,
    required bool isBoldArabic,
    required bool highlightDivineWords,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildAudioListenBanner(
          colors: colors,
          isTr: isTr,
          soundKey: 'feraciye',
          label: isTr ? 'Feraciye Duasını Sesli Dinle' : 'Listen to Feraciye Prayer',
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.cardBackground,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.borderStroke),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildQuranStyleArabicBox(
                clauses: _feraciyeClauses,
                arabicFont: arabicFont,
                isBoldArabic: isBoldArabic,
                highlightDivineWords: highlightDivineWords,
                isDark: isDark,
              ),
              const Divider(height: 24),
              Text(
                isTr ? 'Türkçe Okunuşu' : 'Transliteration',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: colors.accent,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '"Allâhümme salli alâ seyyidinâ Muhammedin ve alâ âli seyyidinâ Muhammed. Salâten tüneccînâ bihâ min cemî\'il-ehvâli vel-âfât. Ve takdî lenâ bihâ cemî\'al-hâcât. Ve tutahhirunâ bihâ min cemî\'is-seyyiât. Ve terfe\'unâ bihâ indeke a\'led-derecât. Ve tübelliğunâ bihâ aksal-ğâyât, min cemî\'il-hayrâti fil-hayâti ve ba\'del-memât."',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  fontStyle: FontStyle.italic,
                  color: colors.primaryText,
                ),
              ),
              const Divider(height: 24),
              Text(
                isTr ? 'Anlamı' : 'Meaning',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: colors.accent,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isTr
                    ? '"Allah\'ım! Efendimiz Muhammed\'e (s.a.v.) ve Efendimiz Muhammed\'in âline öyle bir salât eyle ki; o salât vesilesiyle bizi bütün korkulardan ve afetlerden kurtarasın, bütün ihtiyaçlarımızı gideresin, bizi bütün günahlardan temizleyesin, katındaki en yüce derecelere yükseltesin ve hayatta iken de öldükten sonra da bütün hayırların en üstün gayelerine ulaştırasın."'
                    : '"O Allah! Bestow blessings upon our Master Muhammad and his family, a blessing by which You save us from all terrors and calamities, fulfill all our needs, purify us from all evils, and raise us to the highest ranks."',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: colors.secondaryText,
                ),
              ),
              const Divider(height: 24),
              Text(
                isTr ? 'Fazileti ve Perşembe Akşamı Okunmasının Hikmeti' : 'Virtue & Wisdom of Reciting on Thursday Evening',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: colors.accent,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isTr
                    ? '• "Feraciye", gam ve kederin dağılması, sıkıntıdan kurtuluş ve gönül ferahlığı demektir.\n'
                      '• İslâmî takvimde mübarek Cuma gecesi, Perşembe günü akşam ezanıyla birlikte başlar. Anadolu irfan geleneğinde ve pek çok tarihi camimizde Perşembe günü akşam namazına 15 dakika kala Cuma gecesini karşılamak, belâ ve musibetlerin def\'i, rızkın bereketi ve duaların kabulü niyetiyle Feraciye (Salât-ı Münciye) okunması asırlık bir âdettir.\n'
                      '• İbnü\'l-Fâkihânî\'nin "el-Fecrü\'l-Münîr" adlı eserinde naklettiği üzere, salih zatların darlık ve şiddet anlarında bu duaya devam ederek feraha ulaştıkları bildirilmiştir.'
                    : '• "Feraciye" means relief from distress and opening of doors of mercy.\n'
                      '• Since the blessed night of Jumu\'ah begins at Maghrib on Thursday, reciting the Feraciye prayer 15 minutes before Thursday Maghrib is a cherished tradition for spiritual protection, acceptance of prayers, and relief from hardships.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.55,
                  color: colors.primaryText,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSelaContent({
    required AppThemeColors colors,
    required bool isTr,
    required String arabicFont,
    required bool isBoldArabic,
    required bool highlightDivineWords,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildAudioListenBanner(
          colors: colors,
          isTr: isTr,
          soundKey: 'sela',
          label: isTr ? 'Cuma & Perşembe Salâsını Dinle' : 'Listen to Sala Recitation',
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.cardBackground,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.borderStroke),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildQuranStyleArabicBox(
                clauses: _selaClauses,
                arabicFont: arabicFont,
                isBoldArabic: isBoldArabic,
                highlightDivineWords: highlightDivineWords,
                isDark: isDark,
              ),
              const Divider(height: 24),
              Text(
                isTr ? 'Türkçe Okunuşu ve Anlamı' : 'Transliteration & Meaning',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: colors.accent,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isTr
                    ? '"Es-salâtü ves-selâmü aleyke yâ Rasûlallâh. Es-salâtü ves-selâmü aleyke yâ Habîballâh. Es-salâtü ves-selâmü aleyke yâ Seyyidel-evvelîne vel-âhirîn. Vel-hamdü lillâhi Rabbil-âlemîn."\n\n'
                      'Anlamı: "Salât ve selâm senin üzerine olsun ey Allah\'ın Resûlü! Salât ve selâm senin üzerine olsun ey Allah\'ın Sevgilisi! Salât ve selâm senin üzerine olsun ey öncekilerin ve sonrakilerin Efendisi! Hamd, âlemlerin Rabbi olan Allah\'a mahsustur."'
                    : '"Peace and blessings be upon you, O Messenger of Allah! Peace and blessings be upon you, O Beloved of Allah! Peace and blessings be upon you, O Master of the first and the last!"',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: colors.primaryText,
                ),
              ),
              const Divider(height: 24),
              Text(
                isTr ? 'Perşembe Gecesi ve Cuma Salâsının Fazileti' : 'Virtue of Thursday Night & Friday Sala',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: colors.accent,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isTr
                    ? '• Kur\'ân-ı Kerîm\'de Ahzâb Sûresi 56. âyette: "Şüphesiz Allah ve melekleri Peygamber\'e salât ediyorlar. Ey iman edenler! Siz de ona salât edin ve tam bir teslimiyetle selâm verin" buyrulmaktadır.\n'
                      '• Peygamber Efendimiz (s.a.v.) hadis-i şeriflerinde şöyle buyurmuştur: "Günlerinizin en faziletlisi Cuma günüdür. Cuma günü ve Cuma gecesi bana çokça salavât getirin; çünkü sizin salavâtlarınız bana arz olunur." (Ebû Dâvûd, Salât, 201).\n'
                      '• Perşembe günü yatsı ezanından yarım saat önce okunan salâ, mübarek Cuma gecesinin feyzini ve salavât vaktini hatırlatır. Cuma günü öğle vaktinden 45 dakika önce okunan salâ ise müminleri gusül, sünnet hazırlığı ve Cuma namazı için camiye davet eden asırlık İslâm şiarıdır.'
                    : '• In Surah Al-Ahzab (33:56), Allah commands believers to send blessings and salutations upon the Prophet (pbuh).\n'
                      '• The Prophet (pbuh) said: "The best of your days is Friday; so send abundant blessings upon me on Friday and the night of Friday, for your blessings are presented to me." (Abu Dawud).\n'
                      '• Reciting Sala 30 minutes before Thursday Isha heralds the blessed night of Jumu\'ah, and reciting it 45 minutes before Friday Dhuhr prepares hearts for Jumu\'ah prayer.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.55,
                  color: colors.primaryText,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAudioListenBanner({
    required AppThemeColors colors,
    required bool isTr,
    required String soundKey,
    required String label,
  }) {
    return ValueListenableBuilder<String?>(
      valueListenable: SoundPoolService.activePreviewSound,
      builder: (context, activePreview, _) {
        final isPlaying = activePreview == soundKey;
        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            HapticService.selectionClick();
            SoundPoolService.togglePreviewSound(soundKey);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: colors.accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isPlaying ? Colors.orangeAccent : colors.accent,
                width: 1.3,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isPlaying ? Icons.stop_circle_rounded : Icons.play_circle_fill_rounded,
                  color: isPlaying ? Colors.orangeAccent : colors.accent,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Text(
                  isPlaying
                      ? (isTr ? 'Tilaveti Durdur' : 'Stop Audio')
                      : label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: isPlaying ? Colors.orangeAccent : colors.accent,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
