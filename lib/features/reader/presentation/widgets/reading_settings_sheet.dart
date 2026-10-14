import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/theme_provider.dart';

class ReadingSettingsSheet extends ConsumerWidget {
  const ReadingSettingsSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const ReadingSettingsSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(readerThemeProvider);
    final notifier = ref.read(readerThemeProvider.notifier);
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
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
                '🎨 Okuma & Tipografi Ayarları',
                style: GoogleFonts.literata(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 20),

              // Theme Presets
              Text(
                'TEMA PALETİ',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _ThemeColorCircle(
                    title: 'Parşömen',
                    bg: AppColors.parchmentBg,
                    border: AppColors.parchmentBorder,
                    isSelected: state.preset == TahrirThemePreset.parchment,
                    onTap: () => notifier.setPreset(TahrirThemePreset.parchment),
                  ),
                  _ThemeColorCircle(
                    title: 'AMOLED',
                    bg: AppColors.amoledBg,
                    border: AppColors.amoledBorder,
                    isSelected: state.preset == TahrirThemePreset.amoled,
                    onTap: () => notifier.setPreset(TahrirThemePreset.amoled),
                  ),
                  _ThemeColorCircle(
                    title: 'Safir',
                    bg: AppColors.sapphireBg,
                    border: AppColors.sapphireBorder,
                    isSelected: state.preset == TahrirThemePreset.sapphire,
                    onTap: () => notifier.setPreset(TahrirThemePreset.sapphire),
                  ),
                  _ThemeColorCircle(
                    title: 'Kağıt',
                    bg: AppColors.paperBg,
                    border: AppColors.paperBorder,
                    isSelected: state.preset == TahrirThemePreset.paperWhite,
                    onTap: () => notifier.setPreset(TahrirThemePreset.paperWhite),
                  ),
                  _ThemeColorCircle(
                    title: 'Zeytin',
                    bg: AppColors.forestBg,
                    border: AppColors.forestBorder,
                    isSelected: state.preset == TahrirThemePreset.forest,
                    onTap: () => notifier.setPreset(TahrirThemePreset.forest),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Font Family Selector
              Text(
                'YAZI TİPİ (FONT)',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: TahrirFontFamily.values.map((font) {
                  final isSelected = state.fontFamily == font;
                  return ChoiceChip(
                    label: Text(font.displayName),
                    selected: isSelected,
                    onSelected: (_) => notifier.setFontFamily(font),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Font Size Slider
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Punto Boyutu',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  Text(
                    '${state.fontSize.toInt()} pt',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: theme.colorScheme.primary),
                  ),
                ],
              ),
              Slider(
                value: state.fontSize,
                min: 13,
                max: 28,
                divisions: 15,
                onChanged: (val) => notifier.setFontSize(val),
              ),

              // Line Height Slider
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Satır Aralığı',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  Text(
                    '${state.lineHeight.toStringAsFixed(2)}x',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: theme.colorScheme.primary),
                  ),
                ],
              ),
              Slider(
                value: state.lineHeight,
                min: 1.2,
                max: 2.2,
                divisions: 10,
                onChanged: (val) => notifier.setLineHeight(val),
              ),
              const SizedBox(height: 12),

              // Bionic Reading Switch
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Bionic / Hızlı Odak Modu',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: Text(
                  'Kelimelerin ilk harflerini belirginleştirerek okuma hızını artırır.',
                  style: GoogleFonts.inter(fontSize: 12),
                ),
                value: state.bionicReadingEnabled,
                onChanged: (_) => notifier.toggleBionicReading(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeColorCircle extends StatelessWidget {
  final String title;
  final Color bg;
  final Color border;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeColorCircle({
    required this.title,
    required this.bg,
    required this.border,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Theme.of(context).colorScheme.primary : border,
                width: isSelected ? 3 : 1.5,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
                        blurRadius: 8,
                        spreadRadius: 2,
                      )
                    ]
                  : null,
            ),
            child: isSelected
                ? Icon(
                    Icons.check,
                    size: 20,
                    color: bg.computeLuminance() > 0.5 ? Colors.black87 : Colors.white,
                  )
                : null,
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
