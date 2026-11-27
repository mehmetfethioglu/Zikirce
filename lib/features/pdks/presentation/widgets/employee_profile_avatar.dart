import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../core/security/hasibu_security_service.dart';
import '../../../../core/services/company_logo_service.dart';
import '../../domain/pdks_models.dart';
import '../providers/pdks_providers.dart';
import 'hasibu_theme_palette.dart';

/// Kurumsal Şirket Logosu Rozeti (Katman 4 Atomik UI).
class CompanyLogoBadge extends StatelessWidget {
  final CompanySettings settings;
  final double size;
  final double borderRadius;
  final VoidCallback? onTap;
  final bool preferCompanyMonogramWhenDefault;

  const CompanyLogoBadge({
    super.key,
    required this.settings,
    this.size = 40,
    this.borderRadius = 11,
    this.onTap,
    this.preferCompanyMonogramWhenDefault = false,
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

  Widget _buildInitialsBadge() {
    return Container(
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
  }

  Widget _buildCorporatePlaceholderBadge(BuildContext context) {
    if (settings.hasCustomCompanyName) {
      return _buildInitialsBadge();
    }
    final pal = HasibuPalette.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: pal.subtle,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: pal.border),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.business_rounded,
        color: pal.isDark ? const Color(0xFF38BDF8) : const Color(0xFF0F172A),
        size: size * 0.48,
      ),
    );
  }

