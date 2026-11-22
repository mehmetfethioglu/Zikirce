import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/tenfei_zk_client.dart';
import '../../domain/pdks_models.dart';
import '../providers/pdks_providers.dart';
import 'app_users_management_card.dart';
import 'cloud_backup_center_dialog.dart';
import 'hasibu_release_notes_dialog.dart';

// ============================================================================
// ORTAK BİLEŞEN 0: MİNİMALİST TEMA PALETİ (AÇIK / KOYU / SİSTEM UYUMLU)
// ============================================================================
class HasibuPalette {
  final bool isDark;

  const HasibuPalette._(this.isDark);

  factory HasibuPalette.of(BuildContext context) {
    return HasibuPalette._(Theme.of(context).brightness == Brightness.dark);
  }

  // Koyu temada OLED ekranlar için %100 gerçek simsiyah (#000000) zemin
  Color get bg => isDark ? const Color(0xFF000000) : const Color(0xFFF8FAFC);
  Color get card => isDark ? const Color(0xFF09090B) : Colors.white;
  Color get subtle =>
      isDark ? const Color(0xFF121216) : const Color(0xFFF8FAFC);
  Color get chip => isDark ? const Color(0xFF18181D) : const Color(0xFFF1F5F9);
  Color get border =>
      isDark ? const Color(0xFF232329) : const Color(0xFFE2E8F0);
  Color get textPrimary =>
      isDark ? const Color(0xFFFFFFFF) : const Color(0xFF0F172A);
  Color get textSecondary =>
      isDark ? const Color(0xFFA1A1AA) : const Color(0xFF64748B);
  Color get textMuted =>
      isDark ? const Color(0xFF71717A) : const Color(0xFF94A3B8);
  Color get activeBg =>
      isDark ? const Color(0xFF10B981) : const Color(0xFF0F172A);
  Color get activeFg => Colors.white;
}

// ============================================================================
// ORTAK BİLEŞEN 1A: KURUMSAL ŞİRKET LOGOSU BİLEŞENİ & SEÇİM MODALI
// ============================================================================
class CompanyLogoBadge extends StatelessWidget {
  final CompanySettings settings;
  final double size;
  final double borderRadius;
  final VoidCallback? onTap;

  const CompanyLogoBadge({
    super.key,
    required this.settings,
    this.size = 40,
    this.borderRadius = 11,
    this.onTap,
  });

  static const List<({IconData icon, Color bg, Color fg, String label})>
      presets = <({IconData icon, Color bg, Color fg, String label})>[
    (
      icon: Icons.grid_view_rounded,
      bg: Color(0xFF0F172A),
      fg: Colors.white,
      label: 'Minimalist Kare'
    ),
    (
      icon: Icons.precision_manufacturing_rounded,
      bg: Color(0xFF0369A1),
      fg: Colors.white,
      label: 'Endüstriyel Üretim'
    ),
    (
      icon: Icons.shield_rounded,
      bg: Color(0xFF047857),
      fg: Colors.white,
      label: 'Kurumsal Kalkan'
    ),
    (
      icon: Icons.hub_rounded,
      bg: Color(0xFF4338CA),
      fg: Colors.white,
      label: 'Yalın Teknoloji'
    ),
    (
      icon: Icons.apartment_rounded,
      bg: Color(0xFFB45309),
      fg: Colors.white,
      label: 'Merkez Holding'
    ),
    (
      icon: Icons.bolt_rounded,
      bg: Color(0xFFBE123C),
      fg: Colors.white,
      label: 'Dinamik Enerji'
    ),
  ];

  String _companyInitials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) return 'H';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts[1].substring(0, 1)}'
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final raw = settings.logoPath?.trim() ?? '';
    final bool isPreset = raw.startsWith('logo:');
    final int presetIdx = isPreset
        ? ((int.tryParse(raw.replaceFirst('logo:', '')) ?? 1) - 1)
            .clamp(0, presets.length - 1)
        : 0;

    Widget content;
    if (raw == 'logo:initials') {
      content = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF0284C7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        alignment: Alignment.center,
        child: Text(
          _companyInitials(settings.companyName),
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: size * 0.38,
            letterSpacing: -0.5,
          ),
        ),
      );
    } else if (raw == 'logo:hasibu_alt') {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.asset(
          'assets/icon/hasibu_icon_alt.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
          isAntiAlias: true,
          errorBuilder: (context, error, stackTrace) =>
              _buildPreset(presetIdx),
        ),
      );
    } else if (raw.isEmpty || raw == 'logo:1' || raw == 'logo:hasibu') {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.asset(
          'assets/icon/hasibu_icon.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
          isAntiAlias: true,
          errorBuilder: (context, error, stackTrace) =>
              _buildPreset(presetIdx),
        ),
      );
    } else if (raw.isNotEmpty && !isPreset) {
      final file = File(raw);
      if (file.existsSync()) {
        content = ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: Image.file(
            file,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                _buildPreset(presetIdx),
          ),
        );
      } else {
        content = _buildPreset(presetIdx);
      }
    } else {
      content = _buildPreset(presetIdx);
    }

    if (onTap == null) return content;
    return InkWell(
      borderRadius: BorderRadius.circular(borderRadius),
      onTap: onTap,
      child: content,
    );
  }

  Widget _buildPreset(int index) {
    final p = presets[index];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: p.bg,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      alignment: Alignment.center,
      child: Icon(
        p.icon,
        color: p.fg,
        size: size * 0.54,
      ),
    );
  }

  static const String _winDialogHost = 'power' 'shell.exe';

  static Future<String?> pickLogoFromDesktop() async {
    if (!Platform.isWindows) return null;
    try {
      final result = await Process.run(_winDialogHost, <String>[
        '-NoProfile',
        '-Command',
        "Add-Type -AssemblyName System.Windows.Forms; "
            "\$f = New-Object System.Windows.Forms.OpenFileDialog; "
            "\$f.Title = 'Şirket Logosu Seçin'; "
            "\$f.Filter = 'Logo Görselleri (*.png;*.jpg;*.jpeg;*.webp;*.bmp)|*.png;*.jpg;*.jpeg;*.webp;*.bmp'; "
            "if (\$f.ShowDialog() -eq 'OK') { Write-Output \$f.FileName }",
      ]);
      final path = result.stdout.toString().trim();
      return path.isNotEmpty ? path : null;
    } catch (_) {
      return null;
    }
  }
}

Future<void> showCompanyLogoDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final settings = ref.read(pdksDashboardProvider).companySettings;
  final pathCtrl = TextEditingController(text: settings.logoPath ?? 'logo:1');
  final nameCtrl = TextEditingController(text: settings.companyName);

  await showDialog<void>(
    context: context,
    builder: (dialogCtx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        final previewSettings = settings.copyWith(
          companyName: nameCtrl.text.trim().isEmpty
              ? settings.companyName
              : nameCtrl.text.trim(),
          logoPath: () =>
              pathCtrl.text.trim().isEmpty ? null : pathCtrl.text.trim(),
        );
        final pal = HasibuPalette.of(ctx);

        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.verified_rounded, color: Color(0xFF0284C7)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Şirket Logosu & Kurumsal Kimlik Ayarı',
                  style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: pal.subtle,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: pal.border),
                    ),
                    child: Row(
                      children: [
                        CompanyLogoBadge(
                          settings: previewSettings,
                          size: 58,
                          borderRadius: 14,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                previewSettings.companyName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: pal.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Seçtiğiniz logo hem Oturum Açma (Login) ekranında hem de uygulama üst barında gösterilir.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: pal.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: nameCtrl,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Şirket / İşletme Adı',
                      prefixIcon: Icon(Icons.apartment_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const ValueKey('company_logo_path_field'),
                          controller: pathCtrl,
                          onChanged: (_) => setDialogState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'Logo Dosya Yolu veya Stil Kodu',
                            hintText: r'C:\Logo\sirket_logo.png veya logo:1',
                            prefixIcon: Icon(Icons.image_outlined),
                          ),
                        ),
                      ),
                      if (Platform.isWindows) ...[
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final picked =
                                await CompanyLogoBadge.pickLogoFromDesktop();
                            if (picked != null) {
                              setDialogState(() => pathCtrl.text = picked);
                            }
                          },
                          icon: const Icon(Icons.folder_open_rounded, size: 18),
                          label: const Text('Dosya Seç'),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Hazır Kurumsal Amblem Stilleri:',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: pal.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        avatar: const Icon(Icons.auto_awesome_rounded, size: 15),
                        label: const Text('Hasibu Mizan & Defter'),
                        selected: pathCtrl.text.trim().isEmpty ||
                            pathCtrl.text.trim() == 'logo:1' ||
                            pathCtrl.text.trim() == 'logo:hasibu',
                        onSelected: (_) =>
                            setDialogState(() => pathCtrl.text = 'logo:hasibu'),
                      ),
                      ChoiceChip(
                        avatar: const Icon(Icons.architecture_rounded, size: 15),
                        label: const Text('Hasibu Monolitik H'),
                        selected: pathCtrl.text.trim() == 'logo:hasibu_alt',
                        onSelected: (_) => setDialogState(
                          () => pathCtrl.text = 'logo:hasibu_alt',
                        ),
                      ),
                      ChoiceChip(
                        label: const Text('Harf Amblemi'),
                        selected: pathCtrl.text.trim() == 'logo:initials',
                        onSelected: (_) =>
                            setDialogState(() => pathCtrl.text = 'logo:initials'),
                      ),
                      for (int i = 0;
                          i < CompanyLogoBadge.presets.length;
                          i++)
                        ChoiceChip(
                          avatar: Icon(
                            CompanyLogoBadge.presets[i].icon,
                            size: 15,
                          ),
                          label: Text(CompanyLogoBadge.presets[i].label),
                          selected: pathCtrl.text.trim() == 'logo:${i + 1}',
                          onSelected: (_) => setDialogState(
                            () => pathCtrl.text = 'logo:${i + 1}',
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('İptal'),
            ),
            FilledButton.icon(
              key: const ValueKey('save_company_logo_button'),
              onPressed: () async {
                final notifier = ref.read(pdksDashboardProvider.notifier);
                final cleanLogo = pathCtrl.text.trim();
                await notifier.updateCompanySettings(
                  settings.copyWith(
                    companyName: nameCtrl.text.trim().isEmpty
                        ? settings.companyName
                        : nameCtrl.text.trim(),
                    logoPath: () => cleanLogo.isEmpty ? null : cleanLogo,
                  ),
                );
                if (dialogCtx.mounted) {
                  Navigator.of(dialogCtx).pop();
                }
              },
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Logoyu & Kimliği Kaydet'),
            ),
          ],
        );
      },
    ),
  );

  pathCtrl.dispose();
  nameCtrl.dispose();
}

// ============================================================================
// ORTAK BİLEŞEN 1B: KULLANICIYA ÖZGÜ TEMA SEÇİCİ (AÇIK / KOYU / SİSTEM)
// ============================================================================
class UserThemeSelectorBar extends ConsumerWidget {
  final bool compact;

  const UserThemeSelectorBar({
    super.key,
    this.compact = false,
  });

