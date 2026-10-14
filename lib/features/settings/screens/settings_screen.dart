import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/services/changelog_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/theme_provider.dart';
import '../../bookshelf/presentation/providers/bookshelf_provider.dart';
import '../../marginalia/presentation/widgets/dictionary_sheet.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const List<int> _goalOptions = [10, 15, 20, 30, 45, 60];

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
                    color: theme.colorScheme.outline.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '⏱️ Günlük Okuma Hedefi Seçin',
                style: GoogleFonts.literata(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Tahrir zincirinizi korumak için her gün okumak istediğiniz süreyi belirleyin.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withOpacity(0.65),
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
                            content: Text('✨ Günlük okuma hedefi $mins dakika olarak güncellendi.'),
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
    final themeMode = ref.watch(readerThemeProvider.select((s) => s.themeMode));
    final preset = ref.watch(readerThemeProvider.select((s) => s.preset));
    final fontFamily = ref.watch(readerThemeProvider.select((s) => s.fontFamily));
    final dailyGoalMinutes = ref.watch(
      bookshelfProvider.select((s) => s.habitProfile?.dailyGoalMinutes ?? 20),
    );
    final themeNotifier = ref.read(readerThemeProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Ayarlar & Tercihler',
          style: GoogleFonts.literata(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Section 1: Görsel Görünüm ve Tema
          _buildSectionHeader(theme, 'GÖRÜNÜM VE TEMALAR'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.brightness_medium_outlined),
                  title: const Text('Cihaz Sistem Teması'),
                  subtitle: Text(
                    themeMode == ThemeMode.system
                        ? 'Sistem Temasına Otomatik Uyum'
                        : (themeMode == ThemeMode.dark ? 'Koyu Tema' : 'Açık Tema'),
                  ),
                  trailing: DropdownButton<ThemeMode>(
                    value: themeMode,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: ThemeMode.system, child: Text('Sistem')),
                      DropdownMenuItem(value: ThemeMode.light, child: Text('Açık')),
                      DropdownMenuItem(value: ThemeMode.dark, child: Text('Koyu')),
                    ],
                    onChanged: (mode) {
                      if (mode != null) themeNotifier.setThemeMode(mode);
                    },
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: const Text('Varsayılan Okuma Teması'),
                  subtitle: Text(preset.name.toUpperCase()),
                  trailing: DropdownButton<TahrirThemePreset>(
                    value: preset,
                    underline: const SizedBox(),
                    items: TahrirThemePreset.values.map((p) {
                      return DropdownMenuItem(value: p, child: Text(p.name));
                    }).toList(),
                    onChanged: (selectedPreset) {
                      if (selectedPreset != null) themeNotifier.setPreset(selectedPreset);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Section 2: Tipografi
          _buildSectionHeader(theme, 'TİPOGRAFİ VE METİN'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.font_download_outlined),
                  title: const Text('Varsayılan Yazı Tipi'),
                  subtitle: Text(fontFamily.displayName),
                  trailing: DropdownButton<TahrirFontFamily>(
                    value: fontFamily,
                    underline: const SizedBox(),
                    items: TahrirFontFamily.values.map((f) {
                      return DropdownMenuItem(value: f, child: Text(f.displayName));
                    }).toList(),
                    onChanged: (f) {
                      if (f != null) themeNotifier.setFontFamily(f);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Section 3: Alışkanlık & Hedefler
          _buildSectionHeader(theme, 'ALIŞKANLIK VE HEDEFLER'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.timer_outlined),
              title: const Text('Günlük Okuma Hedefi'),
              subtitle: Text('Günde en az $dailyGoalMinutes dakika'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$dailyGoalMinutes dk',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.edit_outlined,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                ],
              ),
              onTap: () => _showDailyGoalSheet(context, ref, dailyGoalMinutes),
            ),
          ),
          const SizedBox(height: 20),

          // Section 4: Gizlilik & Hakkında
          _buildSectionHeader(theme, 'GİZLİLİK VE SİSTEM'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.menu_book_outlined),
                  title: const Text('📖 Tahrir Klasik & Etimolojik Lügat'),
                  subtitle: const Text('Osmanlıca, klasik Türkçe ve edebi kavramlar sözlüğü'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => DictionarySheet.show(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.history_edu_outlined),
                  title: const Text('📜 Sürüm Notları & Yenilikler (Changelog)'),
                  subtitle: const Text('Son güncellemeler ve yeni eklenen özellikler'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => ChangelogModal.show(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.shield_outlined),
                  title: const Text('Yerel Öncelikli & Güvenli Mimari'),
                  subtitle: const Text('Tüm verileriniz ve kitaplarınız yalnızca cihazınızda saklanır.'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Tahrir Sürümü'),
                  subtitle: const Text('${AppConstants.appVersion} • Impeller Zero-Lag Engine'),
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
          letterSpacing: 1.2,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

