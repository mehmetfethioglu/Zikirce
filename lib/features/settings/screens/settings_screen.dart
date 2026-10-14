import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/theme_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(readerThemeProvider);
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
                    themeState.themeMode == ThemeMode.system
                        ? 'Sistem Temasına Otomatik Uyum'
                        : (themeState.themeMode == ThemeMode.dark ? 'Koyu Tema' : 'Açık Tema'),
                  ),
                  trailing: DropdownButton<ThemeMode>(
                    value: themeState.themeMode,
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
                  subtitle: Text(themeState.preset.name.toUpperCase()),
                  trailing: DropdownButton<TahrirThemePreset>(
                    value: themeState.preset,
                    underline: const SizedBox(),
                    items: TahrirThemePreset.values.map((p) {
                      return DropdownMenuItem(value: p, child: Text(p.name));
                    }).toList(),
                    onChanged: (preset) {
                      if (preset != null) themeNotifier.setPreset(preset);
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
                  subtitle: Text(themeState.fontFamily.displayName),
                  trailing: DropdownButton<TahrirFontFamily>(
                    value: themeState.fontFamily,
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
              subtitle: const Text('Günde en az 20 dakika'),
              trailing: Text('20 dk', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
            ),
          ),
          const SizedBox(height: 20),

          // Section 4: Gizlilik & Hakkında
          _buildSectionHeader(theme, 'GİZLİLİK VE SİSTEM'),
          Card(
            child: Column(
              children: [
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