  IconData _iconForTheme(HasibuThemeMode mode) {
    switch (mode) {
      case HasibuThemeMode.light:
        return Icons.light_mode_rounded;
      case HasibuThemeMode.dark:
        return Icons.dark_mode_rounded;
      case HasibuThemeMode.system:
        return Icons.brightness_auto_rounded;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTheme = ref.watch(
      pdksDashboardProvider.select((s) => s.activeThemeMode),
    );
    final authSession = ref.watch(
      pdksDashboardProvider.select((s) => s.authSession),
    );
    final pal = HasibuPalette.of(context);

    if (compact) {
      final isMobile = MediaQuery.sizeOf(context).width < 640;
      return PopupMenuButton<HasibuThemeMode>(
        key: const ValueKey('appbar_theme_selector_button'),
        tooltip: 'Kişisel Tema Seçimi (${activeTheme.label})',
        onSelected: (mode) => ref
            .read(pdksDashboardProvider.notifier)
            .setCurrentUserThemeMode(mode),
        itemBuilder: (_) => [
          for (final m in HasibuThemeMode.values)
            PopupMenuItem<HasibuThemeMode>(
              value: m,
              child: Row(
                children: [
                  Icon(_iconForTheme(m), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    m.label,
                    style: TextStyle(
                      fontWeight:
                          m == activeTheme ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 8 : 10,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: pal.subtle,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: pal.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_iconForTheme(activeTheme), size: 15, color: pal.textPrimary),
              if (!isMobile) ...[
                const SizedBox(width: 6),
                Text(
                  activeTheme.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: pal.textPrimary,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final userLabel = authSession.isAuthenticated
        ? '${authSession.displayName} (${authSession.role.label})'
        : 'Varsayılan Görünüm';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: pal.subtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: pal.border),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _iconForTheme(activeTheme),
                    size: 18,
                    color: const Color(0xFF0284C7),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Kişisel Tema Tercihi • $userLabel',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: pal.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                'Her kullanıcının (Yönetici ve Personellerin) tema seçimi kendi profiline özel kaydedilir.',
                style: TextStyle(fontSize: 12, color: pal.textSecondary),
              ),
            ],
          ),
          SegmentedButton<HasibuThemeMode>(
            key: const ValueKey('settings_theme_segmented_button'),
            segments: [
              for (final m in HasibuThemeMode.values)
                ButtonSegment<HasibuThemeMode>(
                  value: m,
                  icon: Icon(_iconForTheme(m), size: 16),
                  label: Text(m.label),
                ),
            ],
            selected: {activeTheme},
            onSelectionChanged: (sel) => ref
                .read(pdksDashboardProvider.notifier)
                .setCurrentUserThemeMode(sel.first),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// ORTAK BİLEŞEN 1C: PERSONEL PROFİL FOTOĞRAFI / MİNİMALİST STÜDYO AVATARI
// ============================================================================
class EmployeeProfileAvatar extends StatelessWidget {
  final Employee employee;
  final double size;
  final Color? borderColor;

  const EmployeeProfileAvatar({
    super.key,
    required this.employee,
    this.size = 44,
    this.borderColor,
  });

  static const List<List<Color>> _palettes = <List<Color>>[
    [Color(0xFF0F172A), Color(0xFF334155)],
    [Color(0xFF0369A1), Color(0xFF0284C7)],
    [Color(0xFF047857), Color(0xFF10B981)],
    [Color(0xFF4338CA), Color(0xFF6366F1)],
    [Color(0xFFB45309), Color(0xFFF59E0B)],
    [Color(0xFFBE123C), Color(0xFFF43F5E)],
  ];

  String _initials(String fullName) {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) return 'P';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final rawPath = employee.photoPath?.trim() ?? '';
    final bool isPreset = rawPath.startsWith('preset:');
    final int paletteIndex = isPreset
        ? ((int.tryParse(rawPath.replaceFirst('preset:', '')) ?? 1) - 1)
            .clamp(0, _palettes.length - 1)
        : (employee.id.abs() % _palettes.length);
    final colors = _palettes[paletteIndex];

    Widget inner;
    if (rawPath.isNotEmpty && !isPreset) {
      final file = File(rawPath);
      if (file.existsSync()) {
        inner = Image.file(
          file,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildFallback(colors),
        );
      } else {
        inner = _buildFallback(colors);
      }
    } else {
      inner = _buildFallback(colors);
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: borderColor ?? HasibuPalette.of(context).border,
          width: 1.5,
        ),
      ),
      child: ClipOval(child: inner),
    );
  }

  Widget _buildFallback(List<Color> colors) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            bottom: -size * 0.14,
            child: Icon(
              Icons.person_rounded,
              size: size * 0.85,
              color: Colors.white.withValues(alpha: 0.18),
            ),
          ),
          Text(
            _initials(employee.fullName),
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: size * 0.36,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  /// Windows masaüstünde yerel dosya seçici penceresini açar.
  static Future<String?> pickPhotoFromDesktop() async {
    if (!Platform.isWindows) return null;
    try {
      final result = await Process.run(
        'power' 'shell.exe',
        <String>[
          '-NoProfile',
          '-Command',
          "Add-Type -AssemblyName System.Windows.Forms; "
              "\$f = New-Object System.Windows.Forms.OpenFileDialog; "
              "\$f.Title = 'Personel Profil Fotoğrafı Seçin'; "
              "\$f.Filter = 'Görsel Dosyaları (*.jpg;*.jpeg;*.png;*.webp)|*.jpg;*.jpeg;*.png;*.webp'; "
              "if (\$f.ShowDialog() -eq 'OK') { Write-Output \$f.FileName }",
        ],
      );
      final path = result.stdout.toString().trim();
      return path.isNotEmpty ? path : null;
    } catch (_) {
      return null;
    }
  }

  /// Windows masaüstünde yerel klasör seçici penceresini açar.
  static Future<String?> pickFolderFromDesktop() async {
    if (!Platform.isWindows) return null;
    try {
      final result = await Process.run(
        'power' 'shell.exe',
        <String>[
          '-NoProfile',
          '-Command',
          "Add-Type -AssemblyName System.Windows.Forms; "
              "\$d = New-Object System.Windows.Forms.FolderBrowserDialog; "
              "\$d.Description = 'Google Drive Senkronizasyon Klasörünü Seçin'; "
              "if (\$d.ShowDialog() -eq 'OK') { Write-Output \$d.SelectedPath }",
        ],
      );
      final path = result.stdout.toString().trim();
      return path.isNotEmpty ? path : null;
    } catch (_) {
      return null;
    }
  }

  /// Windows masaüstünde resmi özlük evrakı dijital kopyası (.pdf, .jpg, .png, .docx) seçiciyi açar.
  static Future<String?> pickDocumentFromDesktop() async {
    if (!Platform.isWindows) return null;
    try {
      final result = await Process.run(
        'power' 'shell.exe',
        <String>[
          '-NoProfile',
          '-Command',
          "Add-Type -AssemblyName System.Windows.Forms; "
              "\$f = New-Object System.Windows.Forms.OpenFileDialog; "
              "\$f.Title = 'Personel Özlük Dosyası Resmi Evrak Dijital Kopyasını Seçin'; "
              "\$f.Filter = 'Resmi Evrak & Görsel (*.pdf;*.jpg;*.jpeg;*.png;*.webp;*.doc;*.docx)|*.pdf;*.jpg;*.jpeg;*.png;*.webp;*.doc;*.docx|Tüm Dosyalar (*.*)|*.*'; "
              "if (\$f.ShowDialog() -eq 'OK') { Write-Output \$f.FileName }",
        ],
      );
      final path = result.stdout.toString().trim();
      return path.isNotEmpty ? path : null;
    } catch (_) {
      return null;
    }
  }

  /// Dijital evrak dosyasını varsayılan görüntüleyicide veya Gezgin'de açar.
  static Future<void> openDigitalDocument(String filePath) async {
    if (!Platform.isWindows || filePath.trim().isEmpty) return;
    try {
      final f = File(filePath.trim());
      if (f.existsSync()) {
        await Process.run('explorer', <String>[f.path]);
      }
    } catch (e) {
      debugPrint('HasibuSettingsView: openDigitalDocument hatası ($filePath): $e');
    }
  }
}

// ============================================================================
// ORTAK BİLEŞEN 1D: TENFEI D35 CİHAZ BAĞLANTI KONTROLÜ & TANILAMA PENCERESİ
// ============================================================================
Future<void> showTerminalDiagnosticsDialog(
  BuildContext context,
  WidgetRef ref, {
  Branch? initialBranch,
}) async {
  final initState = ref.read(pdksDashboardProvider);
  Branch selectedBranch = initialBranch ??
      initState.branches.firstWhere(
        (b) => b.hasTerminal,
        orElse: () => initState.branches.first,
      );
  final ipCtrl = TextEditingController(
    text: selectedBranch.terminalIp ?? '',
  );
  final portCtrl = TextEditingController(
    text: selectedBranch.terminalPort.toString(),
  );

  bool isTesting = false;
  bool isPulling = false;
  TenfeiConnectionDiagnostics? lastDiag;
  String? pullFeedback;

  await showDialog<void>(
    context: context,
    builder: (dialogCtx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        final pal = HasibuPalette.of(ctx);
        final branches = ref.watch(
          pdksDashboardProvider.select((s) => s.branches),
        );

        Future<void> runDiagnostic() async {
          setDialogState(() {
            isTesting = true;
            pullFeedback = null;
          });
          final ip = ipCtrl.text.trim();
          final port = int.tryParse(portCtrl.text.trim()) ?? 4370;
          final updatedBranch = selectedBranch.copyWith(
            hasTerminal: true,
            terminalIp: ip,
            terminalPort: port,
          );
          await ref.read(pdksDashboardProvider.notifier).saveBranch(updatedBranch);
          selectedBranch = updatedBranch;
          final diag = await ref
              .read(pdksDashboardProvider.notifier)
              .testBranchTerminalConnection(updatedBranch);
          if (dialogCtx.mounted) {
            setDialogState(() {
              isTesting = false;
              lastDiag = diag;
            });
          }
        }

        Future<void> pullNow() async {
          setDialogState(() {
            isPulling = true;
            pullFeedback = null;
          });
          final ip = ipCtrl.text.trim();
          final port = int.tryParse(portCtrl.text.trim()) ?? 4370;
          final updatedBranch = selectedBranch.copyWith(
            hasTerminal: true,
            terminalIp: ip,
            terminalPort: port,
          );
          await ref.read(pdksDashboardProvider.notifier).saveBranch(updatedBranch);
          selectedBranch = updatedBranch;
          final summary = await ref
              .read(pdksDashboardProvider.notifier)
              .pullFromTenfeiTerminals(onlyBranchId: updatedBranch.id);
          final latestState = ref.read(pdksDashboardProvider);
          if (dialogCtx.mounted) {
            setDialogState(() {
              isPulling = false;
              pullFeedback = latestState.terminalStatusMessage;
            });
            if (summary != null) {
              await showTerminalPullResultDialog(dialogCtx, ref, summary);
            }
          }
        }

        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.network_check_rounded, color: Color(0xFF0284C7)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Cihaz Bağlantı Kontrolü & Canlı Veri Çekme (TCP 4370)',
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    color: pal.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Aynı yerel ağdaki Tenfei D35 / ZKTeco yüz ve parmak izi terminaline doğrudan TCP 4370 soketi ve CMD_AUTH (1102) el sıkışması ile bağlanarak erişimi ve cihaz hafızasındaki hareket sayısını kontrol edin.',
                    style: TextStyle(fontSize: 12.5, color: pal.textSecondary),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    initialValue: selectedBranch.id,
                    decoration: const InputDecoration(
                      labelText: 'Kontrol Edilecek Şube / Terminal',
                      prefixIcon: Icon(Icons.router_outlined),
                    ),
                    items: [
                      for (final b in branches)
                        DropdownMenuItem<int>(
                          value: b.id,
                          child: Text(
                            (b.terminalIp != null && b.terminalIp!.isNotEmpty)
                                ? '${b.name} (${b.terminalIp}:${b.terminalPort})'
                                : '${b.name} (Terminal IP tanımlı değil)',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (val) {
                      if (val == null) return;
                      final found = branches.firstWhere((b) => b.id == val);
                      setDialogState(() {
                        selectedBranch = found;
                        ipCtrl.text = found.terminalIp ?? '';
                        portCtrl.text = found.terminalPort.toString();
                        lastDiag = null;
                        pullFeedback = null;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: ipCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Terminal IP Adresi',
                            hintText: '192.168.1.100',
                            prefixIcon: Icon(Icons.lan_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: portCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'TCP Port',
                            hintText: '4370',
                            prefixIcon: Icon(Icons.settings_ethernet_rounded),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        key: const ValueKey('run_terminal_diag_button'),
                        onPressed: isTesting ? null : runDiagnostic,
                        icon: isTesting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.radar_rounded, size: 18),
                        label: Text(
                          isTesting
                              ? 'Cihaz Test Ediliyor...'
                              : 'Bağlantıyı Şimdi Test Et',
                        ),
                      ),
                      FilledButton.tonalIcon(
                        key: const ValueKey('diag_pull_terminal_logs_button'),
                        onPressed: isPulling ? null : pullNow,
                        icon: isPulling
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.download_rounded, size: 18),
                        label: Text(
                          isPulling
                              ? 'Hareketler Çekiliyor...'
                              : 'Cihazdan Hareketleri Şimdi Çek',
                        ),
                      ),
                    ],
                  ),
                  if (lastDiag != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: lastDiag!.isReachable
                            ? const Color(0xFF059669).withValues(alpha: 0.12)
                            : const Color(0xFFDC2626).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: lastDiag!.isReachable
                              ? const Color(0xFF059669)
                              : const Color(0xFFDC2626),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                lastDiag!.isReachable
                                    ? Icons.check_circle_rounded
                                    : Icons.error_outline_rounded,
                                color: lastDiag!.isReachable
                                    ? const Color(0xFF059669)
                                    : const Color(0xFFDC2626),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  lastDiag!.isReachable
                                      ? 'BAĞLANTI BAŞARILI • CİHAZ ÇEVRİMİÇİ'
                                      : 'BAĞLANTI KURULAMADI',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                    color: lastDiag!.isReachable
                                        ? const Color(0xFF059669)
                                        : const Color(0xFFDC2626),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            lastDiag!.message,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: pal.textPrimary,
                            ),
                          ),
                          if (lastDiag!.isReachable) ...[
                            const SizedBox(height: 6),
                            Text(
                              '• Protokol: TCP 4370 (CMD_CONNECT 1000 + CMD_AUTH 1102 Doğrulandı)\n'
                              '• Yanıt Süresi (Ping/Handshake): ${lastDiag!.latencyMs} ms\n'
                              '• Cihaz Hafızasındaki Hareket Kaydı: ${lastDiag!.recordCount} adet',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: pal.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  if (pullFeedback != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFF0284C7).withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.fact_check_rounded,
                            color: Color(0xFF0284C7),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              pullFeedback!,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: pal.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Kapat'),
            ),
          ],
        );
      },
    ),
  );

  ipCtrl.dispose();
  portCtrl.dispose();
}

/// Tarih bilgisini sağa sola kaydırmak yerine üzerine dokunulduğunda doğrudan takvim (showDatePicker) açar.
Future<void> pickPdksDateWithCalendar(
  BuildContext context,
  WidgetRef ref,
) async {
  final currentKey = ref.read(pdksDashboardProvider).selectedDate;
  final initialDate = DateTime.tryParse(currentKey) ?? DateTime.now();
  final now = DateTime.now();
  final picked = await showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: DateTime(2020, 1, 1),
    lastDate: DateTime(now.year + 2, 12, 31),
    helpText: 'PDKS Yoklama Tarihini Seçin',
    cancelText: 'İptal',
    confirmText: 'Tarihi Seç',
  );
  if (picked != null) {
    final key =
        '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    ref.read(pdksDashboardProvider.notifier).setSelectedDate(key);
  }
}

/// Terminalden canlı veri çekimini başlatır ve işlem tamamlandığında sonucu bilgi popup'ı ile gösterir.
Future<void> pullTerminalAndShowPopup(
  BuildContext context,
  WidgetRef ref, {
  int? onlyBranchId,
}) async {
  final summary = await ref
      .read(pdksDashboardProvider.notifier)
      .pullFromTenfeiTerminals(onlyBranchId: onlyBranchId);
  if (summary != null && context.mounted) {
    await showTerminalPullResultDialog(context, ref, summary);
  }
}

/// Terminal veri çekimi tamamlandıktan sonra kullanıcıya detaylı bilgi veren Popup penceresi.
Future<void> showTerminalPullResultDialog(
  BuildContext context,
  WidgetRef ref,
  TerminalPullSummary summary,
) async {
  final selectedDateLabel =
      PdksDashboardNotifier.formatDisplayDate(summary.selectedDateAfterPull);
  final latestDateLabel = summary.latestPulledDateKey != null
      ? PdksDashboardNotifier.formatDisplayDate(summary.latestPulledDateKey!)
      : 'Kayıt Bulunamadı';
  final timeStr =
      '${summary.pulledAt.hour.toString().padLeft(2, '0')}:${summary.pulledAt.minute.toString().padLeft(2, '0')}:${summary.pulledAt.second.toString().padLeft(2, '0')}';

  await showDialog<void>(
    context: context,
    builder: (dialogCtx) {
      final pal = HasibuPalette.of(dialogCtx);
      final statusColor = summary.anyReachable
          ? const Color(0xFF059669)
          : const Color(0xFFDC2626);

      return AlertDialog(
        key: const ValueKey('terminal_pull_result_popup'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              summary.anyReachable
                  ? Icons.check_circle_rounded
                  : Icons.error_outline_rounded,
              color: statusColor,
              size: 24,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                summary.anyReachable
                    ? 'Terminal Veri Çekimi Tamamlandı'
                    : 'Terminale Ulaşılamadı — Veri Çekilemedi',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: pal.textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Text(
                    summary.anyReachable
                        ? 'Cihaz hafızasından toplam ${summary.totalFetched} hareket okundu ve ${summary.newInserted} yeni giriş/çıkış kaydı veritabanına eklendi (Saat: $timeStr).'
                        : 'Ağdaki Tenfei D35 (TCP 4370) yüz tanıma terminaline ulaşılamadı. Cihazın açık olduğunu ve aynı yerel ağda bulunduğunu kontrol edin (Saat: $timeStr).',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: pal.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _EmployeeHistorySummaryChip(
                      label: 'Cihazdan Okunan',
                      value: '${summary.totalFetched} Hareket',
                      color: const Color(0xFF0284C7),
                    ),
                    _EmployeeHistorySummaryChip(
                      label: 'Yeni Eklenen',
                      value: '${summary.newInserted} Yeni Kayıt',
                      color: const Color(0xFF059669),
                    ),
                    _EmployeeHistorySummaryChip(
                      label: 'Seçili Gün ($selectedDateLabel)',
                      value: '${summary.logsCountForSelectedDate} Hareket',
                      color: const Color(0xFF7C3AED),
                    ),
                    _EmployeeHistorySummaryChip(
                      label: 'Cihazdaki Son Tarih',
                      value: latestDateLabel,
                      color: const Color(0xFFD97706),
                    ),
                  ],
                ),
                if (summary.branchMessages.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    'Terminal Bağlantı & Çekim Detayları:',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: pal.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  for (final msg in summary.branchMessages)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: pal.subtle,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: pal.border),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            msg.contains('ulaşılamadı')
                                ? Icons.portable_wifi_off_rounded
                                : Icons.router_rounded,
                            size: 16,
                            color: msg.contains('ulaşılamadı')
                                ? const Color(0xFFDC2626)
                                : const Color(0xFF059669),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              msg,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: pal.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          if (summary.latestPulledDateKey != null &&
              summary.latestPulledDateKey != summary.selectedDateAfterPull)
            OutlinedButton.icon(
              key: const ValueKey('terminal_pull_jump_latest_date_button'),
              onPressed: () {
                ref
                    .read(pdksDashboardProvider.notifier)
                    .setSelectedDate(summary.latestPulledDateKey!);
                Navigator.of(dialogCtx).pop();
              },
              icon: const Icon(Icons.event_available_rounded, size: 16),
              label: Text('Son Hareket Gününe Git ($latestDateLabel)'),
            ),
          FilledButton.icon(
            key: const ValueKey('terminal_pull_popup_ok_button'),
            onPressed: () => Navigator.of(dialogCtx).pop(),
            icon: const Icon(Icons.check_rounded, size: 16),
            label: const Text('Tamam'),
          ),
        ],
      );
    },
  );
}

// ============================================================================
// ORTAK BİLEŞEN 1E: PERSONEL GEÇMİŞİ & DİJİTAL ÖZLÜK DOSYASI (RESMİ EVRAKLAR)
// ============================================================================
Future<void> showEmployeeHistoryAndDossierDialog(
  BuildContext context,
  WidgetRef ref,
  Employee employee, {
  int initialTabIndex = 0,
}) async {
  int activeTab = initialTabIndex.clamp(0, 1);
  PersonnelDocumentCategory selectedCategory =
      PersonnelDocumentCategory.kimlikFotokopisi;
  final docTitleCtrl = TextEditingController(
    text: PersonnelDocumentCategory.kimlikFotokopisi.label,
  );
  final docPathCtrl = TextEditingController();
  final docNotesCtrl = TextEditingController();

  await showDialog<void>(
    context: context,
    builder: (dialogCtx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        final pal = HasibuPalette.of(ctx);
        final state = ref.watch(pdksDashboardProvider);
        final notifier = ref.read(pdksDashboardProvider.notifier);

        final currentStatus = state.dailyStatuses.firstWhere(
          (s) => s.employee.id == employee.id,
          orElse: () => state.dailyStatuses.first,
        );
        final emp = currentStatus.employee;
        final historyEntries = notifier.getEmployeeHistory(emp);
        final empDocs = state.documentsForEmployee(emp.id);

        final int presentDays = historyEntries
            .where((e) => e.state == DailyAttendanceState.present)
            .length;
        final int lateDays = historyEntries
            .where((e) => e.state == DailyAttendanceState.late)
            .length;
        final int totalLateMins =
            historyEntries.fold<int>(0, (sum, e) => sum + e.lateMinutes);
        final int totalOvertimeMins =
            historyEntries.fold<int>(0, (sum, e) => sum + e.overtimeMinutes);
        final int leaveOrSickDays = historyEntries
            .where(
              (e) =>
                  e.state == DailyAttendanceState.onLeave ||
                  e.state == DailyAttendanceState.sickReport,
            )
            .length;

        final mandatoryCategories = PersonnelDocumentCategory.values
            .where((c) => c.isMandatory)
            .toList(growable: false);
        final uploadedCategorySet = empDocs.map((d) => d.category).toSet();
        final int completedMandatoryCount = mandatoryCategories
            .where((c) => uploadedCategorySet.contains(c))
            .length;

        return AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          titlePadding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
          contentPadding: const EdgeInsets.fromLTRB(18, 6, 18, 14),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  EmployeeProfileAvatar(employee: emp, size: 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              emp.fullName,
                              style: TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w800,
                                color: pal.textPrimary,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: pal.chip,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Sicil / Kart No: #${emp.cardNo}',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: pal.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              '${currentStatus.branch.name} • ${currentStatus.department.name} • ${emp.title} • '
                              'İşe Giriş: ${PdksDashboardNotifier.formatDisplayDate(emp.hireDate, includeTodayBadge: false)}',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: pal.textSecondary,
                              ),
                            ),
                            if (emp.hasExitDate)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDC2626)
                                      .withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  'İşten Çıkış: ${PdksDashboardNotifier.formatDisplayDate(emp.normalizedExitDate!, includeTodayBadge: false)} • '
                                  '${emp.isSeparatedNow ? "İŞTEN AYRILDI" : "ÇIKIŞ PLANLI"}',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFDC2626),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Kapat',
                    onPressed: () => Navigator.of(dialogCtx).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // BUGÜNKÜ DURUM DETAYI & HIZLI AKSİYON PANELİ (Kart üzerinden buraya taşındı)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: pal.subtle,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: pal.border),
                ),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _stateColor(currentStatus.state)
                                .withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            currentStatus.lateMinutes > 0
                                ? '${currentStatus.state.label} (+${currentStatus.lateMinutes} dk)'
                                : currentStatus.state.label,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: _stateColor(currentStatus.state),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            currentStatus.firstCheckIn != null
                                ? 'Giriş: ${currentStatus.firstCheckIn!.timeFormatted}'
                                    '${currentStatus.lastCheckOut != null && currentStatus.lastCheckOut!.id != currentStatus.firstCheckIn!.id ? " • Çıkış: ${currentStatus.lastCheckOut!.timeFormatted}" : " • Çıkış Yok"}'
                                    ' (${currentStatus.firstCheckIn!.verifyMethod.label}) • Vardiya: ${currentStatus.shift.startTime}-${currentStatus.shift.endTime}'
                                : '${currentStatus.leaveRecord?.note ?? "Giriş Yok"} • Vardiya: ${currentStatus.shift.startTime}-${currentStatus.shift.endTime}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: pal.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (currentStatus.hasMissingCheckOut)
                          FilledButton.tonalIcon(
                            key: ValueKey('quick_complete_out_${emp.cardNo}'),
                            style: FilledButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              backgroundColor: const Color(0xFFD97706)
                                  .withValues(alpha: 0.18),
                              foregroundColor: const Color(0xFFF59E0B),
                            ),
                            onPressed: () => notifier
                                .quickCompleteMissingCheckOut(currentStatus),
                            icon: const Icon(Icons.bolt_rounded, size: 15),
                            label: Text(
                              'Eksik Çıkış (${currentStatus.shift.endTime} Tamamla)',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        PopupMenuButton<LeaveType>(
                          tooltip: 'Hızlı İzin / Rapor Durumu Ata',
                          onSelected: (leaveType) {
                            notifier.assignLeaveOrReport(
                              employeeId: emp.id,
                              leaveType: leaveType,
                              note: '${leaveType.label} (Detay Penceresi)',
                            );
                          },
                          itemBuilder: (_) => [
                            for (final lt in LeaveType.values)
                              PopupMenuItem<LeaveType>(
                                value: lt,
                                child: Text('${lt.label} Olarak İşaretle'),
                              ),
                          ],
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: pal.card,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: pal.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.edit_calendar_rounded,
                                  size: 14,
                                  color: pal.textSecondary,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'Durum Ata',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: pal.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<int>(
                  key: const ValueKey('employee_detail_tab_selector'),
                  segments: [
                    ButtonSegment<int>(
                      value: 0,
                      icon: const Icon(Icons.history_rounded, size: 16),
                      label: Text(
                        'Personel Geçmişi (${historyEntries.length} Gün)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    ButtonSegment<int>(
                      value: 1,
                      icon: const Icon(Icons.folder_shared_outlined, size: 16),
                      label: Text(
                        'Özlük Dosyası & Resmi Evraklar (${empDocs.length})',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  selected: {activeTab},
                  onSelectionChanged: (sel) =>
                      setDialogState(() => activeTab = sel.first),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 780,
            height: 520,
            child: activeTab == 0
                ? ListView(
                    children: [
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _EmployeeHistorySummaryChip(
                            label: 'Zamanında Giriş',
                            value: '$presentDays Gün',
                            color: const Color(0xFF059669),
                          ),
                          _EmployeeHistorySummaryChip(
                            label: 'Geç Kalma',
                            value: '$lateDays Kez ($totalLateMins dk)',
                            color: const Color(0xFFD97706),
                          ),
                          _EmployeeHistorySummaryChip(
                            label: 'Toplam Fazla Mesai',
                            value: '+$totalOvertimeMins dk',
                            color: const Color(0xFF059669),
                          ),
                          _EmployeeHistorySummaryChip(
                            label: 'İzinli / Raporlu',
                            value: '$leaveOrSickDays Gün',
                            color: const Color(0xFF0284C7),
                          ),
                          _EmployeeHistorySummaryChip(
                            label: 'Kalan Yıllık İzin',
                            value: '${emp.remainingAnnualLeave} Gün',
                            color: const Color(0xFF7C3AED),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Kronolojik Giriş-Çıkış, Mesai & İzin Geçmişi',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: pal.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final entry in historyEntries)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: pal.subtle,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: pal.border),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: pal.card,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: pal.border),
                                ),
                                child: Text(
                                  entry.dateKey,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12.5,
                                    color: pal.textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      entry.firstCheckIn != null
                                          ? 'İlk Giriş: ${entry.firstCheckIn!.timeFormatted}'
                                              '${entry.lastCheckOut != null && entry.lastCheckOut!.id != entry.firstCheckIn!.id ? " • Son Çıkış: ${entry.lastCheckOut!.timeFormatted}" : ""}'
                                              ' (${entry.firstCheckIn!.verifyMethod.label})'
                                          : (entry.leaveRecord?.note ??
                                              (entry.state ==
                                                      DailyAttendanceState
                                                          .terminated
                                                  ? 'İşten ayrıldı (${PdksDashboardNotifier.formatDisplayDate(emp.normalizedExitDate ?? entry.dateKey, includeTodayBadge: false)})'
                                                  : (entry.state ==
                                                          DailyAttendanceState
                                                              .notYetHired
                                                      ? 'İşe giriş tarihi (${PdksDashboardNotifier.formatDisplayDate(emp.hireDate, includeTodayBadge: false)}) öncesi'
                                                      : 'Cihaz veya mobil giriş kaydı bulunmuyor'))),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12.5,
                                        color: pal.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Vardiya: ${currentStatus.shift.name} (${currentStatus.shift.startTime}-${currentStatus.shift.endTime}) • '
                                      'Net Çalışma: ${entry.workedDurationFormatted}'
                                      '${entry.overtimeMinutes > 0 ? " • +${entry.overtimeMinutes} dk Mesai" : ""}'
                                      '${entry.earlyLeaveMinutes > 0 ? " • -${entry.earlyLeaveMinutes} dk Erken Çıkış" : ""}',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: pal.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _stateColor(entry.state)
                                      .withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  entry.lateMinutes > 0
                                      ? '${entry.state.label} (+${entry.lateMinutes} dk)'
                                      : entry.state.label,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: _stateColor(entry.state),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  )
                : ListView(
                    children: [
                      // 1. ZORUNLU ÖZLÜK EVRAKLARI KONTROL LİSTESİ
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: pal.subtle,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: pal.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    'Resmi Özlük Dosyası Kontrol Listesi ($completedMandatoryCount / ${mandatoryCategories.length} Zorunlu Evrak)',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: pal.textPrimary,
                                    ),
                                  ),
                                ),
                                Text(
                                  'Eksik evraka dokunarak hızlı seçebilirsiniz',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: pal.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final cat in mandatoryCategories)
                                  InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: () {
                                      setDialogState(() {
                                        selectedCategory = cat;
                                        docTitleCtrl.text = cat.label;
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: uploadedCategorySet.contains(cat)
                                            ? const Color(0xFF059669)
                                                .withValues(alpha: 0.14)
                                            : const Color(0xFFD97706)
                                                .withValues(alpha: 0.14),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color:
                                              uploadedCategorySet.contains(cat)
                                                  ? const Color(0xFF059669)
                                                  : const Color(0xFFD97706),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            uploadedCategorySet.contains(cat)
                                                ? Icons.check_circle_rounded
                                                : Icons.upload_file_rounded,
                                            size: 14,
                                            color: uploadedCategorySet
                                                    .contains(cat)
                                                ? const Color(0xFF059669)
                                                : const Color(0xFFD97706),
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            cat.label,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: uploadedCategorySet
                                                      .contains(cat)
                                                  ? const Color(0xFF059669)
                                                  : const Color(0xFFD97706),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // 2. YENİ RESMİ EVRAK DİJİTAL KOPYASI EKLEME FORMU
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: pal.card,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: pal.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Yeni Resmi Evrak Dijital Kopyası Ekle (.PDF, .JPG, .PNG, .DOCX)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: pal.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<
                                      PersonnelDocumentCategory>(
                                    isExpanded: true,
                                    initialValue: selectedCategory,
                                    decoration: const InputDecoration(
                                      labelText: 'Resmi Evrak Türü',
                                    ),
                                    items: [
                                      for (final c
                                          in PersonnelDocumentCategory.values)
                                        DropdownMenuItem(
                                          value: c,
                                          child: Text(
                                            c.label,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                    ],
                                    onChanged: (val) {
                                      if (val == null) return;
                                      setDialogState(() {
                                        selectedCategory = val;
                                        docTitleCtrl.text = val.label;
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextField(
                                    key: const ValueKey(
                                      'dossier_doc_title_field',
                                    ),
                                    controller: docTitleCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'Evrak Başlığı / Adı',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    key: const ValueKey(
                                      'dossier_doc_path_field',
                                    ),
                                    controller: docPathCtrl,
                                    decoration: const InputDecoration(
                                      labelText:
                                          'Dijital Kopya Dosya Yolu (.pdf / .jpg / .png)',
                                      hintText:
                                          r'Örn: C:\Evraklar\00001_Kimlik_Kopyasi.pdf',
                                      prefixIcon: Icon(
                                        Icons.description_outlined,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ),
                                if (Platform.isWindows) ...[
                                  const SizedBox(width: 8),
                                  OutlinedButton.icon(
                                    onPressed: () async {
                                      final picked = await EmployeeProfileAvatar
                                          .pickDocumentFromDesktop();
                                      if (picked != null) {
                                        setDialogState(
                                          () => docPathCtrl.text = picked,
                                        );
                                      }
                                    },
                                    icon: const Icon(
                                      Icons.attach_file_rounded,
                                      size: 17,
                                    ),
                                    label: const Text('Bilgisayardan Seç'),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: docNotesCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'Evrak Notu / Açıklama',
                                      hintText:
                                          'Örn: Islak imzalı aslı arşivde, dijital kopyası doğrulandı',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                FilledButton.icon(
                                  key: const ValueKey(
                                    'dossier_add_document_button',
                                  ),
                                  onPressed: () async {
                                    final title = docTitleCtrl.text.trim();
                                    if (title.isEmpty) return;
                                    final path = docPathCtrl.text.trim().isEmpty
                                        ? 'Dijital_Arsiv/${emp.cardNo}_${selectedCategory.name}.pdf'
                                        : docPathCtrl.text.trim();
                                    final doc = PersonnelDocument(
                                      id: 'doc_${emp.id}_${DateTime.now().millisecondsSinceEpoch}',
                                      employeeId: emp.id,
                                      category: selectedCategory,
                                      title: title,
                                      filePath: path,
                                      uploadDate: state.selectedDate,
                                      notes: docNotesCtrl.text.trim(),
                                    );
                                    await notifier.savePersonnelDocument(doc);
                                    if (dialogCtx.mounted) {
                                      setDialogState(() {
                                        docPathCtrl.clear();
                                        docNotesCtrl.clear();
                                      });
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.cloud_upload_outlined,
                                    size: 17,
                                  ),
                                  label: const Text('Özlük Dosyasına Ekle'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Kayıtlı Dijital Özlük Evrakları (${empDocs.length})',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: pal.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (empDocs.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'Bu personelin özlük dosyasına henüz dijital evrak eklenmemiş.',
                            style: TextStyle(color: pal.textSecondary),
                          ),
                        ),
                      for (final doc in empDocs)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: pal.subtle,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: pal.border),
                          ),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0284C7)
                                    .withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                doc.filePath.toLowerCase().endsWith('.pdf')
                                    ? Icons.picture_as_pdf_rounded
                                    : Icons.insert_drive_file_rounded,
                                color: const Color(0xFF0284C7),
                                size: 20,
                              ),
                            ),
                            title: Text(
                              '${doc.title} (${doc.category.label})',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: pal.textPrimary,
                              ),
                            ),
                            subtitle: Text(
                              'Dijital Kopya: ${doc.filePath} • Yükleme: ${doc.uploadDate}'
                              '${doc.notes.isNotEmpty ? " • ${doc.notes}" : ""}',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: pal.textSecondary,
                              ),
                            ),
                            trailing: Wrap(
                              spacing: 4,
                              children: [
                                if (Platform.isWindows &&
                                    File(doc.filePath).existsSync())
                                  OutlinedButton.icon(
                                    onPressed: () => EmployeeProfileAvatar
                                        .openDigitalDocument(doc.filePath),
                                    icon: const Icon(
                                      Icons.open_in_new_rounded,
                                      size: 15,
                                    ),
                                    label: const Text('Evrakı Aç'),
                                  ),
                                IconButton(
                                  tooltip: 'Evrakı Sil',
                                  color: const Color(0xFFDC2626),
                                  onPressed: () =>
                                      notifier.deletePersonnelDocument(doc.id),
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    size: 19,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Kapat'),
            ),
          ],
        );
      },
    ),
  );

  docTitleCtrl.dispose();
  docPathCtrl.dispose();
  docNotesCtrl.dispose();
}

Color attendanceStateColor(DailyAttendanceState state) {
  switch (state) {
    case DailyAttendanceState.present:
      return const Color(0xFF059669);
    case DailyAttendanceState.late:
      return const Color(0xFFD97706);
    case DailyAttendanceState.onLeave:
      return const Color(0xFF0284C7);
    case DailyAttendanceState.sickReport:
      return const Color(0xFF7C3AED);
    case DailyAttendanceState.absent:
      return const Color(0xFFDC2626);
    case DailyAttendanceState.terminated:
      return const Color(0xFF64748B);
    case DailyAttendanceState.notYetHired:
      return const Color(0xFF94A3B8);
  }
}

Color _stateColor(DailyAttendanceState state) => attendanceStateColor(state);

Future<void> showCreateHrRequestDialog(
  BuildContext context,
  WidgetRef ref, {
  required Employee employee,
  bool allowEmployeeSwitch = false,
  HrRequestType? initialRequestType,
}) async {
  final state = ref.read(pdksDashboardProvider);
  final activeStatuses = state.dailyStatuses
      .where((s) => !s.employee.isSeparatedNow || s.employee.id == employee.id)
      .toList(growable: false);
  final selectableStatuses =
      activeStatuses.isNotEmpty ? activeStatuses : state.dailyStatuses;
  Employee selectedEmp = employee;
  HrRequestType selectedType =
      initialRequestType ?? HrRequestType.annualLeave;
  LeaveType selectedLeaveType = LeaveType.yillikIzin;
  bool isCheckInCorrection = false;

  final targetDateCtrl = TextEditingController(text: state.selectedDate);
  final endDateCtrl = TextEditingController(text: state.selectedDate);
  final timeCtrl = TextEditingController(text: '18:00');
  final overtimeCtrl = TextEditingController(text: '90');
  final reasonCtrl = TextEditingController(
    text: 'Resmi mazeret / vardiya bildirim talebi',
  );

  await showDialog<void>(
    context: context,
    builder: (dialogCtx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: const Text(
          'Yeni İK Talebi Oluştur (İzin / Mesai / Hareket Düzeltme)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (allowEmployeeSwitch) ...[
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    initialValue: selectedEmp.id,
                    decoration: const InputDecoration(
                      labelText: 'Personel Seçin',
                    ),
                    items: [
                      for (final s in selectableStatuses)
                        DropdownMenuItem<int>(
                          value: s.employee.id,
                          child: Text(
                            '${s.employee.fullName} (#${s.employee.cardNo})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (empId) {
                      if (empId == null) return;
                      final match = selectableStatuses.where(
                        (s) => s.employee.id == empId,
                      );
                      if (match.isNotEmpty) {
                        setDialogState(
                          () => selectedEmp = match.first.employee,
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                ],
                DropdownButtonFormField<HrRequestType>(
                  key: const ValueKey('hr_req_type_dropdown'),
                  isExpanded: true,
                  initialValue: selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Talep Türü',
                  ),
                  items: [
                    for (final t in HrRequestType.values)
                      DropdownMenuItem(
                        value: t,
                        child: Text(t.label, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedType = val);
                    }
                  },
                ),
                const SizedBox(height: 10),
                if (selectedType == HrRequestType.annualLeave) ...[
                  DropdownButtonFormField<LeaveType>(
                    isExpanded: true,
                    initialValue: selectedLeaveType,
                    decoration: const InputDecoration(
                      labelText: 'İzin Türü',
                    ),
                    items: [
                      for (final lt in LeaveType.values)
                        DropdownMenuItem(
                          value: lt,
                          child: Text(lt.label),
                        ),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setDialogState(() => selectedLeaveType = v);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: targetDateCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Başlangıç (YYYY-AA-GG)',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: endDateCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Bitiş (YYYY-AA-GG)',
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  TextField(
                    controller: targetDateCtrl,
                    decoration: const InputDecoration(
                      labelText: 'İlgili Tarih (YYYY-AA-GG)',
                    ),
                  ),
                ],
                if (selectedType == HrRequestType.missingPunchCorrection) ...[
                  const SizedBox(height: 10),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: true, label: Text('Unutulan Giriş')),
                      ButtonSegment(
                        value: false,
                        label: Text('Unutulan Çıkış'),
                      ),
                    ],
                    selected: {isCheckInCorrection},
                    onSelectionChanged: (s) => setDialogState(
                      () => isCheckInCorrection = s.first,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: timeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Gerçekleşen Saat (SS:DD)',
                      hintText: '18:00',
                    ),
                  ),
                ],
                if (selectedType == HrRequestType.overtimeApproval) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: overtimeCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Fazla Mesai Süresi (Dakika)',
                      hintText: '90',
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                TextField(
                  key: const ValueKey('hr_req_reason_field'),
                  controller: reasonCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Talep Açıklaması / Gerekçe',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('İptal'),
          ),
          FilledButton.icon(
            key: const ValueKey('submit_hr_request_button'),
            onPressed: () async {
              final req = HrRequest(
                id: 'req_${selectedEmp.id}_${DateTime.now().millisecondsSinceEpoch}',
                employeeId: selectedEmp.id,
                employeeCardNo: selectedEmp.cardNo,
                employeeName: selectedEmp.fullName,
                type: selectedType,
                status: HrRequestStatus.pending,
                targetDate: targetDateCtrl.text.trim(),
                endDate: selectedType == HrRequestType.annualLeave
                    ? endDateCtrl.text.trim()
                    : null,
                requestedTime:
                    selectedType == HrRequestType.missingPunchCorrection
                        ? timeCtrl.text.trim()
                        : null,
                isCheckInCorrection: isCheckInCorrection,
                overtimeMinutes: selectedType == HrRequestType.overtimeApproval
                    ? (int.tryParse(overtimeCtrl.text.trim()) ?? 60)
                    : 0,
                leaveType: selectedLeaveType,
                reason: reasonCtrl.text.trim().isEmpty
                    ? selectedType.label
                    : reasonCtrl.text.trim(),
                createdAt: '${state.selectedDate} 09:00',
              );
              await ref
                  .read(pdksDashboardProvider.notifier)
                  .submitHrRequest(req);
              if (dialogCtx.mounted) {
                Navigator.of(dialogCtx).pop();
              }
            },
            icon: const Icon(Icons.send_rounded, size: 16),
            label: const Text('Talebi İK Onayına Gönder'),
          ),
        ],
      ),
    ),
  );

  targetDateCtrl.dispose();
  endDateCtrl.dispose();
  timeCtrl.dispose();
  overtimeCtrl.dispose();
  reasonCtrl.dispose();
}

class _EmployeeHistorySummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _EmployeeHistorySummaryChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pal = HasibuPalette.of(context);
    return Container(
      width: 175,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: pal.subtle,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: pal.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: pal.textSecondary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// ORTAK BİLEŞEN 2: GOOGLE (GMAIL) & DRIVE VERİ EŞİTLEME KURULUM MODALI
// ============================================================================
Future<void> showGmailDriveSyncDialog(
  BuildContext context,
  WidgetRef ref,
) {
  return showCloudBackupCenterDialog(
    context,
    ref,
    onPickFolder: EmployeeProfileAvatar.pickFolderFromDesktop,
  );
}

// ============================================================================
// 1. ŞİRKET, GMAIL BULUT EŞİTLEME, ŞUBE VE TENFEI D35 CİHAZ AYARLARI
// ============================================================================
class CompanyAndBranchesSettingsView extends ConsumerStatefulWidget {
  const CompanyAndBranchesSettingsView({super.key});

  @override
  ConsumerState<CompanyAndBranchesSettingsView> createState() =>
      _CompanyAndBranchesSettingsViewState();
}

class _CompanyAndBranchesSettingsViewState
    extends ConsumerState<CompanyAndBranchesSettingsView> {
  late final TextEditingController _companyNameCtrl;
  late final TextEditingController _pollMinutesCtrl;
  late final TextEditingController _adminUserCtrl;
  late final TextEditingController _adminPassCtrl;
  late final TextEditingController _empPinCtrl;
  late final TextEditingController _gmailCtrl;
  late final TextEditingController _driveFolderCtrl;
  String? _connectionTestFeedback;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(pdksDashboardProvider).companySettings;
    _companyNameCtrl = TextEditingController(text: settings.companyName);
    _pollMinutesCtrl =
        TextEditingController(text: settings.autoPollMinutes.toString());
    _adminUserCtrl = TextEditingController(text: settings.adminUsername);
    _adminPassCtrl = TextEditingController(text: settings.adminPassword);
    _empPinCtrl = TextEditingController(text: settings.defaultEmployeePin);
    _gmailCtrl = TextEditingController(text: settings.syncGmailAccount);
    _driveFolderCtrl = TextEditingController(text: settings.syncFolderPath);
  }

  @override
  void dispose() {
    _companyNameCtrl.dispose();
    _pollMinutesCtrl.dispose();
    _adminUserCtrl.dispose();
    _adminPassCtrl.dispose();
    _empPinCtrl.dispose();
    _gmailCtrl.dispose();
    _driveFolderCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings =
        ref.watch(pdksDashboardProvider.select((s) => s.companySettings));
    final syncStatus =
        ref.watch(pdksDashboardProvider.select((s) => s.syncStatus));
    final branches = ref.watch(pdksDashboardProvider.select((s) => s.branches));
    final pal = HasibuPalette.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
        // KART 1: ŞİRKET LOGOSU, KİŞİSEL TEMA & KURUMSAL KİMLİK AYARLARI
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: pal.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: pal.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Kurumsal Kimlik, Şirket Logosu, Tema & Güvenlik Ayarları',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: pal.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              // ŞİRKET LOGOSU KUTUSU
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: pal.subtle,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: pal.border),
                ),
                child: Wrap(
                  spacing: 14,
                  runSpacing: 10,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CompanyLogoBadge(
                          settings: settings,
                          size: 52,
                          borderRadius: 12,
                          onTap: () => showCompanyLogoDialog(context, ref),
                        ),
                        const SizedBox(width: 14),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Şirket Logosu & Kurumsal Amblem',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                  color: pal.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Giriş (Login) ekranında, üst uygulama barında ve mobil personel portalında görüntülenir.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: pal.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    OutlinedButton.icon(
                      key: const ValueKey('settings_company_logo_button'),
                      onPressed: () => showCompanyLogoDialog(context, ref),
                      icon: const Icon(Icons.image_outlined, size: 17),
                      label: const Text('Şirket Logosunu Değiştir / Ekle'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // KULLANICIYA ÖZGÜ TEMA SEÇİCİ (AÇIK / KOYU / SİSTEM)
              const UserThemeSelectorBar(),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 280,
                    child: TextField(
                      controller: _companyNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Şirket / İşletme Adı',
                        prefixIcon: Icon(Icons.apartment_rounded),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 150,
                    child: TextField(
                      controller: _pollMinutesCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Oto Çekim (Dk)',
                        prefixIcon: Icon(Icons.timer_outlined),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 160,
                    child: TextField(
                      controller: _adminUserCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Yönetici Kullanıcı',
                        prefixIcon: Icon(Icons.admin_panel_settings_outlined),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 150,
                    child: TextField(
                      controller: _adminPassCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Yönetici Parolası',
                        prefixIcon: Icon(Icons.lock_outline_rounded),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 160,
                    child: TextField(
                      controller: _empPinCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Varsayılan Personel Parolası',
                        prefixIcon: Icon(Icons.pin_outlined),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: settings.autoPollEnabled,
                        onChanged: (val) => ref
                            .read(pdksDashboardProvider.notifier)
                            .toggleAutoPoll(val),
                      ),
                      const Text(
                        'Otomatik Terminal Çekimi',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(height: 1, color: pal.border),
              const SizedBox(height: 16),
              Text(
                'Google (Gmail) & Bulut Veri Eşitleme Hesabı',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: pal.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                syncStatus.isTrulySynced
                    ? '✓ Doğrulanmış Google Bulut/Drive Eşitlemesi Aktif (${settings.syncGmailAccount.isEmpty ? "Google Drive" : settings.syncGmailAccount} • ${syncStatus.message})'
                    : (settings.syncGmailAccount.trim().isNotEmpty
                        ? '⚠️ E-posta kayıtlı (${settings.syncGmailAccount}) ancak Google OAuth 2.0 girişi veya Drive klasörü doğrulanmadı • ${syncStatus.message}'
                        : 'Cihazlar arası gerçek bulut eşitleme için "Google OAuth 2.0 & Drive Doğrulama Merkezi" butonunu kullanarak Google hesabınızla giriş yapın.'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: syncStatus.isTrulySynced
                      ? FontWeight.w700
                      : FontWeight.w600,
                  color: syncStatus.isTrulySynced
                      ? const Color(0xFF10B981)
                      : (settings.syncGmailAccount.trim().isNotEmpty
                          ? const Color(0xFFD97706)
                          : pal.textSecondary),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 280,
                    child: TextField(
                      controller: _gmailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Gmail Adresi (Eşitleme Hesabı)',
                        hintText: 'isletme@gmail.com',
                        prefixIcon: Icon(Icons.alternate_email_rounded),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 300,
                    child: TextField(
                      controller: _driveFolderCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Google Drive Klasör Yolu (İsteğe Bağlı)',
                        hintText: r"G:\Drive'ım\Hasibu\CloudSync",
                        prefixIcon: Icon(Icons.folder_shared_outlined),
                      ),
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () async {
                      await showGmailDriveSyncDialog(context, ref);
                      final updated =
                          ref.read(pdksDashboardProvider).companySettings;
                      if (mounted) {
                        setState(() {
                          _gmailCtrl.text = updated.syncGmailAccount;
                          _driveFolderCtrl.text = updated.syncFolderPath;
                        });
                      }
                    },
                    icon: const Icon(Icons.cloud_sync_rounded, size: 18),
                    label: Text(
                      syncStatus.isTrulySynced
                          ? 'Google OAuth / Drive Doğrulandı (${settings.syncGmailAccount.isEmpty ? "Drive" : settings.syncGmailAccount})'
                          : 'Google OAuth 2.0 & Drive Doğrulama Merkezi',
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () async {
                      final mins =
                          int.tryParse(_pollMinutesCtrl.text.trim()) ?? 5;
                      final rawGmail = _gmailCtrl.text.trim();
                      final cleanGmail =
                          rawGmail.isNotEmpty && !rawGmail.contains('@')
                              ? '$rawGmail@gmail.com'
                              : rawGmail;
                      _gmailCtrl.text = cleanGmail;
                      await ref
                          .read(pdksDashboardProvider.notifier)
                          .updateCompanySettings(
                            settings.copyWith(
                              companyName: _companyNameCtrl.text.trim(),
                              autoPollMinutes: mins.clamp(1, 1440),
                              adminUsername: _adminUserCtrl.text.trim(),
                              adminPassword: _adminPassCtrl.text.trim(),
                              defaultEmployeePin: _empPinCtrl.text.trim(),
                              syncGmailAccount: cleanGmail,
                              syncFolderPath: _driveFolderCtrl.text.trim(),
                            ),
                          );
                      final syncRes = await ref
                          .read(pdksDashboardProvider.notifier)
                          .saveGmailSyncAccount(
                            gmailAccount: cleanGmail,
                            syncFolderPath: _driveFolderCtrl.text.trim(),
                          );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              syncRes.isTrulySynced
                                  ? '✓ Ayarlar kaydedildi ve Google Drive bulut yedeği eşitlendi.'
                                  : 'Ayarlar ve yerel yedek kaydedildi. Bulut eşitlemesi için Google OAuth 2.0 girişi veya Drive klasörü gereklidir.',
                            ),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.save_rounded, size: 18),
                    label: const Text('Ayarları Kaydet'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const CloudBackupQuickCard(
                onPickFolder: EmployeeProfileAvatar.pickFolderFromDesktop,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Şubeler & Yüz / Parmak İzi Terminalleri',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: pal.textPrimary,
              ),
            ),
            FilledButton.icon(
              onPressed: () => _showBranchDialog(context, null),
              icon: const Icon(Icons.add_business_rounded, size: 18),
              label: const Text('Yeni Şube / Cihaz Ekle'),
            ),
          ],
        ),
        if (_connectionTestFeedback != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F9FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBAE6FD)),
            ),
            child: Text(
              _connectionTestFeedback!,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF0369A1),
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        for (final branch in branches)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: pal.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: pal.border),
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 10,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: branch.hasTerminal
                            ? const Color(0xFFECFDF5)
                            : const Color(0xFFF0F9FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        branch.hasTerminal
                            ? Icons.router_rounded
                            : Icons.storefront_rounded,
                        size: 20,
                        color: branch.hasTerminal
                            ? const Color(0xFF059669)
                            : const Color(0xFF0284C7),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${branch.name} (${branch.code})',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${branch.hasTerminal ? "Aktif Terminal" : "Mobil QR / GPS Modu"}  •  '
                            'IP: ${branch.terminalIp ?? "-"}:${branch.terminalPort}  •  '
                            'Konum: ${branch.latitude}, ${branch.longitude} (${branch.geofenceRadiusMeters.round()}m)',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        setState(() {
                          _connectionTestFeedback =
                              '${branch.name} (${branch.terminalIp}:${branch.terminalPort}) test ediliyor...';
                        });
                        final diag = await ref
                            .read(pdksDashboardProvider.notifier)
                            .testBranchTerminalConnection(branch);
                        if (mounted) {
                          setState(
                            () => _connectionTestFeedback = diag.message,
                          );
                        }
                      },
                      icon: const Icon(Icons.network_check_rounded, size: 16),
                      label: const Text('Bağlantı Testi'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => showTerminalDiagnosticsDialog(
                        context,
                        ref,
                        initialBranch: branch,
                      ),
                      icon: const Icon(Icons.radar_rounded, size: 16),
                      label: const Text('Cihaz Tanılama & Çek'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () => _showBranchDialog(context, branch),
                      icon: const Icon(Icons.edit_rounded, size: 16),
                      label: const Text('Düzenle'),
                    ),
                    if (branch.id != 1)
                      IconButton(
                        tooltip: 'Şubeyi Sil',
                        color: const Color(0xFFDC2626),
                        onPressed: () => ref
                            .read(pdksDashboardProvider.notifier)
                            .deleteBranch(branch.id),
                        icon: const Icon(Icons.delete_outline_rounded),
                      ),
                  ],
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        const AppUsersManagementCard(),
        const SizedBox(height: 12),
        const HasibuReleaseNotesQuickCard(),
        ],
      ),
    );
  }

  Future<void> _showBranchDialog(BuildContext context, Branch? existing) async {
    final branches = ref.read(pdksDashboardProvider).branches;
    final nextId = existing?.id ??
        (branches.isEmpty
            ? 1
            : branches.map((e) => e.id).reduce((a, b) => a > b ? a : b) + 1);

    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final codeCtrl = TextEditingController(text: existing?.code ?? '');
    final ipCtrl = TextEditingController(text: existing?.terminalIp ?? '');
    final portCtrl = TextEditingController(
      text: (existing?.terminalPort ?? 4370).toString(),
    );
    final machineCtrl = TextEditingController(
      text: (existing?.machineNo ?? 1).toString(),
    );
    final latCtrl = TextEditingController(
      text: (existing?.latitude ?? 0.0).toString(),
    );
    final lngCtrl = TextEditingController(
      text: (existing?.longitude ?? 0.0).toString(),
    );
    final radiusCtrl = TextEditingController(
      text: (existing?.geofenceRadiusMeters ?? 150).round().toString(),
    );
    final commKeyCtrl = TextEditingController(
      text: (existing?.terminalCommKey ?? 0).toString(),
    );
    final qrSecretCtrl = TextEditingController(
      text: existing?.qrSecret ?? 'HASIBU-TOTP-SECRET-$nextId',
    );
    bool hasTerminal = existing?.hasTerminal ?? true;

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text(
                existing == null
                    ? 'Yeni Şube & Cihaz Ekle'
                    : '${existing.name} Ayarlarını Düzenle',
              ),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Şube / Lokasyon Adı (örn. Merkez Şube)',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: codeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Şube Kısa Kodu (örn. MERKEZ)',
                        ),
                      ),
                      const SizedBox(height: 10),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Bu Şubede Yüz / Parmak İzi Terminali Var',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: const Text(
                          'Açıksa TCP 4370 üzerinden otomatik veri çekilir',
                        ),
                        value: hasTerminal,
                        onChanged: (v) => setDialogState(() => hasTerminal = v),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: ipCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Cihaz IP Adresi',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: portCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Port (4370)',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: machineCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Makine No',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: commKeyCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Terminal İletişim Şifresi (CommKey)',
                                helperText: 'Varsayılan 0 yerine şifreli CommKey',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: qrSecretCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Dinamik TOTP QR Anahtarı',
                                helperText: '30 sn HMAC-SHA1 QR Sırrı',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: latCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'GPS Enlem (Lat)',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: lngCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'GPS Boylam (Lng)',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: radiusCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Yarıçap (m)',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: const Text('İptal'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) return;
                    final branch = Branch(
                      id: nextId,
                      code: codeCtrl.text.trim().isEmpty
                          ? 'SUBE_$nextId'
                          : codeCtrl.text.trim().toUpperCase(),
                      name: nameCtrl.text.trim(),
                      hasTerminal: hasTerminal,
                      terminalIp: ipCtrl.text.trim(),
                      terminalPort: int.tryParse(portCtrl.text.trim()) ?? 4370,
                      machineNo: int.tryParse(machineCtrl.text.trim()) ?? 1,
                      terminalCommKey:
                          int.tryParse(commKeyCtrl.text.trim()) ?? 0,
                      qrSecret: qrSecretCtrl.text.trim().isEmpty
                          ? 'HASIBU-TOTP-SECRET-$nextId'
                          : qrSecretCtrl.text.trim(),
                      latitude: double.tryParse(latCtrl.text.trim()) ?? 0.0,
                      longitude:
                          double.tryParse(lngCtrl.text.trim()) ?? 0.0,
                      geofenceRadiusMeters:
                          double.tryParse(radiusCtrl.text.trim()) ?? 150.0,
                    );
                    await ref
                        .read(pdksDashboardProvider.notifier)
                        .saveBranch(branch);
                    if (dialogCtx.mounted) {
                      Navigator.of(dialogCtx).pop();
                    }
                  },
                  child: const Text('Kaydet'),
                ),
              ],
            );
          },
        );
      },
    );

    nameCtrl.dispose();
    codeCtrl.dispose();
    ipCtrl.dispose();
    portCtrl.dispose();
    machineCtrl.dispose();
    commKeyCtrl.dispose();
    qrSecretCtrl.dispose();
    latCtrl.dispose();
    lngCtrl.dispose();
    radiusCtrl.dispose();
  }
}

// ============================================================================
// 2. MESAİ SAAT ARALIKLARI (VARDİYALAR) & GEÇ KALMA TOLERANS SÜRELERİ
// ============================================================================
class ShiftAndLateToleranceSettingsView extends ConsumerWidget {
  const ShiftAndLateToleranceSettingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shifts = ref.watch(pdksDashboardProvider.select((s) => s.shifts));
    final pal = HasibuPalette.of(context);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mesai Saat Aralıkları & Geç Kalma Tolerans Süreleri',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: pal.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Personellerin işe geliş-çıkış saatlerini ve kaç dakika gecikmeden sonra "Geç Geldi" sayılacağını tanımlayın.',
                  style: TextStyle(fontSize: 12, color: pal.textSecondary),
                ),
              ],
            ),
            FilledButton.icon(
              onPressed: () => _showShiftDialog(context, ref, null),
              icon: const Icon(Icons.add_alarm_rounded, size: 18),
              label: const Text('Yeni Mesai Saat Aralığı Ekle'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        for (final shift in shifts)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: pal.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: pal.border),
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD97706).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.access_time_filled_rounded,
                        color: Color(0xFFD97706),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            shift.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: pal.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Mesai Saatleri: ${shift.startTime} - ${shift.endTime}  •  Geç Kalma Toleransı: ${shift.toleranceMinutes} dakika',
                            style: TextStyle(
                              fontSize: 12,
                              color: pal.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: () => _showShiftDialog(context, ref, shift),
                      icon: const Icon(Icons.edit_rounded, size: 16),
                      label: const Text('Saat & Toleransı Düzenle'),
                    ),
                    if (shift.id != 1)
                      IconButton(
                        color: const Color(0xFFDC2626),
                        onPressed: () => ref
                            .read(pdksDashboardProvider.notifier)
                            .deleteShiftPlan(shift.id),
                        icon: const Icon(Icons.delete_outline_rounded),
                      ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _showShiftDialog(
    BuildContext context,
    WidgetRef ref,
    ShiftPlan? existing,
  ) async {
    final shifts = ref.read(pdksDashboardProvider).shifts;
    final nextId = existing?.id ??
        (shifts.isEmpty
            ? 1
            : shifts.map((e) => e.id).reduce((a, b) => a > b ? a : b) + 1);

    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final startCtrl =
        TextEditingController(text: existing?.startTime ?? '08:00');
    final endCtrl = TextEditingController(text: existing?.endTime ?? '18:00');
    final tolCtrl = TextEditingController(
      text: (existing?.toleranceMinutes ?? 15).toString(),
    );

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(
          existing == null
              ? 'Yeni Mesai Saat Aralığı Tanımla'
              : 'Mesai Saatlerini & Geç Kalma Süresini Düzenle',
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Vardiya / Grup Adı (örn. Üretim Sabah)',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: startCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Giriş Saati (SS:DD)',
                        hintText: '06:00',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: endCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Çıkış Saati (SS:DD)',
                        hintText: '15:00',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: tolCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Geç Kalma Tolerans Süresi (Dakika)',
                  helperText:
                      'Örn: 15 yazılırsa 06:00 vardiyasında 06:16 ve sonrası Geç Geldi sayılır.',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              final shift = ShiftPlan(
                id: nextId,
                name: nameCtrl.text.trim(),
                startTime: startCtrl.text.trim(),
                endTime: endCtrl.text.trim(),
                toleranceMinutes: int.tryParse(tolCtrl.text.trim()) ?? 15,
              );
              await ref
                  .read(pdksDashboardProvider.notifier)
                  .saveShiftPlan(shift);
              if (dialogCtx.mounted) {
                Navigator.of(dialogCtx).pop();
              }
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );

    nameCtrl.dispose();
    startCtrl.dispose();
    endCtrl.dispose();
    tolCtrl.dispose();
  }
}

// ============================================================================
// 3. PERSONEL HAREKETLERİNİ DÜZELTME & TOPLU HAREKET DÜZENLEME MODÜLÜ
// ============================================================================
class AttendanceCorrectionSettingsView extends ConsumerStatefulWidget {
  const AttendanceCorrectionSettingsView({super.key});

