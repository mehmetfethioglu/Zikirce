import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/google_drive_sync_service.dart';
import '../../domain/pdks_models.dart';
import '../providers/pdks_providers.dart';

// ============================================================================
// ORTAK BİLEŞEN 0: MİNİMALİST TEMA PALETİ (AÇIK / KOYU / SİSTEM UYUMLU)
// ============================================================================
class HasibuPalette {
  final bool isDark;

  const HasibuPalette._(this.isDark);

  factory HasibuPalette.of(BuildContext context) {
    return HasibuPalette._(Theme.of(context).brightness == Brightness.dark);
  }

  Color get bg => isDark ? const Color(0xFF0B1120) : const Color(0xFFF8FAFC);
  Color get card => isDark ? const Color(0xFF111827) : Colors.white;
  Color get subtle =>
      isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
  Color get chip => isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
  Color get border =>
      isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
  Color get textPrimary =>
      isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
  Color get textSecondary =>
      isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  Color get textMuted =>
      isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
  Color get activeBg =>
      isDark ? const Color(0xFF0284C7) : const Color(0xFF0F172A);
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

  static Future<String?> pickLogoFromDesktop() async {
    if (!Platform.isWindows) return null;
    try {
      final result = await Process.run('powershell', <String>[
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: pal.subtle,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: pal.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_iconForTheme(activeTheme), size: 15, color: pal.textPrimary),
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
      final result = await Process.run('powershell', <String>[
        '-NoProfile',
        '-Command',
        "Add-Type -AssemblyName System.Windows.Forms; "
            "\$f = New-Object System.Windows.Forms.OpenFileDialog; "
            "\$f.Title = 'Personel Profil Fotoğrafı Seçin'; "
            "\$f.Filter = 'Görsel Dosyaları (*.jpg;*.jpeg;*.png;*.webp)|*.jpg;*.jpeg;*.png;*.webp'; "
            "if (\$f.ShowDialog() -eq 'OK') { Write-Output \$f.FileName }",
      ]);
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
      final result = await Process.run('powershell', <String>[
        '-NoProfile',
        '-Command',
        "Add-Type -AssemblyName System.Windows.Forms; "
            "\$d = New-Object System.Windows.Forms.FolderBrowserDialog; "
            "\$d.Description = 'Google Drive Senkronizasyon Klasörünü Seçin'; "
            "if (\$d.ShowDialog() -eq 'OK') { Write-Output \$d.SelectedPath }",
      ]);
      final path = result.stdout.toString().trim();
      return path.isNotEmpty ? path : null;
    } catch (_) {
      return null;
    }
  }
}

// ============================================================================
// ORTAK BİLEŞEN 2: GOOGLE (GMAIL) & DRIVE VERİ EŞİTLEME KURULUM MODALI
// ============================================================================
Future<void> showGmailDriveSyncDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final state = ref.read(pdksDashboardProvider);
  final gmailCtrl = TextEditingController(
    text: state.companySettings.syncGmailAccount,
  );
  final folderCtrl = TextEditingController(
    text: state.companySettings.syncFolderPath,
  );
  final tokenCtrl = TextEditingController();

