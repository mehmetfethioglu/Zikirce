import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/config/kilerce_contact_config.dart';
import '../../../core/services/changelog_service.dart';
import '../../../core/services/kilerce_backup_service.dart';
import '../../../core/services/kilerce_notification_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../family_profiles/presentation/family_profiles_screen.dart';
import '../../kiler/domain/expiry_reminder_service.dart';
import '../../monetization/domain/subscription_service.dart';
import '../../monetization/presentation/paywall_screen.dart';
import '../../onboarding/presentation/kilerce_user_guide_screen.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../recipes/data/kilerce_cloud_recipe_client.dart';
import '../../taklit_tagsis/presentation/taklit_tagsis_screen.dart';
import 'privacy_policy_dialog.dart';
import 'widgets/recipe_photo_feedback_sheet.dart';

/// Dedicated full-page settings screen for Kilerce (Pro, Ads, Theme, Backup, Privacy).
class KilerceSettingsScreen extends StatefulWidget {
  const KilerceSettingsScreen({super.key});

  @override
  State<KilerceSettingsScreen> createState() => _KilerceSettingsScreenState();
}

class _KilerceSettingsScreenState extends State<KilerceSettingsScreen> {
  bool _isAdFree = false;
  Duration _remainingPro = Duration.zero;
  int _adProgress = 0;
  int _dailyPassesUsed = 0;
  final int _dailyPassesLimit = SubscriptionService.maxDailyRewardPasses;
  bool _sktRemindersEnabled = true;
  bool _morningMenuRemindersEnabled = true;
  int _morningHour = KilerceNotificationService.defaultMorningHour;
  int _morningMinute = KilerceNotificationService.defaultMorningMinute;
  bool _notificationsAllowed = true;
  String _appUserId = '';
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _loadSettingsState();
  }

  Future<void> _loadSettingsState() async {
    final results = await Future.wait<dynamic>([
      SubscriptionService.instance.isAdFree(),
      SubscriptionService.instance.getRemainingAdFreeDuration(),
      SubscriptionService.instance.getRewardAdProgress(),
      SubscriptionService.instance.getDailyRewardPassesUsed(),
      ExpiryReminderService.instance.isEnabled(),
      KilerceCloudRecipeClient.instance.getOrCreateAppUserId(),
      KilerceNotificationService.instance.loadSettings(),
      KilerceNotificationService.instance.areNotificationsEnabled(),
    ]);
    if (!mounted) return;
    final notifySettings = results[6] as KilerceNotificationSettings;
    setState(() {
      _isAdFree = results[0] as bool;
      _remainingPro = results[1] as Duration;
      _adProgress = results[2] as int;
      _dailyPassesUsed = results[3] as int;
      _sktRemindersEnabled = results[4] as bool;
      _appUserId = results[5] as String;
      _morningMenuRemindersEnabled = notifySettings.morningMenuEnabled;
      _morningHour = notifySettings.morningHour;
      _morningMinute = notifySettings.morningMinute;
      _notificationsAllowed = results[7] as bool;
    });
  }

  String get _formattedMorningTime {
    final hh = _morningHour.toString().padLeft(2, '0');
    final mm = _morningMinute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  Future<void> _requestNotificationPermission() async {
    final granted = await KilerceNotificationService.instance.requestPermission();
    await KilerceNotificationService.instance.syncAllReminders();
    if (!mounted) return;
    setState(() => _notificationsAllowed = granted);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          granted
              ? 'Bildirim izni onaylandı ve hatırlatıcılar güncellendi.'
              : 'Bildirim izni verilmedi. Cihaz ayarlarından açabilirsiniz.',
        ),
        backgroundColor:
            granted ? AppColors.primaryEmerald : AppColors.cautionGold,
      ),
    );
  }

  Future<void> _pickMorningTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _morningHour, minute: _morningMinute),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _morningHour = picked.hour;
      _morningMinute = picked.minute;
    });
    await KilerceNotificationService.instance.setMorningTime(
      picked.hour,
      picked.minute,
    );
    await KilerceNotificationService.instance.syncAllReminders();
  }

  Future<void> _sendTestNotification() async {
    if (!_notificationsAllowed) {
      await _requestNotificationPermission();
    }
    final sent =
        await KilerceNotificationService.instance.sendTestNotification();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          sent
              ? 'Test bildirimi gönderildi!'
              : 'Bildirim gösterilemedi. Bildirim iznini kontrol edin.',
        ),
        backgroundColor: sent ? AppColors.primaryEmerald : AppColors.cautionGold,
      ),
    );
  }

  Future<void> _openFeedbackEmail() async {
    final opened = await KilerceNotificationService.instance.openEmailClient(
      to: KilerceContactConfig.supportEmail,
      subject: 'Kilerce Geri Bildirim',
      body: 'Merhaba Kilerce Ekibi,\n\n',
    );
    if (opened || !mounted) return;
    await Clipboard.setData(
      const ClipboardData(text: KilerceContactConfig.supportEmail),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('E-posta adresi panoya kopyalandı.'),
        backgroundColor: AppColors.primaryEmerald,
      ),
    );
  }

  String _formatProDuration(Duration d) {
    if (d.inDays > 300) return 'Ömür Boyu / Pro Aktif';
    if (d.inDays > 0) return '${d.inDays} Gün ${d.inHours % 24} Saat kaldı';
    if (d.inHours > 0) return '${d.inHours} Saat ${d.inMinutes % 60} dk kaldı';
    if (d.inMinutes > 0) return '${d.inMinutes} dk kaldı';
    return 'Aktif';
  }

  Future<void> _openPaywall() async {
    await PaywallScreen.show(context);
    if (!mounted) return;
    await _loadSettingsState();
  }

  Future<void> _restorePurchases() async {
    setState(() => _isBusy = true);
    final res = await SubscriptionService.instance.restoreProPurchases();
    await _loadSettingsState();
    if (!mounted) return;
    setState(() => _isBusy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res.message),
        backgroundColor:
            res.success ? AppColors.primaryEmerald : AppColors.cautionGold,
      ),
    );
  }

  Future<void> _exportBackup() async {
    setState(() => _isBusy = true);
    try {
      final jsonStr = await KilerceBackupService.exportFullBackupJson();
      if (!mounted) return;
      await Share.share(jsonStr, subject: 'Kilerce Tam Yedek');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Yedek oluşturulamadı: $e'),
          backgroundColor: AppColors.dangerRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _showRestoreBackupDialog() async {
    final jsonInput = await showDialog<String>(
      context: context,
      builder: (_) => const _RestoreBackupDialog(),
    );

    if (jsonInput == null || jsonInput.isEmpty || !mounted) return;
    setState(() => _isBusy = true);
    try {
      final ok = await KilerceBackupService.importFullBackupJson(jsonInput);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Tüm Kilerce verileri başarıyla geri yüklendi.'
                : 'Geçersiz yedek formatı, veriler geri yüklenemedi.',
          ),
          backgroundColor:
              ok ? AppColors.primaryEmerald : AppColors.dangerRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _copySupportId() async {
    if (_appUserId.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _appUserId));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Destek kimliği panoya kopyalandı.'),
        backgroundColor: AppColors.primaryEmerald,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Ayarlar',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
        children: [
          _ProAndAdsHeroCard(
            isPro: _isAdFree,
            proDurationText: _formatProDuration(_remainingPro),
            adProgress: _adProgress,
            dailyPassesUsed: _dailyPassesUsed,
            dailyPassesLimit: _dailyPassesLimit,
            isBusy: _isBusy,
            onOpenPaywall: _openPaywall,
            onRestorePurchases: _restorePurchases,
          ),
          const SizedBox(height: 20),
          const _SectionHeader('Hesap & Beslenme'),
          const SizedBox(height: 8),
          _SettingsGroupCard(
            children: [
              _SettingsNavTile(
                icon: Icons.badge_outlined,
                color: AppColors.primaryEmerald,
                title: 'Profil & Katkı Rozetleri',
                subtitle: 'XP seviyesi, gönüllü rozetleri ve Google hesabı',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                ),
              ),
              _SettingsNavTile(
                icon: Icons.family_restroom_rounded,
                color: AppColors.primaryMint,
                title: 'Aile & Beslenme Profilleri',
                subtitle: 'Glutensiz, laktozsuz, vegan ve hassasiyet filtreleri',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const FamilyProfilesScreen(),
                  ),
                ),
              ),
              _SettingsNavTile(
                icon: Icons.gpp_maybe_rounded,
                color: AppColors.dangerRed,
                title: 'Bakanlık Taklit & Tağşiş Listesi',
                subtitle: 'Resmi ifşa edilen markaları sorgulayın',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TaklitTagsisScreen(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const _SectionHeader('Görünüm & Bildirimler'),
          const SizedBox(height: 8),
          _SettingsGroupCard(
            children: [
              if (!_notificationsAllowed)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  color: AppColors.cautionGold.withValues(alpha: 0.12),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.notifications_off_outlined,
                        color: AppColors.cautionGold,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Bildirim izni kapalı. Sabah menü uyarıları için izin verin.',
                          style: TextStyle(
                            color: context.textPrimaryColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _requestNotificationPermission,
                        child: const Text(
                          'İzin Ver',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Uygulama Teması',
                      style: TextStyle(
                        color: context.textPrimaryColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ValueListenableBuilder<ThemeMode>(
                      valueListenable: ThemeController.instance,
                      builder: (context, mode, _) {
                        return SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<ThemeMode>(
                            segments: const [
                              ButtonSegment(
                                value: ThemeMode.system,
                                label: Text('Sistem'),
                              ),
                              ButtonSegment(
                                value: ThemeMode.light,
                                label: Text('Açık'),
                              ),
                              ButtonSegment(
                                value: ThemeMode.dark,
                                label: Text('Koyu'),
                              ),
                            ],
                            selected: {mode},
                            onSelectionChanged: (selection) {
                              if (selection.isNotEmpty) {
                                ThemeController.instance
                                    .setThemeMode(selection.first);
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              SwitchListTile.adaptive(
                activeThumbColor: AppColors.primaryEmerald,
                secondary: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryEmerald.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.wb_sunny_outlined,
                    color: AppColors.primaryEmerald,
                    size: 20,
                  ),
                ),
                title: Text(
                  'Sabah Menü & Eksik Malzeme',
                  style: TextStyle(
                    color: context.textPrimaryColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  'Bugünkü menüde eksik ürün varsa sabah $_formattedMorningTime\'da hatırlat',
                  style: TextStyle(
                    color: context.textSecondaryColor,
                    fontSize: 11.5,
                  ),
                ),
                value: _morningMenuRemindersEnabled,
                onChanged: (val) async {
                  setState(() => _morningMenuRemindersEnabled = val);
                  await KilerceNotificationService.instance
                      .setMorningMenuEnabled(val);
                  if (val && !_notificationsAllowed) {
                    await _requestNotificationPermission();
                  } else {
                    await KilerceNotificationService.instance
                        .syncMorningMenuReminder();
                  }
                },
              ),
              if (_morningMenuRemindersEnabled)
                _SettingsNavTile(
                  icon: Icons.schedule_rounded,
                  color: AppColors.primaryMint,
                  title: 'Sabah Hatırlatma Saati',
                  subtitle: _formattedMorningTime,
                  onTap: _pickMorningTime,
                ),
              SwitchListTile.adaptive(
                activeThumbColor: AppColors.primaryEmerald,
                secondary: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.cautionGold.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.notifications_active_rounded,
                    color: AppColors.cautionGold,
                    size: 20,
                  ),
                ),
                title: Text(
                  'SKT Hatırlatma Bildirimleri',
                  style: TextStyle(
                    color: context.textPrimaryColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  'Son kullanma tarihi yaklaşan ürünler için günlük uyarı',
                  style: TextStyle(
                    color: context.textSecondaryColor,
                    fontSize: 11.5,
                  ),
                ),
                value: _sktRemindersEnabled,
                onChanged: (val) async {
                  setState(() => _sktRemindersEnabled = val);
                  await ExpiryReminderService.instance.setEnabled(val);
                  if (val) {
                    if (!_notificationsAllowed) {
                      await _requestNotificationPermission();
                    }
                    await ExpiryReminderService.instance.triggerNow();
                  }
                },
              ),
              _SettingsNavTile(
                icon: Icons.send_rounded,
                color: AppColors.primaryEmerald,
                title: 'Test Bildirimi Gönder',
                subtitle: 'Cihaz bildirimlerinin çalıştığını anında doğrulayın',
                onTap: _sendTestNotification,
              ),
            ],
          ),
          const SizedBox(height: 20),
          const _SectionHeader('Geri Bildirim & Katkı'),
          const SizedBox(height: 8),
          _SettingsGroupCard(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.photo_camera_outlined,
                      size: 18,
                      color: context.accentPrimary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        KilerceContactConfig.representativeImageShortNotice,
                        style: TextStyle(
                          color: context.textSecondaryColor,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _SettingsNavTile(
                icon: Icons.add_a_photo_rounded,
                color: AppColors.primaryEmerald,
                title: 'Tarif Fotoğrafı Gönder',
                subtitle:
                    'Yaptığınız yemeğin fotoğrafını paylaşın, gerçek görsel olarak yayınlansın',
                onTap: () => RecipePhotoFeedbackSheet.show(context),
              ),
              _SettingsNavTile(
                icon: Icons.mail_outline_rounded,
                color: AppColors.primaryMint,
                title: 'İletişim & Geri Bildirim',
                subtitle: KilerceContactConfig.supportEmail,
                onTap: _openFeedbackEmail,
              ),
            ],
          ),
          const SizedBox(height: 20),
          const _SectionHeader('Veri & Yedekleme'),
          const SizedBox(height: 8),
          _SettingsGroupCard(
            children: [
              _SettingsNavTile(
                icon: Icons.upload_file_rounded,
                color: AppColors.primaryEmerald,
                title: 'Tam Yedek Al (JSON)',
                subtitle: 'Kiler, tarif planı, favoriler ve profili dışa aktar',
                onTap: _isBusy ? null : _exportBackup,
              ),
              _SettingsNavTile(
                icon: Icons.download_rounded,
                color: AppColors.primaryMint,
                title: 'Yedekten Geri Yükle',
                subtitle: 'JSON yedek metninden tüm Kilerce verilerini geri yükle',
                onTap: _isBusy ? null : _showRestoreBackupDialog,
              ),
            ],
          ),
          const SizedBox(height: 20),
          const _SectionHeader('Uygulama & Yasal'),
          const SizedBox(height: 8),
          _SettingsGroupCard(
            children: [
              _SettingsNavTile(
                icon: Icons.menu_book_rounded,
                color: AppColors.primaryEmerald,
                title: 'Kullanım Kılavuzu',
                subtitle: 'Kilerce hızlı başlangıç ve kullanım rehberi',
                onTap: () => KilerceUserGuideScreen.show(
                  context,
                  markCompletedOnClose: false,
                ),
              ),
              _SettingsNavTile(
                icon: Icons.new_releases_outlined,
                color: AppColors.primaryEmerald,
                title: 'Sürüm Notları (v${ChangelogService.currentVersionName})',
                subtitle: 'Kilerce yenilikleri ve güncelleme geçmişi',
                onTap: () => ChangelogService.showHistory(context),
              ),
              _SettingsNavTile(
                icon: Icons.privacy_tip_outlined,
                color: AppColors.primaryMint,
                title: 'Gizlilik Politikası & Kullanım Koşulları',
                subtitle: 'Veri güvenliği, kamera izni ve AdMob politikası',
                onTap: () => PrivacyPolicyDialog.show(context),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Center(
            child: Column(
              children: [
                Text(
                  'Kilerce v${ChangelogService.currentVersionName}',
                  style: TextStyle(
                    color: context.textSecondaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_appUserId.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: _copySupportId,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      child: Text(
                        'Destek Kimliği: $_appUserId (Kopyala)',
                        style: TextStyle(
                          color:
                              context.textSecondaryColor.withValues(alpha: 0.75),
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RestoreBackupDialog extends StatefulWidget {
  const _RestoreBackupDialog();

  @override
  State<_RestoreBackupDialog> createState() => _RestoreBackupDialogState();
}

class _RestoreBackupDialogState extends State<_RestoreBackupDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Yedekten Geri Yükle'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Daha önce dışa aktardığınız Kilerce JSON yedeğini aşağıya yapıştırın:',
            style: TextStyle(fontSize: 12.5),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: '{"app":"Kilerce","version":"2.0.0",...}',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Vazgeç'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryEmerald,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('Geri Yükle'),
        ),
      ],
    );
  }
}

class _ProAndAdsHeroCard extends StatelessWidget {
  final bool isPro;
  final String proDurationText;
  final int adProgress;
  final int dailyPassesUsed;
  final int dailyPassesLimit;
  final bool isBusy;
  final VoidCallback onOpenPaywall;
  final VoidCallback onRestorePurchases;

  const _ProAndAdsHeroCard({
    required this.isPro,
    required this.proDurationText,
    required this.adProgress,
    required this.dailyPassesUsed,
    required this.dailyPassesLimit,
    required this.isBusy,
    required this.onOpenPaywall,
    required this.onRestorePurchases,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: (isPro ? AppColors.primaryEmerald : AppColors.cautionGold)
              .withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (isPro
                          ? AppColors.primaryEmerald
                          : AppColors.cautionGold)
                      .withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isPro
                      ? Icons.verified_rounded
                      : Icons.workspace_premium_rounded,
                  color:
                      isPro ? AppColors.primaryEmerald : AppColors.cautionGold,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPro
                          ? 'Kilerce Pro Aktif'
                          : 'Kilerce Pro & Reklam Ödülleri',
                      style: TextStyle(
                        color: context.textPrimaryColor,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isPro
                          ? '$proDurationText • Sınırsız tarif & reklamsız'
                          : 'Ücretsiz plan (günde 5 bulut tarif) • Reklam ilerlemesi: $adProgress/3 ($dailyPassesUsed/$dailyPassesLimit geçiş)',
                      style: TextStyle(
                        color: context.textSecondaryColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onOpenPaywall,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryEmerald,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.play_circle_outline_rounded, size: 19),
              label: const Text(
                'Pro Planlar & Reklam Ödülleri',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: TextButton(
              onPressed: isBusy ? null : onRestorePurchases,
              child: Text(
                'Satın Alımları Geri Yükle',
                style: TextStyle(
                  color: context.textSecondaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          color: context.textSecondaryColor,
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _SettingsGroupCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsGroupCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: context.cardBorderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, color: context.cardBorderColor),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _SettingsNavTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _SettingsNavTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: context.textPrimaryColor,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: context.textSecondaryColor,
          fontSize: 11.5,
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios_rounded,
        size: 14,
        color: context.textSecondaryColor,
      ),
    );
  }
}