  @override
  ConsumerState<AttendanceCorrectionSettingsView> createState() =>
      _AttendanceCorrectionSettingsViewState();
}

class _AttendanceCorrectionSettingsViewState
    extends ConsumerState<AttendanceCorrectionSettingsView> {
  late final TextEditingController _dateCtrl;
  late final TextEditingController _filterCtrl;
  late final TextEditingController _bulkInCtrl;
  late final TextEditingController _bulkOutCtrl;

  final Set<String> _selectedCardNos = <String>{};
  int? _branchFilterId;
  bool _onlyAbsentFilter = false;
  bool _applyIn = true;
  bool _applyOut = true;
  bool _replaceExisting = true;

  @override
  void initState() {
    super.initState();
    final date = ref.read(pdksDashboardProvider).selectedDate;
    _dateCtrl = TextEditingController(text: date);
    _filterCtrl = TextEditingController();
    _bulkInCtrl = TextEditingController(text: '08:00');
    _bulkOutCtrl = TextEditingController(text: '18:00');
  }

  @override
  void dispose() {
    _dateCtrl.dispose();
    _filterCtrl.dispose();
    _bulkInCtrl.dispose();
    _bulkOutCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pdksDashboardProvider);
    final pal = HasibuPalette.of(context);
    final q = _filterCtrl.text.trim().toUpperCase();
    final filtered = state.dailyStatuses.where((s) {
      if (_branchFilterId != null && s.branch.id != _branchFilterId) {
        return false;
      }
      if (_onlyAbsentFilter && s.state != DailyAttendanceState.absent) {
        return false;
      }
      if (q.isEmpty) return true;
      return s.employee.fullName.toUpperCase().contains(q) ||
          s.employee.cardNo.contains(q) ||
          s.department.name.toUpperCase().contains(q);
    }).toList(growable: false);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (state.tamperedAttendanceLogs.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFDC2626).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFDC2626), width: 1.5),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.gpp_bad_rounded,
                  color: Color(0xFFDC2626),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'KIRMIZI ALARM • MANİPÜLE EDİLMİŞ KAYIT TESPİT EDİLDİ (HMAC-SHA256)',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Veritabanında ${state.tamperedAttendanceLogs.length} adet giriş/çıkış kaydının saati veya doğrulama yöntemi uygulama dışından elle değiştirilmiş (integrityHash uyumsuzluğu).',
                        style: TextStyle(
                          fontSize: 12,
                          color: pal.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        // ÜST PANEL: TOPLU HAREKET DÜZENLEME (ÇOKLU PERSONEL)
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: pal.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: pal.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.playlist_add_check_circle_rounded,
                      color: Color(0xFF0284C7),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Toplu Hareket Düzenleme & Çoklu Giriş/Çıkış Atama',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: pal.textPrimary,
                          ),
                        ),
                        Text(
                          'Aşağıdaki listeden birden fazla personeli seçip tek işlemle toplu giriş ve çıkış saati tanımlayabilirsiniz.',
                          style: TextStyle(
                            fontSize: 12,
                            color: pal.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _selectedCardNos.isEmpty
                          ? pal.chip
                          : const Color(0xFF0284C7).withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_selectedCardNos.length} Personel Seçili',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: _selectedCardNos.isEmpty
                            ? pal.textSecondary
                            : const Color(0xFF0284C7),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 170,
                    child: TextField(
                      controller: _dateCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Tarih (YYYY-AA-GG)',
                        prefixIcon: Icon(Icons.calendar_today_rounded, size: 18),
                      ),
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () {
                      final d = _dateCtrl.text.trim();
                      if (d.length >= 8) {
                        ref
                            .read(pdksDashboardProvider.notifier)
                            .setSelectedDate(d);
                      }
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Tarihi Yükle'),
                  ),
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<int?>(
                      isExpanded: true,
                      initialValue: _branchFilterId,
                      decoration: const InputDecoration(
                        labelText: 'Şube Filtresi',
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text(
                            'Tüm Şubeler',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        for (final b in state.branches)
                          DropdownMenuItem<int?>(
                            value: b.id,
                            child: Text(
                              b.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (v) => setState(() => _branchFilterId = v),
                    ),
                  ),
                  FilterChip(
                    selected: _onlyAbsentFilter,
                    label: const Text('Sadece Hareketi Olmayanlar'),
                    onSelected: (v) => setState(() => _onlyAbsentFilter = v),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        for (final s in filtered) {
                          _selectedCardNos.add(s.employee.cardNo);
                        }
                      });
                    },
                    icon: const Icon(Icons.select_all_rounded, size: 16),
                    label: Text('Listeyi Seç (${filtered.length})'),
                  ),
                  if (_selectedCardNos.isNotEmpty)
                    TextButton.icon(
                      onPressed: () =>
                          setState(() => _selectedCardNos.clear()),
                      icon: const Icon(Icons.deselect_rounded, size: 16),
                      label: const Text('Seçimi Temizle'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: pal.subtle,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: pal.border),
                ),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: _applyIn,
                          onChanged: (v) =>
                              setState(() => _applyIn = v ?? true),
                        ),
                        SizedBox(
                          width: 130,
                          child: TextField(
                            controller: _bulkInCtrl,
                            enabled: _applyIn,
                            decoration: const InputDecoration(
                              labelText: 'Toplu Giriş',
                              hintText: '08:00',
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: _applyOut,
                          onChanged: (v) =>
                              setState(() => _applyOut = v ?? true),
                        ),
                        SizedBox(
                          width: 130,
                          child: TextField(
                            controller: _bulkOutCtrl,
                            enabled: _applyOut,
                            decoration: const InputDecoration(
                              labelText: 'Toplu Çıkış',
                              hintText: '18:00',
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: _replaceExisting,
                          onChanged: (v) =>
                              setState(() => _replaceExisting = v),
                        ),
                        const Text(
                          'Günlük Kayıtları Yenile',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    FilledButton.icon(
                      key: const ValueKey('bulk_attendance_apply_button'),
                      onPressed: _selectedCardNos.isEmpty
                          ? null
                          : () async {
                              final selectedEmployees = state.dailyStatuses
                                  .where(
                                    (s) => _selectedCardNos
                                        .contains(s.employee.cardNo),
                                  )
                                  .map((s) => s.employee)
                                  .toList(growable: false);
                              final count = await ref
                                  .read(pdksDashboardProvider.notifier)
                                  .saveBulkManualAttendance(
                                    employees: selectedEmployees,
                                    dateKey: state.selectedDate,
                                    checkInTime: _applyIn
                                        ? _bulkInCtrl.text.trim()
                                        : null,
                                    checkOutTime: _applyOut
                                        ? _bulkOutCtrl.text.trim()
                                        : null,
                                    replaceExistingForDay: _replaceExisting,
                                  );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '${selectedEmployees.length} personel için $count toplu hareket uygulandı.',
                                    ),
                                  ),
                                );
                              }
                            },
                      icon: const Icon(Icons.done_all_rounded, size: 18),
                      label: Text(
                        'Seçili ${_selectedCardNos.length} Personele Toplu Uygula',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // ARAMA SATIRI
        TextField(
          controller: _filterCtrl,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Personel Adı, Kart No veya Bölüm Ara',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
        const SizedBox(height: 12),
        for (final item in filtered)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: pal.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _selectedCardNos.contains(item.employee.cardNo)
                    ? const Color(0xFF0284C7)
                    : pal.border,
              ),
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Checkbox(
                      value: _selectedCardNos.contains(item.employee.cardNo),
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true) {
                            _selectedCardNos.add(item.employee.cardNo);
                          } else {
                            _selectedCardNos.remove(item.employee.cardNo);
                          }
                        });
                      },
                    ),
                    EmployeeProfileAvatar(employee: item.employee, size: 38),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${item.employee.fullName} (#${item.employee.cardNo})',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                              color: pal.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${item.branch.name} • ${item.department.name} • Vardiya: ${item.shift.startTime}-${item.shift.endTime}',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: pal.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              if (item.allLogsOfDay.isEmpty)
                                const Text(
                                  'Kayıt yok',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: Color(0xFFDC2626),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              for (final log in item.allLogsOfDay)
                                Chip(
                                  visualDensity: VisualDensity.compact,
                                  backgroundColor: !log.isIntegrityValid
                                      ? const Color(0xFFDC2626)
                                          .withValues(alpha: 0.18)
                                      : log.isCheckIn
                                          ? const Color(0xFF059669)
                                              .withValues(alpha: 0.14)
                                          : const Color(0xFFD97706)
                                              .withValues(alpha: 0.14),
                                  label: Text(
                                    !log.isIntegrityValid
                                        ? '⚠️ Manipüle Edilmiş Kayıt (${log.timeFormatted})'
                                        : '${log.isCheckIn ? "GİRİŞ" : "ÇIKIŞ"}: ${log.timeFormatted}',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: !log.isIntegrityValid
                                          ? const Color(0xFFDC2626)
                                          : log.isCheckIn
                                              ? const Color(0xFF059669)
                                              : const Color(0xFFD97706),
                                    ),
                                  ),
                                  deleteIcon:
                                      const Icon(Icons.close, size: 14),
                                  onDeleted: () => ref
                                      .read(pdksDashboardProvider.notifier)
                                      .deleteAttendanceLog(log.id),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 6,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _showEditAttendanceDialog(
                        context,
                        item.employee,
                        state.selectedDate,
                        existingLog: item.firstCheckIn,
                        defaultIsCheckIn: true,
                      ),
                      icon: const Icon(Icons.login_rounded, size: 15),
                      label: Text(
                        item.firstCheckIn == null
                            ? 'Giriş Ekle'
                            : 'Giriş (${item.firstCheckIn!.timeFormatted})',
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _showEditAttendanceDialog(
                        context,
                        item.employee,
                        state.selectedDate,
                        existingLog: item.lastCheckOut,
                        defaultIsCheckIn: false,
                      ),
                      icon: const Icon(Icons.logout_rounded, size: 15),
                      label: Text(
                        item.lastCheckOut == null
                            ? 'Çıkış Ekle'
                            : 'Çıkış (${item.lastCheckOut!.timeFormatted})',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _showEditAttendanceDialog(
    BuildContext context,
    Employee employee,
    String dateKey, {
    AttendanceLog? existingLog,
    required bool defaultIsCheckIn,
  }) async {
    final timeCtrl = TextEditingController(
      text: existingLog?.timeFormatted ?? (defaultIsCheckIn ? '08:00' : '18:00'),
    );
    bool isCheckIn = existingLog?.isCheckIn ?? defaultIsCheckIn;

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('${employee.fullName} Hareket Düzeltme'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Tarih: $dateKey • Kart No: #${employee.cardNo}'),
              const SizedBox(height: 12),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('İşe Giriş')),
                  ButtonSegment(value: false, label: Text('İşten Çıkış')),
                ],
                selected: {isCheckIn},
                onSelectionChanged: (s) =>
                    setDialogState(() => isCheckIn = s.first),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: timeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Saat (SS:DD)',
                  hintText: '08:00',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('İptal'),
            ),
            FilledButton(
              onPressed: () async {
                await ref
                    .read(pdksDashboardProvider.notifier)
                    .saveOrUpdateAttendanceLog(
                      existingLogId: existingLog?.id,
                      employee: employee,
                      dateKey: dateKey,
                      timeHhMm: timeCtrl.text.trim(),
                      isCheckIn: isCheckIn,
                    );
                if (dialogCtx.mounted) {
                  Navigator.of(dialogCtx).pop();
                }
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
    timeCtrl.dispose();
  }
}

// ============================================================================
// 4. İZİNLİ VE RAPORLU PERSONEL BİLGİLERİNİ GİRME / YÖNETME
// ============================================================================
class LeavesAndReportsSettingsView extends ConsumerStatefulWidget {
  const LeavesAndReportsSettingsView({super.key});

  @override
  ConsumerState<LeavesAndReportsSettingsView> createState() =>
      _LeavesAndReportsSettingsViewState();
}

class _LeavesAndReportsSettingsViewState
    extends ConsumerState<LeavesAndReportsSettingsView> {
  int? _selectedEmployeeId;
  LeaveType _selectedLeaveType = LeaveType.yillikIzin;
  late final TextEditingController _startDateCtrl;
  late final TextEditingController _endDateCtrl;
  late final TextEditingController _noteCtrl;

  @override
  void initState() {
    super.initState();
    final date = ref.read(pdksDashboardProvider).selectedDate;
    _startDateCtrl = TextEditingController(text: date);
    _endDateCtrl = TextEditingController(text: date);
    _noteCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _startDateCtrl.dispose();
    _endDateCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickLeaveDate(TextEditingController ctrl) async {
    final initial = DateTime.tryParse(ctrl.text.trim()) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2035, 12, 31),
      locale: const Locale('tr', 'TR'),
    );
    if (picked == null || !mounted) return;
    setState(() {
      ctrl.text = PdksDashboardNotifier.formatDateKey(picked);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pdksDashboardProvider);
    final pal = HasibuPalette.of(context);
    final activeEmps = state.dailyStatuses
        .where((s) => !s.employee.isSeparatedNow)
        .map((s) => s.employee)
        .toList(growable: false);
    final employees = activeEmps.isNotEmpty
        ? activeEmps
        : state.dailyStatuses.map((e) => e.employee).toList(growable: false);
    final empMap = {for (final e in employees) e.id: e};

    if ((_selectedEmployeeId == null || !empMap.containsKey(_selectedEmployeeId)) &&
        employees.isNotEmpty) {
      _selectedEmployeeId = employees.first.id;
    }
    final selectedEmp =
        _selectedEmployeeId != null ? empMap[_selectedEmployeeId] : null;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: pal.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: pal.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'İzinli veya Raporlu Personel Kaydı Oluştur',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: pal.textPrimary,
                ),
              ),
              if (selectedEmp != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.28),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.beach_access_rounded,
                        size: 15,
                        color: Color(0xFF0284C7),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '${selectedEmp.fullName} • Kalan Yıllık İzin: ${selectedEmp.remainingAnnualLeave} Gün (Hak: ${selectedEmp.annualLeaveEntitlement} / Kullanılan: ${selectedEmp.usedAnnualLeave})',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: pal.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 300,
                    child: DropdownButtonFormField<int>(
                      isExpanded: true,
                      initialValue: _selectedEmployeeId,
                      decoration: const InputDecoration(
                        labelText: 'Personel Seçin',
                      ),
                      items: [
                        for (final e in employees)
                          DropdownMenuItem(
                            value: e.id,
                            child: Text(
                              '${e.fullName} (#${e.cardNo})',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (v) => setState(() => _selectedEmployeeId = v),
                    ),
                  ),
                  SizedBox(
                    width: 200,
                    child: DropdownButtonFormField<LeaveType>(
                      isExpanded: true,
                      initialValue: _selectedLeaveType,
                      decoration: const InputDecoration(
                        labelText: 'İzin / Rapor Türü',
                      ),
                      items: [
                        for (final lt in LeaveType.values)
                          DropdownMenuItem(
                            value: lt,
                            child: Text(
                              lt.label,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => _selectedLeaveType = v);
                        }
                      },
                    ),
                  ),
                  SizedBox(
                    width: 190,
                    child: TextField(
                      controller: _startDateCtrl,
                      decoration: InputDecoration(
                        labelText: 'Başlangıç (YYYY-AA-GG)',
                        suffixIcon: IconButton(
                          tooltip: 'Takvimden Başlangıç Tarihi Seç',
                          icon: const Icon(Icons.calendar_today_rounded, size: 16),
                          onPressed: () => _pickLeaveDate(_startDateCtrl),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 190,
                    child: TextField(
                      controller: _endDateCtrl,
                      decoration: InputDecoration(
                        labelText: 'Bitiş (YYYY-AA-GG)',
                        suffixIcon: IconButton(
                          tooltip: 'Takvimden Bitiş Tarihi Seç',
                          icon: const Icon(Icons.calendar_today_rounded, size: 16),
                          onPressed: () => _pickLeaveDate(_endDateCtrl),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 260,
                    child: TextField(
                      controller: _noteCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Açıklama / Rapor Notu',
                        hintText: 'Örn: 3 Günlük Hastane Raporu',
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () async {
                      final empId = _selectedEmployeeId;
                      if (empId == null) return;
                      final start =
                          DateTime.tryParse(_startDateCtrl.text.trim()) ??
                              DateTime(2026, 10, 19);
                      final end =
                          DateTime.tryParse(_endDateCtrl.text.trim()) ?? start;
                      final count = await ref
                          .read(pdksDashboardProvider.notifier)
                          .assignLeaveDateRange(
                            employeeId: empId,
                            startDate: start,
                            endDate: end,
                            leaveType: _selectedLeaveType,
                            note: _noteCtrl.text,
                          );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '$count günlük ${_selectedLeaveType.label} kaydı eklendi.',
                            ),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('İzin / Rapor Kaydet'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Kayıtlı İzinler & Sağlık Raporları (${state.allLeaveRecords.length})',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: pal.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        for (final rec in state.allLeaveRecords)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: pal.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: pal.border),
            ),
            child: ListTile(
              leading: empMap[rec.employeeId] != null
                  ? EmployeeProfileAvatar(
                      employee: empMap[rec.employeeId]!,
                      size: 38,
                    )
                  : const CircleAvatar(child: Icon(Icons.person_outline)),
              title: Text(
                '${empMap[rec.employeeId]?.fullName ?? "Personel #${rec.employeeId}"} • ${rec.leaveType.label}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
              ),
              subtitle: Text('Tarih: ${rec.date} • Not: ${rec.note}'),
              trailing: IconButton(
                color: const Color(0xFFDC2626),
                tooltip: 'İzin/Rapor Kaydını Sil',
                onPressed: () => ref
                    .read(pdksDashboardProvider.notifier)
                    .deleteLeaveRecord(rec.id),
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ),
          ),
      ],
    );
  }
}

enum _EmployeeListFilter { all, active, terminated }

// ============================================================================
// 5. PERSONEL KARTLARI, KİŞİSEL PAROLA, PROFİL FOTOĞRAFI VE YETKİ YÖNETİMİ
// ============================================================================
class EmployeesManagementSettingsView extends ConsumerStatefulWidget {
  const EmployeesManagementSettingsView({super.key});

  @override
  ConsumerState<EmployeesManagementSettingsView> createState() =>
      _EmployeesManagementSettingsViewState();
}

class _EmployeesManagementSettingsViewState
    extends ConsumerState<EmployeesManagementSettingsView> {
  late final TextEditingController _searchCtrl;
  _EmployeeListFilter _statusFilter = _EmployeeListFilter.all;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _showQuickExitDialog(BuildContext context, Employee emp) {
    return showDialog<void>(
      context: context,
      builder: (_) => _EmployeeQuickExitDialog(employee: emp),
    );
  }

  Future<void> _showQuickRehireDialog(
    BuildContext context,
    Employee emp,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('${emp.fullName} — Tekrar Aktif Et'),
        content: Text(
          'Mevcut işten çıkış tarihi (${PdksDashboardNotifier.formatDisplayDate(emp.normalizedExitDate ?? '', includeTodayBadge: false)}) kaldırılıp personel yeniden aktif kadroya alınacak. Onaylıyor musunuz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 17),
            label: const Text('Tekrar Aktif Et'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(pdksDashboardProvider.notifier).saveEmployee(
            emp.copyWith(
              exitDate: () => null,
              sgkActive: true,
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pdksDashboardProvider);
    final pal = HasibuPalette.of(context);
    final q = _searchCtrl.text.trim().toUpperCase();

    final int totalStaff = state.dailyStatuses.length;
    final int terminatedStaff = state.dailyStatuses
        .where((s) => s.employee.isSeparatedNow)
        .length;
    final int activeStaff = totalStaff - terminatedStaff;

    final filtered = state.dailyStatuses.where((s) {
      final isSeparated = s.employee.isSeparatedNow;
      if (_statusFilter == _EmployeeListFilter.active && isSeparated) {
        return false;
      }
      if (_statusFilter == _EmployeeListFilter.terminated && !isSeparated) {
        return false;
      }
      if (q.isEmpty) return true;
      return s.employee.fullName.toUpperCase().contains(q) ||
          s.employee.cardNo.contains(q) ||
          s.department.name.toUpperCase().contains(q);
    }).toList(growable: false)
      ..sort((a, b) {
        final sepCmp = (a.employee.isSeparatedNow ? 1 : 0)
            .compareTo(b.employee.isSeparatedNow ? 1 : 0);
        if (sepCmp != 0) return sepCmp;
        return a.employee.fullName.compareTo(b.employee.fullName);
      });

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 360,
              child: TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Personel Adı, Kart No veya Bölüm Ara',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showAddDepartmentDialog(context),
                  icon: const Icon(Icons.category_rounded, size: 18),
                  label: const Text('Yeni Bölüm Ekle'),
                ),
                FilledButton.icon(
                  onPressed: () => _showEmployeeDialog(context, null),
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                  label: const Text('Yeni Personel Ekle'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              key: const ValueKey('employees_filter_all'),
              label: Text('Tümü ($totalStaff)'),
              selected: _statusFilter == _EmployeeListFilter.all,
              onSelected: (_) =>
                  setState(() => _statusFilter = _EmployeeListFilter.all),
            ),
            ChoiceChip(
              key: const ValueKey('employees_filter_active'),
              label: Text('Aktif ($activeStaff)'),
              selected: _statusFilter == _EmployeeListFilter.active,
              onSelected: (_) =>
                  setState(() => _statusFilter = _EmployeeListFilter.active),
            ),
            ChoiceChip(
              key: const ValueKey('employees_filter_terminated'),
              label: Text('İşten Ayrılan ($terminatedStaff)'),
              selected: _statusFilter == _EmployeeListFilter.terminated,
              onSelected: (_) =>
                  setState(() => _statusFilter = _EmployeeListFilter.terminated),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (filtered.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: pal.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: pal.border),
            ),
            child: Center(
              child: Text(
                'Seçili filtreye uygun personel kartı bulunamadı.',
                style: TextStyle(fontSize: 13, color: pal.textSecondary),
              ),
            ),
          ),
        for (final item in filtered)
          _EmployeeManagementCard(
            item: item,
            docCount: state.documentsForEmployee(item.employee.id).length,
            onOpenDossier: () => showEmployeeHistoryAndDossierDialog(
              context,
              ref,
              item.employee,
              initialTabIndex: 0,
            ),
            onOpenDocuments: () => showEmployeeHistoryAndDossierDialog(
              context,
              ref,
              item.employee,
              initialTabIndex: 1,
            ),
            onEdit: () => _showEmployeeDialog(context, item.employee),
            onQuickExit: () => _showQuickExitDialog(context, item.employee),
            onQuickRehire: () => _showQuickRehireDialog(context, item.employee),
            onDelete: () => ref
                .read(pdksDashboardProvider.notifier)
                .deleteEmployee(item.employee.id),
          ),
      ],
    );
  }

  Future<void> _showAddDepartmentDialog(BuildContext context) async {
    final state = ref.read(pdksDashboardProvider);
    final nameCtrl = TextEditingController();
    int selectedBranchId =
        state.branches.isNotEmpty ? state.branches.first.id : 1;

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Yeni Üretim Bölümü / Departman Ekle'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Bölüm Adı (örn. PAKETLEME)',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                isExpanded: true,
                initialValue: selectedBranchId,
                decoration: const InputDecoration(
                  labelText: 'Bağlı Şube',
                ),
                items: [
                  for (final b in state.branches)
                    DropdownMenuItem(
                      value: b.id,
                      child: Text(b.name, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) {
                  if (v != null) setDialogState(() => selectedBranchId = v);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('İptal'),
            ),
            FilledButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                final nextId = state.departments.isEmpty
                    ? 1
                    : state.departments
                            .map((d) => d.id)
                            .reduce((a, b) => a > b ? a : b) +
                        1;
                await ref.read(pdksDashboardProvider.notifier).saveDepartment(
                      Department(
                        id: nextId,
                        name: nameCtrl.text.trim(),
                        branchId: selectedBranchId,
                      ),
                    );
                if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
    nameCtrl.dispose();
  }

  Future<void> _showEmployeeDialog(
    BuildContext context,
    Employee? existing,
  ) {
    return showDialog<void>(
      context: context,
      builder: (_) => _EmployeeEditDialog(existing: existing),
    );
  }
}

class _EmployeeQuickExitDialog extends ConsumerStatefulWidget {
  final Employee employee;

  const _EmployeeQuickExitDialog({required this.employee});

  @override
  ConsumerState<_EmployeeQuickExitDialog> createState() =>
      _EmployeeQuickExitDialogState();
}

class _EmployeeQuickExitDialogState
    extends ConsumerState<_EmployeeQuickExitDialog> {
  late final TextEditingController _exitCtrl;
  bool _deactivateSgk = true;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _exitCtrl = TextEditingController(text: PdksDashboardNotifier.todayDateKey());
  }

  @override
  void dispose() {
    _exitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final emp = widget.employee;
    return AlertDialog(
      title: Text('${emp.fullName} — İşten Çıkış İşlemi'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'İşe Giriş: ${PdksDashboardNotifier.formatDisplayDate(emp.hireDate, includeTodayBadge: false)}',
              style: const TextStyle(fontSize: 12.5),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _exitCtrl,
              decoration: InputDecoration(
                labelText: 'İşten Çıkış Tarihi (YYYY-AA-GG)',
                suffixIcon: IconButton(
                  tooltip: 'Takvimden Seç',
                  icon: const Icon(Icons.calendar_today_rounded, size: 18),
                  onPressed: () async {
                    final initial =
                        Employee.parseDateKey(_exitCtrl.text) ?? DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: initial,
                      firstDate: DateTime(1990, 1, 1),
                      lastDate: DateTime(2035, 12, 31),
                      locale: const Locale('tr', 'TR'),
                    );
                    if (picked != null && mounted) {
                      setState(() {
                        _exitCtrl.text =
                            PdksDashboardNotifier.formatDateKey(picked);
                        _errorMsg = null;
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _deactivateSgk,
              onChanged: (v) => setState(() => _deactivateSgk = v ?? true),
              title: const Text(
                'SGK durumunu pasif yap',
                style: TextStyle(fontSize: 13),
              ),
            ),
            if (_errorMsg != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _errorMsg!,
                  style: const TextStyle(
                    color: Color(0xFFDC2626),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('İptal'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFDC2626),
          ),
          onPressed: () {
            final exitDt = Employee.parseDateKey(_exitCtrl.text);
            final hireDt = Employee.parseDateKey(emp.hireDate);
            if (exitDt == null) {
              setState(
                () => _errorMsg = 'Geçerli bir YYYY-AA-GG tarihi giriniz.',
              );
              return;
            }
            if (hireDt != null && exitDt.isBefore(hireDt)) {
              setState(
                () => _errorMsg =
                    'Çıkış tarihi işe giriş tarihinden (${emp.hireDate}) önce olamaz.',
              );
              return;
            }
            final normExit = PdksDashboardNotifier.formatDateKey(exitDt);
            final saveFuture =
                ref.read(pdksDashboardProvider.notifier).saveEmployee(
                      emp.copyWith(
                        exitDate: () => normExit,
                        sgkActive: _deactivateSgk ? false : emp.sgkActive,
                      ),
                    );
            unawaited(
              saveFuture.catchError((Object e) {
                debugPrint(
                  'Personel çıkış kaydetme arka plan senkronizasyon uyarısı: $e',
                );
              }),
            );
            Navigator.of(context).pop();
          },
          icon: const Icon(Icons.person_remove_rounded, size: 17),
          label: const Text('Çıkış Kaydet'),
        ),
      ],
    );
  }
}

class _EmployeeEditDialog extends ConsumerStatefulWidget {
  final Employee? existing;

  const _EmployeeEditDialog({required this.existing});

  @override
  ConsumerState<_EmployeeEditDialog> createState() =>
      _EmployeeEditDialogState();
}

class _EmployeeEditDialogState extends ConsumerState<_EmployeeEditDialog> {
  late final int _nextId;
  late final TextEditingController _cardCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _hireCtrl;
  late final TextEditingController _exitCtrl;
  late final TextEditingController _passwordCtrl;
  late final TextEditingController _photoPathCtrl;
  late final TextEditingController _leaveEntCtrl;
  late final TextEditingController _leaveUsedCtrl;
  late final TextEditingController _kpiCtrl;

  late int _branchId;
  late int _deptId;
  late int _shiftId;
  late bool _sgkActive;
  bool _userTouchedSgk = false;
  String? _dateValidationError;
  late HasibuThemeMode _empThemeMode;
  late final Set<HasibuModule> _selectedModules;

  @override
  void initState() {
    super.initState();
    final state = ref.read(pdksDashboardProvider);
    final existing = widget.existing;
    _nextId = existing?.id ??
        (state.dailyStatuses.isEmpty
            ? 3000
            : state.dailyStatuses
                    .map((s) => s.employee.id)
                    .reduce((a, b) => a > b ? a : b) +
                1);

    _cardCtrl = TextEditingController(
      text: existing?.cardNo ?? _nextId.toString().padLeft(5, '0'),
    );
    _nameCtrl = TextEditingController(text: existing?.fullName ?? '');
    _titleCtrl =
        TextEditingController(text: existing?.title ?? 'ÜRETİM PERSONELİ');
    _hireCtrl = TextEditingController(
      text: existing?.hireDate ?? PdksDashboardNotifier.todayDateKey(),
    );
    _exitCtrl = TextEditingController(
      text: existing?.normalizedExitDate ?? '',
    );
    _passwordCtrl =
        TextEditingController(text: existing?.password ?? '1234');
    _photoPathCtrl =
        TextEditingController(text: existing?.photoPath ?? '');
    _leaveEntCtrl = TextEditingController(
      text: (existing?.annualLeaveEntitlement ?? 14).toString(),
    );
    _leaveUsedCtrl = TextEditingController(
      text: (existing?.usedAnnualLeave ?? 0).toString(),
    );
    _kpiCtrl = TextEditingController(
      text: (existing?.kpiScore ?? 95.0).toStringAsFixed(0),
    );

    _branchId = existing?.branchId ??
        (state.branches.isNotEmpty ? state.branches.first.id : 1);
    _deptId = existing?.departmentId ??
        (state.departments.isNotEmpty ? state.departments.first.id : 1);
    _shiftId = existing?.shiftId ??
        (state.shifts.isNotEmpty ? state.shifts.first.id : 1);
    _sgkActive = existing?.sgkActive ?? true;
    _empThemeMode = existing?.themeMode ?? HasibuThemeMode.light;
    _selectedModules = <HasibuModule>{
      ...(existing?.allowedModules ??
          const <HasibuModule>[HasibuModule.employeePortal]),
    };
  }

  @override
  void dispose() {
    _cardCtrl.dispose();
    _nameCtrl.dispose();
    _titleCtrl.dispose();
    _hireCtrl.dispose();
    _exitCtrl.dispose();
    _passwordCtrl.dispose();
    _photoPathCtrl.dispose();
    _leaveEntCtrl.dispose();
    _leaveUsedCtrl.dispose();
    _kpiCtrl.dispose();
    super.dispose();
  }

  DateTime _clampedPickerDate(String rawText) {
    final raw = Employee.parseDateKey(rawText) ?? DateTime.now();
    if (raw.isBefore(DateTime(1990, 1, 1))) return DateTime(1990, 1, 1);
    if (raw.isAfter(DateTime(2035, 12, 31))) return DateTime(2035, 12, 31);
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pdksDashboardProvider);
    final pal = HasibuPalette.of(context);
    final existing = widget.existing;
    final previewEmp = Employee(
      id: _nextId,
      cardNo: _cardCtrl.text,
      fullName:
          _nameCtrl.text.isEmpty ? 'Personel' : _nameCtrl.text.toUpperCase(),
      title: _titleCtrl.text,
      departmentId: _deptId,
      branchId: _branchId,
      hireDate: _hireCtrl.text.trim(),
      exitDate: Employee.normalizeDateKey(_exitCtrl.text),
      photoPath: _photoPathCtrl.text.trim().isEmpty
          ? null
          : _photoPathCtrl.text.trim(),
      themeMode: _empThemeMode,
    );

    return AlertDialog(
      title: Text(
        existing == null
            ? 'Yeni Personel, Parola & Yetki Kaydı'
            : '${existing.fullName} Kartını Güncelle',
      ),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. PROFİL FOTOĞRAFI ALANI
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: pal.subtle,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: pal.border),
                ),
                child: Row(
                  children: [
                    EmployeeProfileAvatar(
                      employee: previewEmp,
                      size: 60,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Profil Fotoğrafı & Avatar',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              if (Platform.isWindows)
                                OutlinedButton.icon(
                                  onPressed: () async {
                                    final picked =
                                        await EmployeeProfileAvatar
                                            .pickPhotoFromDesktop();
                                    if (picked != null && mounted) {
                                      setState(
                                        () => _photoPathCtrl.text = picked,
                                      );
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.photo_camera_outlined,
                                    size: 16,
                                  ),
                                  label: const Text(
                                    'Bilgisayardan Fotoğraf Seç',
                                  ),
                                ),
                              for (int i = 1; i <= 6; i++)
                                InkWell(
                                  onTap: () => setState(
                                    () => _photoPathCtrl.text = 'preset:$i',
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          _photoPathCtrl.text == 'preset:$i'
                                              ? const Color(0xFF0284C7)
                                                  .withValues(alpha: 0.2)
                                              : pal.card,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: pal.border),
                                    ),
                                    child: Text(
                                      'Stil $i',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _cardCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Kart / Sicil No (örn. 00001)',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _nameCtrl,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Ad Soyad',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _passwordCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Kişisel Giriş Parolası',
                        helperText: 'Personelin oturum açma parolası',
                        prefixIcon: Icon(Icons.key_rounded, size: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Görev / Unvan',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // 2. PERSONELİN KENDİNE ÖZGÜ TEMA SEÇİMİ
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: pal.subtle,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: pal.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Personelin Kişisel Tema Tercihi (Oturum Açtığında Uygulanır)',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<HasibuThemeMode>(
                      segments: [
                        for (final m in HasibuThemeMode.values)
                          ButtonSegment<HasibuThemeMode>(
                            value: m,
                            label: Text(m.label),
                          ),
                      ],
                      selected: {_empThemeMode},
                      onSelectionChanged: (sel) => setState(
                        () => _empThemeMode = sel.first,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // 3. PERSONEL YETKİ ALANLARI (MODÜL İZİNLERİ)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: pal.subtle,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: pal.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            'Personel Yetki Alanları (Girişte Görebileceği Modüller)',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => setState(() {
                            _selectedModules
                                .addAll(HasibuModule.activePhaseModules);
                          }),
                          child: const Text(
                            'Tüm Yetkileri Ver',
                            style: TextStyle(fontSize: 11.5),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final mod in HasibuModule.activePhaseModules)
                          FilterChip(
                            selected: _selectedModules.contains(mod),
                            label: Text(
                              mod.title,
                              style: const TextStyle(fontSize: 12),
                            ),
                            onSelected: (val) {
                              setState(() {
                                if (val) {
                                  _selectedModules.add(mod);
                                } else if (_selectedModules.length > 1) {
                                  _selectedModules.remove(mod);
                                }
                              });
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      isExpanded: true,
                      initialValue: _branchId,
                      decoration: const InputDecoration(
                        labelText: 'Şube / Merkez',
                      ),
                      items: [
                        for (final b in state.branches)
                          DropdownMenuItem(
                            value: b.id,
                            child: Text(
                              b.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _branchId = v);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      isExpanded: true,
                      initialValue: _deptId,
                      decoration: const InputDecoration(
                        labelText: 'Bölüm / Departman',
                      ),
                      items: [
                        for (final d in state.departments)
                          DropdownMenuItem(
                            value: d.id,
                            child: Text(
                              d.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _deptId = v);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                isExpanded: true,
                initialValue: _shiftId,
                decoration: const InputDecoration(
                  labelText: 'Mesai Saat Aralığı (Vardiya)',
                ),
                items: [
                  for (final s in state.shifts)
                    DropdownMenuItem(
                      value: s.id,
                      child: Text(
                        '${s.name} (${s.startTime}-${s.endTime} • ${s.toleranceMinutes} dk tol.)',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _shiftId = v);
                },
              ),
              const SizedBox(height: 10),
              // İSTİHDAM TARİHLERİ (İŞE GİRİŞ & İŞTEN ÇIKIŞ)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: pal.subtle,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: pal.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text(
                          'İstihdam Tarihleri (İşe Giriş & İşten Çıkış)',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                          ),
                        ),
                        ActionChip(
                          visualDensity: VisualDensity.compact,
                          avatar: const Icon(
                            Icons.person_off_outlined,
                            size: 14,
                            color: Color(0xFFDC2626),
                          ),
                          label: const Text(
                            'Bugün Çıkış Ver',
                            style: TextStyle(fontSize: 11),
                          ),
                          onPressed: () => setState(() {
                            _exitCtrl.text =
                                PdksDashboardNotifier.todayDateKey();
                            _dateValidationError = null;
                            if (!_userTouchedSgk) {
                              _sgkActive = false;
                            }
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LayoutBuilder(
                      builder: (fieldCtx, constraints) {
                        final hireField = TextField(
                          key: const ValueKey(
                            'employee_dialog_hire_date_field',
                          ),
                          controller: _hireCtrl,
                          onChanged: (_) =>
                              setState(() => _dateValidationError = null),
                          decoration: InputDecoration(
                            labelText: 'İşe Giriş (YYYY-AA-GG)',
                            suffixIcon: IconButton(
                              tooltip: 'Takvimden Seç',
                              icon: const Icon(
                                Icons.calendar_today_rounded,
                                size: 17,
                              ),
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate:
                                      _clampedPickerDate(_hireCtrl.text),
                                  firstDate: DateTime(1990, 1, 1),
                                  lastDate: DateTime(2035, 12, 31),
                                  locale: const Locale('tr', 'TR'),
                                );
                                if (picked != null && mounted) {
                                  setState(() {
                                    _hireCtrl.text =
                                        PdksDashboardNotifier.formatDateKey(
                                      picked,
                                    );
                                    _dateValidationError = null;
                                  });
                                }
                              },
                            ),
                          ),
                        );
                        final exitField = TextField(
                          key: const ValueKey(
                            'employee_dialog_exit_date_field',
                          ),
                          controller: _exitCtrl,
                          onChanged: (v) => setState(() {
                            _dateValidationError = null;
                            if (!_userTouchedSgk) {
                              _sgkActive = v.trim().isEmpty;
                            }
                          }),
                          decoration: InputDecoration(
                            labelText: 'İşten Çıkış (Opsiyonel)',
                            hintText: 'YYYY-AA-GG',
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_exitCtrl.text.trim().isNotEmpty)
                                  IconButton(
                                    tooltip: 'Çıkış Tarihini Temizle',
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      size: 17,
                                    ),
                                    onPressed: () => setState(() {
                                      _exitCtrl.clear();
                                      _dateValidationError = null;
                                      if (!_userTouchedSgk) {
                                        _sgkActive = true;
                                      }
                                    }),
                                  ),
                                IconButton(
                                  tooltip: 'Takvimden Seç',
                                  icon: const Icon(
                                    Icons.calendar_today_rounded,
                                    size: 17,
                                  ),
                                  onPressed: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate:
                                          _clampedPickerDate(_exitCtrl.text),
                                      firstDate: DateTime(1990, 1, 1),
                                      lastDate: DateTime(2035, 12, 31),
                                      locale: const Locale('tr', 'TR'),
                                    );
                                    if (picked != null && mounted) {
                                      setState(() {
                                        _exitCtrl.text =
                                            PdksDashboardNotifier.formatDateKey(
                                          picked,
                                        );
                                        _dateValidationError = null;
                                        if (!_userTouchedSgk) {
                                          _sgkActive = false;
                                        }
                                      });
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                        if (constraints.maxWidth >= 420) {
                          return Row(
                            children: [
                              Expanded(child: hireField),
                              const SizedBox(width: 8),
                              Expanded(child: exitField),
                            ],
                          );
                        }
                        return Column(
                          children: [
                            hireField,
                            const SizedBox(height: 8),
                            exitField,
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Kıdem: ${previewEmp.tenureSummaryAt()} • 4857 Yasal İzin: ${previewEmp.statutoryAnnualLeaveEntitlement} Gün',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: pal.textSecondary,
                      ),
                    ),
                    if (_exitCtrl.text.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626)
                              .withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFFDC2626)
                                .withValues(alpha: 0.30),
                          ),
                        ),
                        child: const Text(
                          'Çıkış tarihinden itibaren devamsız sayılmaz ve portal girişi kapatılır.',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                      ),
                    ],
                    if (_dateValidationError != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _dateValidationError!,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _leaveEntCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'İzin Hakkı',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _leaveUsedCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Kullanılan',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _kpiCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'KPI (%)',
                      ),
                    ),
                  ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('SGK Sigortalılık Durumu Aktif'),
                value: _sgkActive,
                onChanged: (v) => setState(() {
                  _userTouchedSgk = true;
                  _sgkActive = v;
                }),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('İptal'),
        ),
        FilledButton(
          key: const ValueKey('employee_dialog_save_button'),
          onPressed: () {
            if (_nameCtrl.text.trim().isEmpty) return;
            final parsedHire = Employee.parseDateKey(_hireCtrl.text);
            if (parsedHire == null) {
              setState(
                () => _dateValidationError =
                    'Geçerli bir işe giriş tarihi (YYYY-AA-GG) giriniz.',
              );
              return;
            }
            final rawExit = _exitCtrl.text.trim();
            DateTime? parsedExit;
            if (rawExit.isNotEmpty) {
              parsedExit = Employee.parseDateKey(rawExit);
              if (parsedExit == null) {
                setState(
                  () => _dateValidationError =
                      'Geçerli bir işten çıkış tarihi (YYYY-AA-GG) giriniz.',
                );
                return;
              }
              if (parsedExit.isBefore(parsedHire)) {
                setState(
                  () => _dateValidationError =
                      'İşten çıkış tarihi işe giriş tarihinden önce olamaz.',
                );
                return;
              }
            }
            final orderedModules = HasibuModule.activePhaseModules
                .where((m) => _selectedModules.contains(m))
                .toList(growable: false);
            final emp = Employee(
              id: _nextId,
              cardNo: _cardCtrl.text.trim().padLeft(5, '0'),
              fullName: _nameCtrl.text.trim().toUpperCase(),
              title: _titleCtrl.text.trim().toUpperCase(),
              departmentId: _deptId,
              branchId: _branchId,
              shiftId: _shiftId,
              hireDate: PdksDashboardNotifier.formatDateKey(parsedHire),
              exitDate: parsedExit != null
                  ? PdksDashboardNotifier.formatDateKey(parsedExit)
                  : null,
              sgkActive: _sgkActive,
              annualLeaveEntitlement:
                  int.tryParse(_leaveEntCtrl.text.trim()) ?? 14,
              usedAnnualLeave: int.tryParse(_leaveUsedCtrl.text.trim()) ?? 0,
              kpiScore: double.tryParse(_kpiCtrl.text.trim()) ?? 92.0,
              password: _passwordCtrl.text.trim().isEmpty
                  ? '1234'
                  : _passwordCtrl.text.trim(),
              allowedModules: orderedModules.isEmpty
                  ? const <HasibuModule>[HasibuModule.employeePortal]
                  : orderedModules,
              photoPath: _photoPathCtrl.text.trim().isEmpty
                  ? null
                  : _photoPathCtrl.text.trim(),
              themeMode: _empThemeMode,
            );
            final saveFuture =
                ref.read(pdksDashboardProvider.notifier).saveEmployee(emp);
            unawaited(
              saveFuture.catchError((Object e) {
                debugPrint(
                  'Personel kaydetme arka plan senkronizasyon uyarısı: $e',
                );
              }),
            );
            Navigator.of(context).pop();
          },
          child: const Text('Kaydet'),
        ),
      ],
    );
  }
}

class _EmployeeManagementCard extends StatelessWidget {
  final EmployeeDailyStatus item;
  final int docCount;
  final VoidCallback onOpenDossier;
  final VoidCallback onOpenDocuments;
  final VoidCallback onEdit;
  final VoidCallback onQuickExit;
  final VoidCallback onQuickRehire;
  final VoidCallback onDelete;

  const _EmployeeManagementCard({
    required this.item,
    required this.docCount,
    required this.onOpenDossier,
    required this.onOpenDocuments,
    required this.onEdit,
    required this.onQuickExit,
    required this.onQuickRehire,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final pal = HasibuPalette.of(context);
    final emp = item.employee;
    final bool isSeparated = emp.isSeparatedNow;
    final bool hasScheduledExit = emp.hasExitDate && !isSeparated;

    final (Color statusBg, Color statusFg, String statusText) = isSeparated
        ? (
            const Color(0xFFDC2626).withValues(alpha: 0.13),
            const Color(0xFFDC2626),
            'İŞTEN AYRILDI',
          )
        : (hasScheduledExit
            ? (
                const Color(0xFFD97706).withValues(alpha: 0.14),
                const Color(0xFFD97706),
                'ÇIKIŞ PLANLI',
              )
            : (
                const Color(0xFF059669).withValues(alpha: 0.14),
                const Color(0xFF059669),
                'AKTİF',
              ));

    final Color sgkColor = emp.sgkActive
        ? const Color(0xFF059669)
        : const Color(0xFF64748B);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: isSeparated ? pal.subtle : pal.card,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onOpenDossier,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSeparated
                    ? const Color(0xFFDC2626).withValues(alpha: 0.25)
                    : pal.border,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Opacity(
                      opacity: isSeparated ? 0.72 : 1.0,
                      child: EmployeeProfileAvatar(
                        employee: emp,
                        size: 48,
                        borderColor: isSeparated
                            ? const Color(0xFF64748B).withValues(alpha: 0.5)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                '${emp.fullName} (#${emp.cardNo})',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: pal.textPrimary,
                                ),
                              ),
                              _EmpMiniTag(
                                label: statusText,
                                bg: statusBg,
                                fg: statusFg,
                              ),
                              _EmpMiniTag(
                                label: emp.sgkActive
                                    ? 'SGK AKTİF'
                                    : 'SGK PASİF',
                                bg: sgkColor.withValues(alpha: 0.13),
                                fg: sgkColor,
                              ),
                              _EmpMiniTag(
                                label: 'Tema: ${emp.themeMode.label}',
                                bg: pal.chip,
                                fg: pal.textSecondary,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${item.branch.name} • ${item.department.name} • ${emp.title} • '
                            'Mesai: ${item.shift.name} • İzin: ${emp.remainingAnnualLeave} G • KPI: %${emp.kpiScore.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: pal.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              _EmpMiniTag(
                                icon: Icons.login_rounded,
                                label:
                                    'İşe Giriş: ${PdksDashboardNotifier.formatDisplayDate(emp.hireDate, includeTodayBadge: false)}',
                                bg: pal.chip,
                                fg: pal.textPrimary,
                              ),
                              if (emp.hasExitDate)
                                _EmpMiniTag(
                                  icon: Icons.logout_rounded,
                                  label:
                                      'İşten Çıkış: ${PdksDashboardNotifier.formatDisplayDate(emp.normalizedExitDate!, includeTodayBadge: false)}',
                                  bg: const Color(0xFFDC2626)
                                      .withValues(alpha: 0.11),
                                  fg: const Color(0xFFDC2626),
                                ),
                              _EmpMiniTag(
                                icon: Icons.workspace_premium_outlined,
                                label: 'Kıdem: ${emp.tenureSummaryAt()}',
                                bg: const Color(0xFF0284C7)
                                    .withValues(alpha: 0.10),
                                fg: const Color(0xFF0284C7),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'Yetkiler:',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: pal.textSecondary,
                                ),
                              ),
                              for (final mod in emp.allowedModules)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0284C7)
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: const Color(0xFF0284C7)
                                          .withValues(alpha: 0.30),
                                    ),
                                  ),
                                  child: Text(
                                    mod.title,
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF0284C7),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: onOpenDossier,
                      icon: const Icon(Icons.history_rounded, size: 16),
                      label: const Text('Personel Geçmişi'),
                    ),
                    OutlinedButton.icon(
                      onPressed: onOpenDocuments,
                      icon: const Icon(Icons.folder_shared_rounded, size: 16),
                      label: Text('Özlük Dosyası ($docCount)'),
                    ),
                    if (!emp.hasExitDate)
                      OutlinedButton.icon(
                        key: ValueKey('quick_exit_employee_${emp.cardNo}'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFDC2626),
                        ),
                        onPressed: onQuickExit,
                        icon: const Icon(Icons.person_off_outlined, size: 16),
                        label: const Text('İşten Çıkış'),
                      )
                    else
                      OutlinedButton.icon(
                        key: ValueKey('quick_rehire_employee_${emp.cardNo}'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF059669),
                        ),
                        onPressed: onQuickRehire,
                        icon: const Icon(Icons.restart_alt_rounded, size: 16),
                        label: const Text('Tekrar Aktif Et'),
                      ),
                    FilledButton.tonalIcon(
                      key: ValueKey('edit_employee_btn_${emp.cardNo}'),
                      onPressed: onEdit,
                      icon: const Icon(Icons.manage_accounts_rounded, size: 16),
                      label: const Text('Kartı Düzenle'),
                    ),
                    IconButton(
                      color: const Color(0xFFDC2626),
                      tooltip: 'Personeli Sil',
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmpMiniTag extends StatelessWidget {
  final IconData? icon;
  final String label;
  final Color bg;
  final Color fg;

  const _EmpMiniTag({
    this.icon,
    required this.label,
    required this.bg,
    required this.fg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