  await showDialog<void>(
    context: context,
    builder: (dialogCtx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.cloud_sync_rounded, color: Color(0xFF0284C7)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Gmail & Google Drive Veri Eşitleme Ayarları',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Şubeler, işyeri bilgisayarı ve mobil cihazlar arasında verileri eşitlemek için kurumsal Gmail hesabınızı tanımlayın.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: gmailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Eşitleme Yapılacak Gmail Hesabı',
                    hintText: 'ornek.isletme@gmail.com',
                    prefixIcon: Icon(Icons.alternate_email_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: folderCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Google Drive Masaüstü Klasörü (Önerilen)',
                          hintText: r"Örn: G:\Drive'ım\Hasibu_Sync",
                          prefixIcon: Icon(Icons.folder_shared_outlined),
                        ),
                      ),
                    ),
                    if (Platform.isWindows) ...[
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await EmployeeProfileAvatar
                              .pickFolderFromDesktop();
                          if (picked != null) {
                            setDialogState(() => folderCtrl.text = picked);
                          }
                        },
                        icon: const Icon(Icons.folder_open_rounded, size: 18),
                        label: const Text('Seç'),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: tokenCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Google Cloud OAuth2 Anahtarı (İsteğe Bağlı)',
                    hintText: 'Doğrudan bulut API erişimi için ya29.a0...',
                    prefixIcon: Icon(Icons.vpn_key_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.verified_user_outlined,
                        size: 18,
                        color: Color(0xFF0284C7),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Yedek Dosyası: ${GoogleDriveSyncService.backupFileName}\n'
                          'Durum: ${state.syncStatus.message}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Kapat'),
          ),
          FilledButton.icon(
            onPressed: () async {
              await ref
                  .read(pdksDashboardProvider.notifier)
                  .saveGmailSyncAccount(
                    gmailAccount: gmailCtrl.text.trim(),
                    syncFolderPath: folderCtrl.text.trim(),
                    accessToken: tokenCtrl.text.trim().isEmpty
                        ? null
                        : tokenCtrl.text.trim(),
                  );
              if (dialogCtx.mounted) {
                Navigator.of(dialogCtx).pop();
              }
            },
            icon: const Icon(Icons.cloud_done_rounded, size: 18),
            label: const Text('Gmail Hesabını Kaydet & Eşitle'),
          ),
        ],
      ),
    ),
  );

  gmailCtrl.dispose();
  folderCtrl.dispose();
  tokenCtrl.dispose();
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

    return ListView(
      padding: const EdgeInsets.all(20),
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
                'Cihazlar arası veri eşitleme için Gmail adresinizi ve varsa Google Drive klasörünüzü girin. (${syncStatus.message})',
                style: TextStyle(fontSize: 12, color: pal.textSecondary),
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
                        hintText: r"G:\Drive'ım\Hasibu_Sync",
                        prefixIcon: Icon(Icons.folder_shared_outlined),
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => showGmailDriveSyncDialog(context, ref),
                    icon: const Icon(Icons.cloud_sync_rounded, size: 18),
                    label: const Text('Gelişmiş Gmail / OAuth Bağlantısı'),
                  ),
                  FilledButton.icon(
                    onPressed: () async {
                      final mins =
                          int.tryParse(_pollMinutesCtrl.text.trim()) ?? 5;
                      await ref
                          .read(pdksDashboardProvider.notifier)
                          .updateCompanySettings(
                            settings.copyWith(
                              companyName: _companyNameCtrl.text.trim(),
                              autoPollMinutes: mins.clamp(1, 1440),
                              adminUsername: _adminUserCtrl.text.trim(),
                              adminPassword: _adminPassCtrl.text.trim(),
                              defaultEmployeePin: _empPinCtrl.text.trim(),
                              syncGmailAccount: _gmailCtrl.text.trim(),
                              syncFolderPath: _driveFolderCtrl.text.trim(),
                            ),
                          );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Şirket, parola ve Gmail bulut eşitleme ayarları kaydedildi.',
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
      ],
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
    final ipCtrl =
        TextEditingController(text: existing?.terminalIp ?? '192.168.9.150');
    final portCtrl = TextEditingController(
      text: (existing?.terminalPort ?? 4370).toString(),
    );
    final machineCtrl = TextEditingController(
      text: (existing?.machineNo ?? 1).toString(),
    );
    final latCtrl = TextEditingController(
      text: (existing?.latitude ?? 37.1674).toString(),
    );
    final lngCtrl = TextEditingController(
      text: (existing?.longitude ?? 38.7955).toString(),
    );
    final radiusCtrl = TextEditingController(
      text: (existing?.geofenceRadiusMeters ?? 150).round().toString(),
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
                          labelText: 'Şube / Lokasyon Adı (örn. Şube Karaköprü)',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: codeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Şube Kısa Kodu (örn. KARAKOPRU)',
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
                      latitude: double.tryParse(latCtrl.text.trim()) ?? 37.1674,
                      longitude:
                          double.tryParse(lngCtrl.text.trim()) ?? 38.7955,
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
      if (_onlyAbsentFilter && s.allLogsOfDay.isNotEmpty) {
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
                                  backgroundColor: log.isCheckIn
                                      ? const Color(0xFF059669)
                                          .withValues(alpha: 0.14)
                                      : const Color(0xFFD97706)
                                          .withValues(alpha: 0.14),
                                  label: Text(
                                    '${log.isCheckIn ? "GİRİŞ" : "ÇIKIŞ"}: ${log.timeFormatted}',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: log.isCheckIn
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pdksDashboardProvider);
    final pal = HasibuPalette.of(context);
    final employees =
        state.dailyStatuses.map((e) => e.employee).toList(growable: false);
    final empMap = {for (final e in employees) e.id: e};

    if (_selectedEmployeeId == null && employees.isNotEmpty) {
      _selectedEmployeeId = employees.first.id;
    }

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
                    width: 165,
                    child: TextField(
                      controller: _startDateCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Başlangıç (YYYY-AA-GG)',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 165,
                    child: TextField(
                      controller: _endDateCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Bitiş (YYYY-AA-GG)',
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pdksDashboardProvider);
    final pal = HasibuPalette.of(context);
    final q = _searchCtrl.text.trim().toUpperCase();
    final filtered = state.dailyStatuses.where((s) {
      if (q.isEmpty) return true;
      return s.employee.fullName.toUpperCase().contains(q) ||
          s.employee.cardNo.contains(q) ||
          s.department.name.toUpperCase().contains(q);
    }).toList(growable: false);

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
        const SizedBox(height: 14),
        for (final item in filtered)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
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
                    EmployeeProfileAvatar(
                      employee: item.employee,
                      size: 48,
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                '${item.employee.fullName} (#${item.employee.cardNo})',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
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
                                  'Parola: ${item.employee.password}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: pal.textSecondary,
                                  ),
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
                                  'Tema: ${item.employee.themeMode.label}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: pal.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${item.branch.name} • ${item.department.name} • ${item.employee.title} • '
                            'Mesai: ${item.shift.name} • İzin: ${item.employee.remainingAnnualLeave} G • KPI: %${item.employee.kpiScore.toStringAsFixed(0)}',
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
                              Text(
                                'Yetki Alanları:',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: pal.textSecondary,
                                ),
                              ),
                              for (final mod in item.employee.allowedModules)
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
                Wrap(
                  spacing: 6,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: () =>
                          _showEmployeeDialog(context, item.employee),
                      icon: const Icon(Icons.manage_accounts_rounded, size: 16),
                      label: const Text('Fotoğraf, Parola & Yetki Düzenle'),
                    ),
                    IconButton(
                      color: const Color(0xFFDC2626),
                      tooltip: 'Personeli Sil',
                      onPressed: () => ref
                          .read(pdksDashboardProvider.notifier)
                          .deleteEmployee(item.employee.id),
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
  ) async {
    final state = ref.read(pdksDashboardProvider);
    final nextId = existing?.id ??
        (state.dailyStatuses.isEmpty
            ? 3000
            : state.dailyStatuses
                    .map((s) => s.employee.id)
                    .reduce((a, b) => a > b ? a : b) +
                1);

    final cardCtrl = TextEditingController(
      text: existing?.cardNo ?? nextId.toString().padLeft(5, '0'),
    );
    final nameCtrl = TextEditingController(text: existing?.fullName ?? '');
    final titleCtrl =
        TextEditingController(text: existing?.title ?? 'ÜRETİM PERSONELİ');
    final hireCtrl =
        TextEditingController(text: existing?.hireDate ?? '2026-10-19');
    final passwordCtrl =
        TextEditingController(text: existing?.password ?? '1234');
    final photoPathCtrl =
        TextEditingController(text: existing?.photoPath ?? '');
    final leaveEntCtrl = TextEditingController(
      text: (existing?.annualLeaveEntitlement ?? 14).toString(),
    );
    final leaveUsedCtrl = TextEditingController(
      text: (existing?.usedAnnualLeave ?? 0).toString(),
    );
    final kpiCtrl = TextEditingController(
      text: (existing?.kpiScore ?? 95.0).toStringAsFixed(0),
    );

    int branchId = existing?.branchId ??
        (state.branches.isNotEmpty ? state.branches.first.id : 1);
    int deptId = existing?.departmentId ??
        (state.departments.isNotEmpty ? state.departments.first.id : 1);
    int shiftId = existing?.shiftId ??
        (state.shifts.isNotEmpty ? state.shifts.first.id : 1);
    bool sgkActive = existing?.sgkActive ?? true;
    HasibuThemeMode empThemeMode = existing?.themeMode ?? HasibuThemeMode.light;
    final Set<HasibuModule> selectedModules = <HasibuModule>{
      ...(existing?.allowedModules ??
          const <HasibuModule>[HasibuModule.employeePortal]),
    };

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final pal = HasibuPalette.of(ctx);
          final previewEmp = Employee(
            id: nextId,
            cardNo: cardCtrl.text,
            fullName:
                nameCtrl.text.isEmpty ? 'Personel' : nameCtrl.text.toUpperCase(),
            title: titleCtrl.text,
            departmentId: deptId,
            branchId: branchId,
            hireDate: hireCtrl.text,
            photoPath: photoPathCtrl.text.trim().isEmpty
                ? null
                : photoPathCtrl.text.trim(),
            themeMode: empThemeMode,
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
                                          if (picked != null) {
                                            setDialogState(
                                              () => photoPathCtrl.text = picked,
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
                                        onTap: () => setDialogState(
                                          () =>
                                              photoPathCtrl.text = 'preset:$i',
                                        ),
                                        borderRadius: BorderRadius.circular(14),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: photoPathCtrl.text ==
                                                    'preset:$i'
                                                ? const Color(0xFF0284C7)
                                                    .withValues(alpha: 0.2)
                                                : pal.card,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                              color: pal.border,
                                            ),
                                          ),
                                          child: Text(
                                            'Stil $i',
                                            style:
                                                const TextStyle(fontSize: 11),
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
                            controller: cardCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Kart / Sicil No (örn. 00064)',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: nameCtrl,
                            onChanged: (_) => setDialogState(() {}),
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
                            controller: passwordCtrl,
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
                            controller: titleCtrl,
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
                            selected: {empThemeMode},
                            onSelectionChanged: (sel) => setDialogState(
                              () => empThemeMode = sel.first,
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
                              const Text(
                                'Personel Yetki Alanları (Girişte Görebileceği Modüller)',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5,
                                ),
                              ),
                              TextButton(
                                onPressed: () => setDialogState(() {
                                  selectedModules.addAll(HasibuModule.values);
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
                              for (final mod in HasibuModule.values)
                                FilterChip(
                                  selected: selectedModules.contains(mod),
                                  label: Text(
                                    mod.title,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  onSelected: (val) {
                                    setDialogState(() {
                                      if (val) {
                                        selectedModules.add(mod);
                                      } else if (selectedModules.length > 1) {
                                        selectedModules.remove(mod);
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
                            initialValue: branchId,
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
                              if (v != null) setDialogState(() => branchId = v);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            isExpanded: true,
                            initialValue: deptId,
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
                              if (v != null) setDialogState(() => deptId = v);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      isExpanded: true,
                      initialValue: shiftId,
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
                        if (v != null) setDialogState(() => shiftId = v);
                      },
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: leaveEntCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'İzin Hakkı',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: leaveUsedCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Kullanılan',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: kpiCtrl,
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
                      value: sgkActive,
                      onChanged: (v) => setDialogState(() => sgkActive = v),
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
                  final orderedModules = HasibuModule.values
                      .where((m) => selectedModules.contains(m))
                      .toList(growable: false);
                  final emp = Employee(
                    id: nextId,
                    cardNo: cardCtrl.text.trim().padLeft(5, '0'),
                    fullName: nameCtrl.text.trim().toUpperCase(),
                    title: titleCtrl.text.trim().toUpperCase(),
                    departmentId: deptId,
                    branchId: branchId,
                    shiftId: shiftId,
                    hireDate: hireCtrl.text.trim(),
                    sgkActive: sgkActive,
                    annualLeaveEntitlement:
                        int.tryParse(leaveEntCtrl.text.trim()) ?? 14,
                    usedAnnualLeave:
                        int.tryParse(leaveUsedCtrl.text.trim()) ?? 0,
                    kpiScore: double.tryParse(kpiCtrl.text.trim()) ?? 92.0,
                    password: passwordCtrl.text.trim().isEmpty
                        ? '1234'
                        : passwordCtrl.text.trim(),
                    allowedModules: orderedModules.isEmpty
                        ? const <HasibuModule>[HasibuModule.employeePortal]
                        : orderedModules,
                    photoPath: photoPathCtrl.text.trim().isEmpty
                        ? null
                        : photoPathCtrl.text.trim(),
                    themeMode: empThemeMode,
                  );
                  await ref
                      .read(pdksDashboardProvider.notifier)
                      .saveEmployee(emp);
                  if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                },
                child: const Text('Kaydet'),
              ),
            ],
          );
        },
      ),
    );

    cardCtrl.dispose();
    nameCtrl.dispose();
    titleCtrl.dispose();
    hireCtrl.dispose();
    passwordCtrl.dispose();
    photoPathCtrl.dispose();
    leaveEntCtrl.dispose();
    leaveUsedCtrl.dispose();
    kpiCtrl.dispose();
  }
}