  Widget _buildContainedImageFrame(BuildContext context, Widget child) {
    final pal = HasibuPalette.of(context);
    final innerRadius = (borderRadius - 2).clamp(2.0, borderRadius);
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size >= 56 ? 4 : 2),
      decoration: BoxDecoration(
        color: pal.card,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: pal.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(innerRadius),
        child: child,
      ),
    );
  }

  Widget? _tryBuildBase64Logo(BuildContext context, int presetIdx) {
    final encoded = settings.logoDataBase64?.trim() ?? '';
    if (encoded.isEmpty) return null;
    try {
      final bytes = base64Decode(encoded);
      if (bytes.isEmpty) return null;
      return _buildContainedImageFrame(
        context,
        Image.memory(
          bytes,
          key: ValueKey('logo_mem_${encoded.hashCode}_${encoded.length}'),
          width: size,
          height: size,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          filterQuality: FilterQuality.high,
          isAntiAlias: true,
          errorBuilder: (ctx, error, stackTrace) =>
              preferCompanyMonogramWhenDefault
                  ? _buildCorporatePlaceholderBadge(ctx)
                  : _buildPreset(presetIdx),
        ),
      );
    } catch (e) {
      debugPrint('CompanyLogoBadge: base64 logo çözülemedi: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final raw = CompanyLogoService.normalizeInputPath(settings.logoPath ?? '');
    final bool isPreset = raw.startsWith('logo:');
    final int presetIdx = isPreset
        ? ((int.tryParse(raw.replaceFirst('logo:', '')) ?? 1) - 1)
            .clamp(0, presets.length - 1)
        : 0;

    Widget content;
    if (raw == 'logo:initials') {
      content = _buildInitialsBadge();
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
    } else if (raw.isNotEmpty && !isPreset) {
      final file = File(raw);
      if (file.existsSync()) {
        content = _buildContainedImageFrame(
          context,
          Image.file(
            file,
            key: ValueKey('logo_file_${file.path}'),
            width: size,
            height: size,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            filterQuality: FilterQuality.high,
            isAntiAlias: true,
            errorBuilder: (ctx, error, stackTrace) =>
                _tryBuildBase64Logo(ctx, presetIdx) ??
                (preferCompanyMonogramWhenDefault
                    ? _buildCorporatePlaceholderBadge(ctx)
                    : _buildPreset(presetIdx)),
          ),
        );
      } else {
        content = _tryBuildBase64Logo(context, presetIdx) ??
            (preferCompanyMonogramWhenDefault
                ? _buildCorporatePlaceholderBadge(context)
                : _buildPreset(presetIdx));
      }
    } else if (raw.isEmpty || raw == 'logo:1' || raw == 'logo:hasibu') {
      content = (!isPreset ? _tryBuildBase64Logo(context, presetIdx) : null) ??
          (preferCompanyMonogramWhenDefault
              ? _buildCorporatePlaceholderBadge(context)
              : ClipRRect(
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
                ));
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

  static Future<String?> pickLogoFromDesktop() {
    return PlatformCompanyLogoPickerGateway().pickLogoImagePath();
  }
}

/// Kullanıcıya özgü tema seçici (Açık / Koyu / Sistem).
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

/// Personel Profil Fotoğrafı / Minimalist Stüdyo Avatarı.
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

  static const MethodChannel _filesChannel = MethodChannel(
    'com.akarworks.hasibu/files',
  );

  static Future<String?> pickPhotoFromDevice() async {
    if (Platform.isWindows) return pickPhotoFromDesktop();
    if (Platform.isAndroid || Platform.isIOS) {
      try {
        final path = await _filesChannel.invokeMethod<String>('pickImageFile');
        final clean = path?.trim() ?? '';
        return clean.isEmpty ? null : clean;
      } catch (e) {
        debugPrint('EmployeeProfileAvatar: pickPhotoFromDevice hatası: $e');
      }
    }
    return null;
  }

  static Future<String?> pickDocumentFromDevice() async {
    if (Platform.isWindows) return pickDocumentFromDesktop();
    if (Platform.isAndroid || Platform.isIOS) {
      try {
        final path =
            await _filesChannel.invokeMethod<String>('pickDocumentFile');
        final clean = path?.trim() ?? '';
        return clean.isEmpty ? null : clean;
      } catch (e) {
        debugPrint('EmployeeProfileAvatar: pickDocumentFromDevice hatası: $e');
      }
    }
    return null;
  }

  static Future<String?> pickPhotoFromDesktop() {
    return pickWindowsPathWithPowerShell(r'''
$f = New-Object System.Windows.Forms.OpenFileDialog
$f.Title = 'Personel Profil Fotoğrafı Seçin'
$f.Filter = 'Görsel Dosyaları (*.jpg;*.jpeg;*.png;*.webp)|*.jpg;*.jpeg;*.png;*.webp'
$selectedPath = ''
if ($f.ShowDialog($owner) -eq [System.Windows.Forms.DialogResult]::OK) {
  $selectedPath = $f.FileName
}
''');
  }

  static Future<String?> pickFolderFromDesktop() {
    return pickWindowsPathWithPowerShell(r'''
$d = New-Object System.Windows.Forms.FolderBrowserDialog
$d.Description = 'Google Drive Senkronizasyon Klasörünü Seçin'
$selectedPath = ''
if ($d.ShowDialog($owner) -eq [System.Windows.Forms.DialogResult]::OK) {
  $selectedPath = $d.SelectedPath
}
''');
  }

  static Future<String?> pickDocumentFromDesktop() {
    return pickWindowsPathWithPowerShell(r'''
$f = New-Object System.Windows.Forms.OpenFileDialog
$f.Title = 'Personel Özlük Dosyası Resmi Evrak Dijital Kopyasını Seçin'
$f.Filter = 'Resmi Evrak & Görsel (*.pdf;*.jpg;*.jpeg;*.png;*.webp;*.doc;*.docx)|*.pdf;*.jpg;*.jpeg;*.png;*.webp;*.doc;*.docx|Tüm Dosyalar (*.*)|*.*'
$selectedPath = ''
if ($f.ShowDialog($owner) -eq [System.Windows.Forms.DialogResult]::OK) {
  $selectedPath = $f.FileName
}
''');
  }

  static Future<void> openDigitalDocument(String filePath) async {
    if (filePath.trim().isEmpty) return;
    try {
      final rawPath = filePath.trim();
      final f = File(rawPath);
      if (!f.existsSync()) return;

      File targetToOpen = f;
      if (rawPath.toLowerCase().endsWith('.hasibu_doc')) {
        final encryptedBytes = await f.readAsBytes();
        final plainBytes =
            await HasibuSecurityService.decryptDocumentBytes(encryptedBytes);
        final tempDir = await getTemporaryDirectory();
        final baseName = p
            .basename(rawPath)
            .replaceAll(RegExp(r'\.hasibu_doc$', caseSensitive: false), '');
        final safeName = baseName.isEmpty ? 'hasibu_document.pdf' : baseName;
        targetToOpen = File(p.join(tempDir.path, 'decrypted_$safeName'));
        await targetToOpen.writeAsBytes(plainBytes, flush: true);
      }

      if (Platform.isWindows) {
        await Process.run('explorer', <String>[targetToOpen.path]);
      } else if (Platform.isMacOS) {
        await Process.run('open', <String>[targetToOpen.path]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', <String>[targetToOpen.path]);
      }
    } catch (e) {
      debugPrint('EmployeeProfileAvatar: openDigitalDocument hatası ($filePath): $e');
    }
  }
}
