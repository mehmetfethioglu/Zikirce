import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/pdks_models.dart';
import '../providers/pdks_providers.dart';

class _UsersCardPalette {
  final bool isDark;

  const _UsersCardPalette(this.isDark);

  factory _UsersCardPalette.of(BuildContext context) =>
      _UsersCardPalette(Theme.of(context).brightness == Brightness.dark);

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
}

/// Aynı şirket ve aynı Gmail bulut yedeği içinde birden fazla yetkili kullanıcı
/// (Tam Yönetici, İK Yöneticisi, Şube Sorumlusu, Personel) tanımlama ve yönetme kartı.
class AppUsersManagementCard extends ConsumerWidget {
  const AppUsersManagementCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pal = _UsersCardPalette.of(context);
    final appUsers =
        ref.watch(pdksDashboardProvider.select((s) => s.appUsers));
    final branches =
        ref.watch(pdksDashboardProvider.select((s) => s.branches));
    final adminUsername = ref.watch(
      pdksDashboardProvider.select((s) => s.companySettings.adminUsername),
    );
    final syncGmail = ref.watch(
      pdksDashboardProvider.select((s) => s.companySettings.syncGmailAccount),
    );

    final branchNameById = <int, String>{
      for (final b in branches) b.id: b.name,
    };

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: pal.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: pal.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.group_add_rounded,
                    color: Color(0xFF0284C7),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Yetkili Kullanıcılar & Aynı Bulut Hesabında Çoklu Kullanıcı',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: pal.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              FilledButton.icon(
                key: const ValueKey('btn_add_app_user'),
                onPressed: () => _showAppUserEditDialog(context, ref, null),
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 17),
                label: const Text('Yeni Kullanıcı Ekle'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0284C7).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF0284C7).withValues(alpha: 0.25),
              ),
            ),
            child: Text(
              'Aynı Gmail hesabında (${syncGmail.isEmpty ? "bağlanınca" : syncGmail}) iki şekilde çoklu kullanıcı açabilirsiniz: '
              '(1) Buradan eklediğiniz yöneticiler ve Personel & Bölüm sekmesindeki personeller tek bulut yedeği içinde tüm cihazlara eşitlenir. '
              '(2) Farklı işletmeler veya izole kasalar için "Bulut Yedek Merkezi -> Çoklu Yedek Profili" bölümünden ayrı profil kodu tanımlayabilirsiniz.',
              style: TextStyle(
                fontSize: 11.5,
                color: pal.textSecondary,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Kök ana yönetici kartı
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: pal.subtle,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: pal.border),
            ),
            child: Wrap(
              spacing: 10,
              runSpacing: 6,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.verified_user_rounded,
                      color: Color(0xFF10B981),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            adminUsername,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13.5,
                              color: pal.textPrimary,
                            ),
                          ),
                          Text(
                            'Ana Yönetici (Sistem Sahibi • Tüm Modüller & Tüm Şubeler)',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: pal.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Kök Hesap',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          if (appUsers.isEmpty)
            Text(
              'Henüz ek yetkili kullanıcı tanımlanmadı. İK sorumlusu veya şube yöneticisi eklemek için "Yeni Kullanıcı Ekle" butonunu kullanın.',
              style: TextStyle(fontSize: 12, color: pal.textSecondary),
            )
          else
            for (final user in appUsers)
              Container(
                key: ValueKey('app_user_row_${user.username}'),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: pal.subtle,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: pal.border),
                ),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              '${user.displayName} (@${user.username})',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                                color: pal.textPrimary,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0284C7)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                user.role.label,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0284C7),
                                ),
                              ),
                            ),
                            if (!user.isActive)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444)
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: const Text(
                                  'Pasif',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFDC2626),
                                  ),
                                ),
                              ),
                            if (user.role == AppUserRole.branchSupervisor &&
                                !user.hasBranchRestriction)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444)
                                      .withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: const Text(
                                  'Şube Atanmadı!',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFDC2626),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Builder(
                          builder: (_) {
                            final userBranchIds =
                                user.effectiveAllowedBranchIds;
                            final String branchSummary;
                            if (userBranchIds.isEmpty) {
                              branchSummary =
                                  user.role == AppUserRole.branchSupervisor
                                      ? 'Atanmadı (Düzenleyin)'
                                      : 'Tüm Şubeler';
                            } else {
                              branchSummary = userBranchIds
                                  .map((id) => branchNameById[id] ?? '#$id')
                                  .join(', ');
                            }
                            return Text(
                              'Modüller: ${user.allowedModules.map((m) => m.title).join(', ')} • '
                              'Şube: $branchSummary'
                              '${user.linkedGmail?.isNotEmpty == true ? " • ${user.linkedGmail}" : ""}',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: pal.textSecondary,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          key: ValueKey('switch_app_user_active_${user.username}'),
                          value: user.isActive,
                          onChanged: (val) => ref
                              .read(pdksDashboardProvider.notifier)
                              .toggleAppUserActive(user.id, val),
                        ),
                        IconButton(
                          tooltip: 'Kullanıcıyı Düzenle',
                          onPressed: () =>
                              _showAppUserEditDialog(context, ref, user),
                          icon: const Icon(Icons.edit_outlined, size: 19),
                        ),
                        IconButton(
                          tooltip: 'Kullanıcıyı Sil',
                          color: const Color(0xFFDC2626),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (dCtx) => AlertDialog(
                                title: const Text('Kullanıcıyı Sil'),
                                content: Text(
                                  '"${user.displayName}" (@${user.username}) kullanıcısını silmek istediğinize emin misiniz?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(dCtx).pop(false),
                                    child: const Text('İptal'),
                                  ),
                                  FilledButton(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFFDC2626),
                                    ),
                                    onPressed: () =>
                                        Navigator.of(dCtx).pop(true),
                                    child: const Text('Sil'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              await ref
                                  .read(pdksDashboardProvider.notifier)
                                  .deleteAppUser(user.id);
                            }
                          },
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 19,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

Future<void> _showAppUserEditDialog(
  BuildContext context,
  WidgetRef ref,
  AppUserAccount? existing,
) async {
  await showDialog<void>(
    context: context,
    builder: (_) => _AppUserEditDialog(existing: existing),
  );
}

class _AppUserEditDialog extends ConsumerStatefulWidget {
  final AppUserAccount? existing;

  const _AppUserEditDialog({required this.existing});

  @override
  ConsumerState<_AppUserEditDialog> createState() => _AppUserEditDialogState();
}

class _AppUserEditDialogState extends ConsumerState<_AppUserEditDialog> {
  late final TextEditingController _usernameCtrl;
  late final TextEditingController _displayNameCtrl;
  late final TextEditingController _passwordCtrl;
  late final TextEditingController _gmailCtrl;
  late AppUserRole _selectedRole;
  late Set<HasibuModule> _selectedModules;
  late Set<int> _selectedBranchIds;
  late bool _isActive;
  bool _isSaving = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _usernameCtrl = TextEditingController(text: e?.username ?? '');
    _displayNameCtrl = TextEditingController(text: e?.displayName ?? '');
    _passwordCtrl = TextEditingController();
    _gmailCtrl = TextEditingController(text: e?.linkedGmail ?? '');
    _selectedRole = e?.role ?? AppUserRole.hrManager;
    _selectedModules = Set<HasibuModule>.from(
      e?.allowedModules ?? _selectedRole.defaultModules,
    );
    _selectedBranchIds = Set<int>.from(
      e?.effectiveAllowedBranchIds ?? const <int>[],
    );
    _isActive = e?.isActive ?? true;
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _displayNameCtrl.dispose();
    _passwordCtrl.dispose();
    _gmailCtrl.dispose();
    super.dispose();
  }

  int? _defaultBranchIdForSupervisor(List<Branch> branches) {
    for (final b in branches) {
      if (b.id != 1) return b.id;
    }
    return branches.isNotEmpty ? branches.first.id : null;
  }

  @override
  Widget build(BuildContext context) {
    final branches =
        ref.watch(pdksDashboardProvider.select((s) => s.branches));
    final isNew = widget.existing == null;
    final isBranchSupervisor =
        _selectedRole == AppUserRole.branchSupervisor;
    final validBranchIds = branches.map((b) => b.id).toSet();
    final effectiveSelectedIds =
        _selectedBranchIds.where(validBranchIds.contains).toSet();
    if (isBranchSupervisor && effectiveSelectedIds.isEmpty) {
      final fallbackId = _defaultBranchIdForSupervisor(branches);
      if (fallbackId != null) {
        effectiveSelectedIds.add(fallbackId);
      }
    }
    final nonMerkezBranches =
        branches.where((b) => b.id != 1).toList(growable: false);

    return AlertDialog(
      title: Text(
        isNew ? 'Yeni Yetkili Kullanıcı Ekle' : 'Kullanıcı Yetkilerini Düzenle',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                key: const ValueKey('app_user_username_field'),
                controller: _usernameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Kullanıcı Adı',
                  hintText: 'ör. ik_ayse veya sube_bursa',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const ValueKey('app_user_display_name_field'),
                controller: _displayNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Ad Soyad / Görünen Ad',
                  hintText: 'Ayşe Yılmaz (İK Uzmanı)',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const ValueKey('app_user_password_field'),
                controller: _passwordCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: isNew
                      ? 'Giriş Parolası'
                      : 'Yeni Parola (Boş bırakılırsa değişmez)',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<AppUserRole>(
                key: const ValueKey('app_user_role_dropdown'),
                initialValue: _selectedRole,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Kullanıcı Rolü',
                  prefixIcon: Icon(Icons.admin_panel_settings_outlined),
                ),
                items: [
                  for (final role in AppUserRole.values)
                    DropdownMenuItem<AppUserRole>(
                      value: role,
                      child: Text(role.label),
                    ),
                ],
                onChanged: (role) {
                  if (role == null) return;
                  setState(() {
                    _selectedRole = role;
                    _selectedModules = Set<HasibuModule>.from(
                      role.defaultModules,
                    );
                    if (role == AppUserRole.branchSupervisor &&
                        _selectedBranchIds.isEmpty) {
                      final def = _defaultBranchIdForSupervisor(branches);
                      if (def != null) _selectedBranchIds.add(def);
                    }
                  });
                },
              ),
              const SizedBox(height: 10),
              const Text(
                'Erişebileceği Modüller',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final mod in HasibuModule.activePhaseModules)
                    FilterChip(
                      label: Text(mod.title),
                      selected: _selectedModules.contains(mod),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedModules.add(mod);
                          } else if (_selectedModules.length > 1) {
                            _selectedModules.remove(mod);
                          }
                        });
                      },
                    ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Şube Kapsamı',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF0284C7).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            effectiveSelectedIds.isEmpty
                                ? 'Tüm Şubeler'
                                : '${effectiveSelectedIds.length} Şube Seçili',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0284C7),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (nonMerkezBranches.length > 1)
                      TextButton(
                        key: const ValueKey(
                          'app_user_branch_select_non_merkez',
                        ),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        onPressed: () {
                          setState(() {
                            _selectedBranchIds
                              ..clear()
                              ..addAll(nonMerkezBranches.map((b) => b.id));
                          });
                        },
                        child: const Text(
                          'Merkez Hariç Tümü',
                          style: TextStyle(fontSize: 11.5),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (!isBranchSupervisor)
                    FilterChip(
                      key: const ValueKey('app_user_branch_chip_all'),
                      label: const Text('Tüm Şubeler'),
                      selected: effectiveSelectedIds.isEmpty,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedBranchIds.clear());
                        }
                      },
                    ),
                  for (final b in branches)
                    FilterChip(
                      key: ValueKey('app_user_branch_chip_${b.id}'),
                      avatar: Icon(
                        b.hasTerminal
                            ? Icons.face_retouching_natural
                            : Icons.storefront,
                        size: 14,
                      ),
                      label: Text(b.name),
                      selected: effectiveSelectedIds.contains(b.id),
                      onSelected: (selected) {
                        setState(() {
                          _selectedBranchIds
                            ..clear()
                            ..addAll(effectiveSelectedIds);
                          if (selected) {
                            _selectedBranchIds.add(b.id);
                          } else if (!isBranchSupervisor ||
                              _selectedBranchIds.length > 1) {
                            _selectedBranchIds.remove(b.id);
                          }
                        });
                      },
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                isBranchSupervisor
                    ? 'Şube Sorumlusu yalnızca seçili şubelerin verilerini görür (birden fazla şube seçebilirsiniz).'
                    : (effectiveSelectedIds.isEmpty
                        ? 'Tüm şubelerin ve merkezin verilerine erişir.'
                        : 'Yalnızca seçili ${effectiveSelectedIds.length} şubenin verilerine erişir.'),
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const ValueKey('app_user_gmail_field'),
                controller: _gmailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Bağlı E-Posta / Not (İsteğe Bağlı)',
                  hintText: 'ornek@gmail.com',
                  prefixIcon: Icon(Icons.alternate_email_rounded),
                ),
              ),
              SwitchListTile(
                key: const ValueKey('app_user_active_switch'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Hesap Aktif'),
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 6),
                Text(
                  _errorText!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFDC2626),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('İptal'),
        ),
        FilledButton(
          key: const ValueKey('btn_save_app_user'),
          onPressed: _isSaving
              ? null
              : () async {
                  setState(() {
                    _isSaving = true;
                    _errorText = null;
                  });
                  final orderedModules = HasibuModule.activePhaseModules
                      .where((m) => _selectedModules.contains(m))
                      .toList(growable: false);
                  final sortedBranchIds = effectiveSelectedIds.toList()..sort();
                  final err = await ref
                      .read(pdksDashboardProvider.notifier)
                      .saveAppUser(
                        existingId: widget.existing?.id,
                        username: _usernameCtrl.text,
                        displayName: _displayNameCtrl.text,
                        plainPassword: _passwordCtrl.text,
                        role: _selectedRole,
                        allowedModules: orderedModules,
                        allowedBranchIds: sortedBranchIds,
                        linkedGmail: _gmailCtrl.text,
                        isActive: _isActive,
                      );
                  if (!context.mounted) return;
                  if (err != null) {
                    setState(() {
                      _isSaving = false;
                      _errorText = err;
                    });
                    return;
                  }
                  Navigator.of(context).pop();
                },
          child: Text(_isSaving ? 'Kaydediliyor...' : 'Kaydet'),
        ),
      ],
    );
  }
}
