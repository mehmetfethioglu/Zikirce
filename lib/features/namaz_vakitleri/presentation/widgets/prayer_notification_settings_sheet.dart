import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/battery_optimization_service.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../../core/services/local_notification_service.dart';
import '../../../../core/theme/app_theme_colors.dart';
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
                          // Section: Vakit Namazları Bildirimleri
                          Text(
                            l10n.isTurkish
                                ? 'VAKİT GİRİŞ BİLDİRİMLERİ'
                                : 'PRAYER ENTRY NOTIFICATIONS',
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
                                _buildSwitchTile(
                                  l10n.isTurkish ? 'İmsak' : 'Fajr (Imsak)',
                                  '🌙',
                                  settings.prayerNotifications['İmsak'] ?? true,
                                  (val) {
                                    HapticService.selectionClick();
                                    settingsNotifier.togglePrayerNotification('İmsak', val);
                                  },
                                  colors,
                                ),
                                const Divider(height: 1, indent: 48),
                                _buildSwitchTile(
                                  l10n.isTurkish ? 'Güneş' : 'Sunrise',
                                  '🌅',
                                  settings.prayerNotifications['Güneş'] ?? true,
                                  (val) {
                                    HapticService.selectionClick();
                                    settingsNotifier.togglePrayerNotification('Güneş', val);
                                  },
                                  colors,
                                ),
                                const Divider(height: 1, indent: 48),
                                _buildSwitchTile(
                                  l10n.isTurkish ? 'Öğle' : 'Dhuhr',
                                  '☀️',
                                  settings.prayerNotifications['Öğle'] ?? true,
                                  (val) {
                                    HapticService.selectionClick();
                                    settingsNotifier.togglePrayerNotification('Öğle', val);
                                  },
                                  colors,
                                ),
                                const Divider(height: 1, indent: 48),
                                _buildSwitchTile(
                                  l10n.isTurkish ? 'İkindi' : 'Asr',
                                  '🌤️',
                                  settings.prayerNotifications['İkindi'] ?? true,
                                  (val) {
                                    HapticService.selectionClick();
                                    settingsNotifier.togglePrayerNotification('İkindi', val);
                                  },
                                  colors,
                                ),
                                const Divider(height: 1, indent: 48),
                                _buildSwitchTile(
                                  l10n.isTurkish ? 'Akşam' : 'Maghrib',
                                  '🌆',
                                  settings.prayerNotifications['Akşam'] ?? true,
                                  (val) {
                                    HapticService.selectionClick();
                                    settingsNotifier.togglePrayerNotification('Akşam', val);
                                  },
                                  colors,
                                ),
                                const Divider(height: 1, indent: 48),
                                _buildSwitchTile(
                                  l10n.isTurkish ? 'Yatsı' : 'Isha',
                                  '🌃',
                                  settings.prayerNotifications['Yatsı'] ?? true,
                                  (val) {
                                    HapticService.selectionClick();
                                    settingsNotifier.togglePrayerNotification('Yatsı', val);
                                  },
                                  colors,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Section: Namazınızı Kıldınız mı? Hatırlatıcısı
                          Text(
                            l10n.isTurkish
                                ? 'NAMAZ TAKİP VE SORU BİLDİRİMLERİ'
                                : 'PRAYER TRACKING & QUESTION REMINDER',
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
                            child: SwitchListTile(
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
                                l10n.isTurkish
                                    ? 'Vakit çıkmadan 45 dakika önce hatırlatır ve kaza takibini kolaylaştırır.'
                                    : 'Reminds 45 minutes before prayer ends to facilitate tracking.',
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

  Widget _buildSwitchTile(
    String title,
    String emoji,
    bool value,
    ValueChanged<bool> onChanged,
    AppThemeColors colors,
  ) {
    return SwitchListTile(
      secondary: Text(emoji, style: const TextStyle(fontSize: 20)),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: colors.primaryText,
        ),
      ),
      value: value,
      activeThumbColor: colors.accent,
      onChanged: onChanged,
    );
  }
}
