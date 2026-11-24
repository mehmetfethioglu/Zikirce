import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/services/backup_restore_service.dart';
import '../../../core/services/changelog_service.dart';
import '../../../core/services/reading_notification_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/theme_provider.dart';
import '../../bookshelf/presentation/providers/bookshelf_provider.dart';
import '../../marginalia/presentation/widgets/dictionary_sheet.dart';
import '../../subscription/presentation/providers/subscription_provider.dart';
import '../../subscription/presentation/widgets/tahrir_pro_sheet.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const List<int> _goalOptions = [10, 15, 20, 30, 45, 60];

  static String _themePresetLabel(TahrirThemePreset preset) => switch (preset) {
        TahrirThemePreset.parchment => 'Parşömen',
        TahrirThemePreset.paperWhite => 'Kağıt Beyazı',
        TahrirThemePreset.amoled => 'Gece (AMOLED)',
        TahrirThemePreset.sapphire => 'Safir Gece',
        TahrirThemePreset.forest => 'Zeytin Yeşili',
      };

  void _showDailyGoalSheet(BuildContext context, WidgetRef ref, int currentGoal) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outline.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Günlük Okuma Hedefi',
                style: GoogleFonts.literata(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Okuma serinizi korumak için her gün hedeflediğiniz süreyi seçin.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _goalOptions.map((mins) {
                  final isSelected = mins == currentGoal;
                  return ChoiceChip(
                    label: Text('$mins dk'),
                    selected: isSelected,
                    onSelected: (_) async {
                      Navigator.pop(ctx);
                      await ref.read(habitRepositoryProvider).setDailyGoal(mins);
                      await ref.read(bookshelfProvider.notifier).loadBooks();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Günlük okuma hedefi $mins dakika olarak güncellendi.'),
                          ),
                        );
                      }
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preset = ref.watch(readerThemeProvider.select((s) => s.preset));
    final fontFamily = ref.watch(readerThemeProvider.select((s) => s.fontFamily));
    final fontSize = ref.watch(readerThemeProvider.select((s) => s.fontSize));
    final bionicEnabled =
        ref.watch(readerThemeProvider.select((s) => s.bionicReadingEnabled));
    final dailyGoalMinutes = ref.watch(
      bookshelfProvider.select((s) => s.habitProfile?.dailyGoalMinutes ?? 20),
    );
    final subBadgeLabel =
        ref.watch(subscriptionProvider.select((s) => s.activeBadgeLabel));
    final notifState = ref.watch(readingNotificationProvider.select((s) => s));
    final notifNotifier = ref.read(readingNotificationProvider.notifier);
    final themeNotifier = ref.read(readerThemeProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Ayarlar',
          style: GoogleFonts.literata(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          // 1. BÖLÜM: GÖRÜNÜM & OKUMA TERCİHLERİ
          _buildSectionHeader(theme, 'OKUMA VE GÖRÜNÜM'),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.palette_outlined,
                              size: 20,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Sayfa Teması',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          _themePresetLabel(preset),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _ThemeSwatchOption(
                          label: 'Parşömen',
                          bg: AppColors.parchmentBg,
                          border: AppColors.parchmentBorder,
                          isSelected: preset == TahrirThemePreset.parchment,
                          onTap: () =>
                              themeNotifier.setPreset(TahrirThemePreset.parchment),
                        ),
                        _ThemeSwatchOption(
                          label: 'Kağıt',
                          bg: AppColors.paperBg,
                          border: AppColors.paperBorder,
                          isSelected: preset == TahrirThemePreset.paperWhite,
                          onTap: () =>
                              themeNotifier.setPreset(TahrirThemePreset.paperWhite),
                        ),
                        _ThemeSwatchOption(
                          label: 'AMOLED',
                          bg: AppColors.amoledBg,
                          border: AppColors.amoledBorder,
                          isSelected: preset == TahrirThemePreset.amoled,
                          onTap: () =>
                              themeNotifier.setPreset(TahrirThemePreset.amoled),
                        ),
                        _ThemeSwatchOption(
                          label: 'Safir',
                          bg: AppColors.sapphireBg,
                          border: AppColors.sapphireBorder,
                          isSelected: preset == TahrirThemePreset.sapphire,
                          onTap: () =>
                              themeNotifier.setPreset(TahrirThemePreset.sapphire),
                        ),
                        _ThemeSwatchOption(
                          label: 'Zeytin',
                          bg: AppColors.forestBg,
                          border: AppColors.forestBorder,
                          isSelected: preset == TahrirThemePreset.forest,
                          onTap: () =>
                              themeNotifier.setPreset(TahrirThemePreset.forest),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(
                      Icons.font_download_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    title: Text(
                      'Yazı Tipi',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    trailing: DropdownButton<TahrirFontFamily>(
                      value: fontFamily,
                      underline: const SizedBox(),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                      items: TahrirFontFamily.values.map((f) {
                        return DropdownMenuItem(
                          value: f,
                          child: Text(f.displayName),
                        );
                      }).toList(),
                      onChanged: (f) {
                        if (f != null) themeNotifier.setFontFamily(f);
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(
                      Icons.format_size_rounded,
                      color: theme.colorScheme.primary,
                    ),
                    title: Text(
                      'Metin Boyutu',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.remove_circle_outline, size: 20),
                          onPressed: () => themeNotifier.setFontSize(fontSize - 1),
                        ),
                        Text(
                          '${fontSize.toInt()} pt',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.add_circle_outline, size: 20),
                          onPressed: () => themeNotifier.setFontSize(fontSize + 1),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  SwitchListTile.adaptive(
                    secondary: Icon(
                      Icons.bolt_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    title: Text(
                      'Biyonik Hızlı Odak Modu',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      'Kelimelerin ilk hecelerini vurgulayarak göz takibini hızlandırır',
                      style: GoogleFonts.inter(fontSize: 12),
                    ),
                    value: bionicEnabled,
                    onChanged: (_) => themeNotifier.toggleBionicReading(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 2. BÖLÜM: HEDEFLER & BİLDİRİMLER
          _buildSectionHeader(theme, 'HEDEFLER VE HATIRLATICILAR'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    Icons.timer_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  title: Text(
                    'Günlük Okuma Hedefi',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Her gün $dailyGoalMinutes dakika okuma',
                    style: GoogleFonts.inter(fontSize: 12),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$dailyGoalMinutes dk',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ],
                  ),
                  onTap: () => _showDailyGoalSheet(context, ref, dailyGoalMinutes),
                ),
                const Divider(height: 1),
                SwitchListTile.adaptive(
                  secondary: Icon(
                    Icons.notifications_none_rounded,
                    color: theme.colorScheme.primary,
                  ),
                  title: Text(
                    'Akıllı Seri Hatırlatıcısı',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Hedef tamamlanmadıysa ${notifState.formattedReminderTime} saatinde hatırlat',
                    style: GoogleFonts.inter(fontSize: 12),
                  ),
                  value: notifState.isEnabled,
                  onChanged: (v) => notifNotifier.setEnabled(v),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(
                    Icons.widgets_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  title: Text(
                    'Ana Ekran Widget’ı Ekle',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Seri ve aktif eseri telefon ana ekranına sabitle',
                    style: GoogleFonts.inter(fontSize: 12),
                  ),
                  trailing: Icon(
                    Icons.add_to_home_screen_rounded,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  onTap: () async {
                    final pinned = await notifNotifier.requestPinHomeScreenWidget();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            pinned
                                ? 'Tahrir Ana Ekran Widget’ı eklendi!'
                                : 'Ana ekrana basılı tutup Widget’lar > Tahrir seçerek ekleyebilirsiniz.',
                          ),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 3. BÖLÜM: VERİ VE YEDEKLEME
          _buildSectionHeader(theme, 'VERİ VE YEDEKLEME'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    Icons.upload_file_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  title: Text(
                    'Kütüphane ve Notları Yedekle (JSON)',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Kitap ilerlemelerinizi, notlarınızı ve seri geçmişinizi dışa aktarın',
                    style: GoogleFonts.inter(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    final res = await ref
                        .read(backupRestoreServiceProvider)
                        .exportBackupJson(shareFile: true);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            res.isSuccess
                                ? '✅ Yedek dosyası oluşturuldu: ${res.dataOrNull}'
                                : 'Yedekleme hatası: ${res.errorOrNull?.message ?? ''}',
                          ),
                        ),
                      );
                    }
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(
                    Icons.restore_page_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  title: Text(
                    'Yedekten Geri Yükle',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Daha önce aldığınız JSON yedeğini seçerek verilerinizi geri yükleyin',
                    style: GoogleFonts.inter(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    final res = await ref
                        .read(backupRestoreServiceProvider)
                        .importBackupJson();
                    if (res.isSuccess) {
                      final summary = res.dataOrNull;
                      if (summary != null && summary.totalItems > 0) {
                        await ref.read(bookshelfProvider.notifier).loadBooks();
                        ref.read(highlightsRevisionProvider.notifier).state++;
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '✅ Geri yüklendi: ${summary.booksRestored} kitap, ${summary.highlightsRestored} not, ${summary.sessionsRestored} oturum.',
                              ),
                            ),
                          );
                        }
                      }
                    } else if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Geri yükleme hatası: ${res.errorOrNull?.message ?? ''}',
                          ),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 4. BÖLÜM: SÖZLÜK, ÜYELİK & HAKKINDA
          _buildSectionHeader(theme, 'ARAÇLAR VE UYGULAMA'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    Icons.menu_book_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  title: Text(
                    'Sözlük & Kavram Lügatı',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Akademik, edebi ve klasik Türkçe kavramlar sözlüğü',
                    style: GoogleFonts.inter(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => DictionarySheet.show(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(
                    Icons.workspace_premium_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  title: Text(
                    'Tahrir Pro',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Durum: $subBadgeLabel',
                    style: GoogleFonts.inter(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => TahrirProSheet.show(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(
                    Icons.history_edu_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  title: Text(
                    'Sürüm Notları & Yenilikler',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Son güncellemeler ve iyileştirmeler',
                    style: GoogleFonts.inter(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => ChangelogModal.show(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(
                    Icons.verified_user_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  title: Text(
                    'Tahrir v${AppConstants.appVersion}',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Tüm kitaplarınız ve notlarınız cihazınızda yerel olarak saklanır.',
                    style: GoogleFonts.inter(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _ThemeSwatchOption extends StatelessWidget {
  final String label;
  final Color bg;
  final Color border;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeSwatchOption({
    required this.label,
    required this.bg,
    required this.border,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? theme.colorScheme.primary : border,
                width: isSelected ? 2.5 : 1.2,
              ),
            ),
            child: isSelected
                ? Icon(
                    Icons.check_rounded,
                    size: 18,
                    color: bg.computeLuminance() > 0.5 ? Colors.black87 : Colors.white,
                  )
                : null,
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}


