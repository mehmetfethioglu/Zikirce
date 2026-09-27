import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/services/local_notification_service.dart';
import '../../../../core/services/battery_optimization_service.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../providers/prayer_providers.dart';

class PrayerNotificationSettingsSheet extends ConsumerStatefulWidget {
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
  ConsumerState<PrayerNotificationSettingsSheet> createState() =>
      _PrayerNotificationSettingsSheetState();
}

class _PrayerNotificationSettingsSheetState
    extends ConsumerState<PrayerNotificationSettingsSheet> {
  bool _isLoading = true;

  bool _imsakEnabled = true;
  bool _gunesEnabled = true;
  bool _ogleEnabled = true;
  bool _ikindiEnabled = true;
  bool _aksamEnabled = true;
  bool _yatsiEnabled = true;

  bool _kazaQuestionEnabled = true;
  String _selectedSound = 'Bülbül Sesi';

  static const List<String> _soundOptions = [
    'Bülbül Sesi',
    'Kumru Sesi',
    'Varsayılan',
    'Sessiz',
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _imsakEnabled = prefs.getBool('ImsakNotificationEnabled') ?? true;
      _gunesEnabled = prefs.getBool('GunesNotificationEnabled') ?? true;
      _ogleEnabled = prefs.getBool('OgleNotificationEnabled') ?? true;
      _ikindiEnabled = prefs.getBool('IkindiNotificationEnabled') ?? true;
      _aksamEnabled = prefs.getBool('AksamNotificationEnabled') ?? true;
      _yatsiEnabled = prefs.getBool('YatsiNotificationEnabled') ?? true;

      _kazaQuestionEnabled = prefs.getBool('KazaQuestionNotificationEnabled') ?? true;
      _selectedSound = prefs.getString('SelectedPrayerSound') ?? 'Bülbül Sesi';
      _isLoading = false;
    });
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    }

    final timings = ref.read(prayerTimingsProvider).valueOrNull;
    if (timings != null) {
      await LocalNotificationService.scheduleAllPrayerNotifications(timings);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: colors.bottomSheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
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
                    'Bildirim Ayarları',
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
                // Section: Vakit Namazları Bildirimleri
                Text(
                  'VAKİT GİRİŞ BİLDİRİMLERİ',
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
                      _buildSwitchTile('İmsak', '🌙', _imsakEnabled, (val) {
                        setState(() => _imsakEnabled = val);
                        _saveSetting('ImsakNotificationEnabled', val);
                      }, colors),
                      const Divider(height: 1, indent: 48),
                      _buildSwitchTile('Güneş', '🌅', _gunesEnabled, (val) {
                        setState(() => _gunesEnabled = val);
                        _saveSetting('GunesNotificationEnabled', val);
                      }, colors),
                      const Divider(height: 1, indent: 48),
                      _buildSwitchTile('Öğle', '☀️', _ogleEnabled, (val) {
                        setState(() => _ogleEnabled = val);
                        _saveSetting('OgleNotificationEnabled', val);
                      }, colors),
                      const Divider(height: 1, indent: 48),
                      _buildSwitchTile('İkindi', '🌤️', _ikindiEnabled, (val) {
                        setState(() => _ikindiEnabled = val);
                        _saveSetting('IkindiNotificationEnabled', val);
                      }, colors),
                      const Divider(height: 1, indent: 48),
                      _buildSwitchTile('Akşam', '🌆', _aksamEnabled, (val) {
                        setState(() => _aksamEnabled = val);
                        _saveSetting('AksamNotificationEnabled', val);
                      }, colors),
                      const Divider(height: 1, indent: 48),
                      _buildSwitchTile('Yatsı', '🌃', _yatsiEnabled, (val) {
                        setState(() => _yatsiEnabled = val);
                        _saveSetting('YatsiNotificationEnabled', val);
                      }, colors),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Section: Namazınızı Kıldınız mı? Hatırlatıcısı
                Text(
                  'NAMAZ TAKİP VE SORU BİLDİRİMLERİ',
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
                    title: Text(
                      'Namazınızı Kıldınız mı? 🕌',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: colors.primaryText,
                      ),
                    ),
                    subtitle: Text(
                      'Vakit çıkmadan 45 dakika önce hatırlatır ve kaza takibini kolaylaştırır.',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.secondaryTextAlt,
                      ),
                    ),
                    value: _kazaQuestionEnabled,
                    activeThumbColor: colors.accent,
                    onChanged: (val) {
                      setState(() => _kazaQuestionEnabled = val);
                      _saveSetting('KazaQuestionNotificationEnabled', val);
                    },
                  ),
                ),
                const SizedBox(height: 20),

                // Section: Bildirim Sesi Seçimi
                Text(
                  'BİLDİRİM SESİ',
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedSound,
                      dropdownColor: colors.cardBackground,
                      icon: Icon(Icons.arrow_drop_down_rounded, color: colors.accent),
                      items: _soundOptions.map((s) {
                        return DropdownMenuItem<String>(
                          value: s,
                          child: Text(
                            s,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: colors.primaryText,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedSound = val);
                          _saveSetting('SelectedPrayerSound', val);
                          _saveSetting('SelectedReminderSound', val);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Test Notification Button
                OutlinedButton.icon(
                  onPressed: () async {
                    HapticService.selectionClick();
                    await LocalNotificationService.showTestNotification(sound: _selectedSound);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Test bildirimi gönderildi! 🔔')),
                      );
                    }
                  },
                  icon: const Icon(Icons.notifications_active_outlined, size: 18),
                  label: const Text('Bildirimi Test Et'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.accent,
                    side: BorderSide(color: colors.accent.withValues(alpha: 0.4)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
                const SizedBox(height: 10),

                // Xiaomi / Android 14 Exact Alarm & Background Guide
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
                            'Xiaomi / Android 14 için Alarmlar ve Hatırlatıcılar İznini Kontrol Edin',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: colors.secondaryTextAlt,
                            ),
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, size: 16, color: colors.secondaryTextAlt),
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
