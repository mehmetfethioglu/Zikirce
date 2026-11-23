import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/release/hasibu_release_notes.dart';
import '../../domain/pdks_models.dart';
import '../providers/pdks_providers.dart';
import 'cloud_backup_center_dialog.dart';
import 'hasibu_release_notes_dialog.dart';
import 'hasibu_settings_view.dart';

/// Hasibu Kurumsal Oturum Açma (Login Gate) Ekranı.
/// Yönetici veya yetkili kullanıcı girişi aktif PDKS/İK modüllerini açar;
/// Personel girişi ise personele tanımlanan kişisel parola, kişisel tema (`themeMode`)
/// ve aktif yetki alanlarına (`allowedModules`) göre açılır.
/// Google hesabı bir kez bağlandığında bulut oturumu kalıcı kalır; sonraki açılışlarda
/// kullanıcı adı/parola ile oturum açılır.
class HasibuLoginScreen extends ConsumerStatefulWidget {
  const HasibuLoginScreen({super.key});

  @override
  ConsumerState<HasibuLoginScreen> createState() => _HasibuLoginScreenState();
}

class _HasibuLoginScreenState extends ConsumerState<HasibuLoginScreen> {
  UserRole _selectedRole = UserRole.admin;
  late final TextEditingController _usernameOrCardCtrl;
  late final TextEditingController _passwordOrPinCtrl;
  late final TextEditingController _googleEmailCtrl;
  late final TextEditingController _googleClientIdCtrl;
  late final TextEditingController _googleClientSecretCtrl;
  late final FocusNode _passwordFocusNode;
  bool _obscurePassword = true;
  bool _rememberUsername = true;
  bool _showGoogleConsoleConfig = false;
  bool _showGoogleAccountSwitcher = false;
  bool _isGoogleSigningIn = false;
  String? _infoMessage;

  @override
  void initState() {
    super.initState();
    _usernameOrCardCtrl = TextEditingController(
      text: kDebugMode ? 'admin' : '',
    );
    _passwordOrPinCtrl = TextEditingController(
      text: kDebugMode ? '123' : '',
    );
    _passwordFocusNode = FocusNode();
    final initialEmail =
        ref.read(pdksDashboardProvider).syncStatus.connectedGmail;
    _googleEmailCtrl = TextEditingController(text: initialEmail);
    _googleClientIdCtrl = TextEditingController();
    _googleClientSecretCtrl = TextEditingController();
    _loadSavedLoginPreferences();
    _loadSavedGoogleConsoleCredentials();
  }

  Future<void> _loadSavedLoginPreferences() async {
    final prefs = await ref.read(loginPreferencesServiceProvider).load();
    if (!mounted) return;
    setState(() {
      _rememberUsername = prefs.rememberUsername;
      if (!prefs.rememberUsername) {
        _usernameOrCardCtrl.clear();
        _passwordOrPinCtrl.clear();
      } else if (prefs.username.isNotEmpty) {
        _selectedRole = prefs.role;
        _usernameOrCardCtrl.text = prefs.username;
        if (!(kDebugMode &&
            prefs.role == UserRole.admin &&
            prefs.username.toLowerCase() == 'admin')) {
          _passwordOrPinCtrl.clear();
        }
      }
    });
  }

  Future<void> _loadSavedGoogleConsoleCredentials() async {
    final svc = ref.read(googleDriveSyncServiceProvider);
    final savedId = await svc.getSavedOAuthClientId();
    final savedSecret = await svc.getSavedOAuthClientSecret();
    if (!mounted) return;
    if (savedId.isNotEmpty) {
      _googleClientIdCtrl.text = savedId;
    }
    if (savedSecret.isNotEmpty) {
      _googleClientSecretCtrl.text = savedSecret;
    }
  }

  @override
  void dispose() {
    _usernameOrCardCtrl.dispose();
    _passwordOrPinCtrl.dispose();
    _googleEmailCtrl.dispose();
    _googleClientIdCtrl.dispose();
    _googleClientSecretCtrl.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  void _switchRole(UserRole role) {
    setState(() {
      _selectedRole = role;
      if (role == UserRole.admin) {
        _usernameOrCardCtrl.text = kDebugMode ? 'admin' : '';
        _passwordOrPinCtrl.text = kDebugMode ? '123' : '';
      } else {
        _usernameOrCardCtrl.text = kDebugMode ? '00064' : '';
        _passwordOrPinCtrl.text = kDebugMode ? '1234' : '';
      }
    });
  }

  void _selectKnownUser(String username) {
    setState(() {
      _selectedRole = UserRole.admin;
      _usernameOrCardCtrl.text = username;
      _passwordOrPinCtrl.clear();
    });
    _passwordFocusNode.requestFocus();
  }

  void _submitLogin() {
    final notifier = ref.read(pdksDashboardProvider.notifier);
    final bool ok;
    if (_selectedRole == UserRole.admin) {
      ok = notifier.loginAsAdmin(
        username: _usernameOrCardCtrl.text,
        password: _passwordOrPinCtrl.text,
      );
    } else {
      ok = notifier.loginAsEmployee(
        cardNo: _usernameOrCardCtrl.text,
        pin: _passwordOrPinCtrl.text,
      );
    }
    if (ok) {
      unawaited(
        ref.read(loginPreferencesServiceProvider).save(
              rememberUsername: _rememberUsername,
              username: _usernameOrCardCtrl.text,
              role: _selectedRole,
            ),
      );
    }
  }

  Future<void> _signInWithGoogleEmail() async {
    setState(() {
      _isGoogleSigningIn = true;
      _infoMessage = null;
    });
    try {
      final res = await ref
          .read(pdksDashboardProvider.notifier)
          .signInWithGoogleViaBrowser(
            emailHint: _googleEmailCtrl.text.trim(),
            customClientId: _googleClientIdCtrl.text.trim(),
            customClientSecret: _googleClientSecretCtrl.text.trim(),
            authenticateAppSession: true,
          );
      if (mounted && res.success && res.requiresUserLogin) {
        setState(() {
          _selectedRole = UserRole.admin;
          _showGoogleAccountSwitcher = false;
          _infoMessage = res.message;
          if (res.suggestedUsername != null &&
              res.suggestedUsername!.isNotEmpty) {
            _usernameOrCardCtrl.text = res.suggestedUsername!;
            _passwordOrPinCtrl.clear();
          }
        });
        if (res.suggestedUsername != null && res.suggestedUsername!.isNotEmpty) {
          _passwordFocusNode.requestFocus();
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isGoogleSigningIn = false);
      }
    }
  }

  Future<void> _pullCloudUsersFromLogin() async {
    setState(() => _infoMessage = null);
    final res = await ref
        .read(pdksDashboardProvider.notifier)
        .restoreFromCloudNow(mode: CloudRestoreMode.merge, cloudOnly: true);
    if (!mounted) return;
    setState(() {
      _infoMessage = res.summary != null
          ? '✓ Bulut verisi güncellendi: ${res.summary!.toTurkishSummary()}'
          : res.status.message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final companySettings = ref.watch(
      pdksDashboardProvider.select((s) => s.companySettings),
    );
    final errorMsg = ref.watch(
      pdksDashboardProvider.select((s) => s.authSession.errorMessage),
    );
    final appUsers = ref.watch(
      pdksDashboardProvider.select((s) => s.appUsers),
    );
    final syncStatus = ref.watch(
      pdksDashboardProvider.select((s) => s.syncStatus),
    );
    final isGoogleCloudConnected = ref.watch(
      pdksDashboardProvider.select((s) => s.isGoogleCloudConnected),
    );
    final isCloudBusy = ref.watch(
      pdksDashboardProvider.select((s) => s.isCloudBusy),
    );
    final isNativeGoogleAuth = ref.watch(
      googleAuthAdapterProvider.select((a) => a.isNativePlatform),
    );
    final activeAppUsers =
        appUsers.where((u) => u.isActive).toList(growable: false);
    final pal = HasibuPalette.of(context);
    final isCompact = MediaQuery.sizeOf(context).width < 480;

    return Scaffold(
      backgroundColor: pal.bg,
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isCompact ? 14 : 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Container(
              padding: EdgeInsets.all(isCompact ? 18 : 28),
              decoration: BoxDecoration(
                color: pal.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: pal.border),
                boxShadow: [
                  BoxShadow(
                    color:
                        Colors.black.withValues(alpha: pal.isDark ? 0.28 : 0.05),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      TextButton.icon(
                        key: const ValueKey('login_company_logo_button'),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                        ),
                        onPressed: () => showCompanyLogoDialog(context, ref),
                        icon: const Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 16,
                        ),
                        label: const Text(
                          'Şirket Logosu Ekle',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const UserThemeSelectorBar(compact: true),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: CompanyLogoBadge(
                      key: const ValueKey('login_company_logo_badge'),
                      settings: companySettings,
                      size: 64,
                      borderRadius: 16,
                      onTap: () => showCompanyLogoDialog(context, ref),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    companySettings.companyName,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: pal.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Yüz Okutma (PDKS) • Devam/Devamsızlık • İzin & Personel',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: pal.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SegmentedButton<UserRole>(
                    showSelectedIcon: false,
                    style: SegmentedButton.styleFrom(
                      visualDensity: isCompact
                          ? VisualDensity.compact
                          : VisualDensity.standard,
                      padding: EdgeInsets.symmetric(
                        horizontal: isCompact ? 8 : 12,
                      ),
                    ),
                    segments: const [
                      ButtonSegment<UserRole>(
                        value: UserRole.admin,
                        icon: Icon(Icons.shield_outlined, size: 18),
                        label: Text(
                          'Kullanıcı / Yönetici',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      ButtonSegment<UserRole>(
                        value: UserRole.employee,
                        icon: Icon(Icons.badge_outlined, size: 18),
                        label: Text(
                          'Personel Girişi',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    selected: {_selectedRole},
                    onSelectionChanged: (sel) => _switchRole(sel.first),
                  ),
                  if (_selectedRole == UserRole.admin &&
                      activeAppUsers.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      'Kayıtlı Kullanıcılar',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: pal.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        ActionChip(
                          key: ValueKey(
                            'login_user_chip_${companySettings.adminUsername}',
                          ),
                          visualDensity: VisualDensity.compact,
                          avatar: const Icon(Icons.verified_user_rounded, size: 15),
                          label: Text(companySettings.adminUsername),
                          onPressed: () =>
                              _selectKnownUser(companySettings.adminUsername),
                        ),
                        for (final u in activeAppUsers)
                          ActionChip(
                            key: ValueKey('login_user_chip_${u.username}'),
                            visualDensity: VisualDensity.compact,
                            avatar: const Icon(Icons.person_outline_rounded, size: 15),
                            label: Text(u.username),
                            onPressed: () => _selectKnownUser(u.username),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 18),
                  TextField(
                    key: const ValueKey('login_username_field'),
                    controller: _usernameOrCardCtrl,
                    onSubmitted: (_) => _submitLogin(),
                    decoration: InputDecoration(
                      labelText: _selectedRole == UserRole.admin
                          ? 'Kullanıcı Adı'
                          : 'Personel Kart / Sicil No',
                      hintText: _selectedRole == UserRole.admin
                          ? 'admin'
                          : 'Örn. 00001',
                      prefixIcon: Icon(
                        _selectedRole == UserRole.admin
                            ? Icons.person_outline_rounded
                            : Icons.credit_card_rounded,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const ValueKey('login_password_field'),
                    controller: _passwordOrPinCtrl,
                    focusNode: _passwordFocusNode,
                    obscureText: _obscurePassword,
                    onSubmitted: (_) => _submitLogin(),
                    decoration: InputDecoration(
                      labelText: _selectedRole == UserRole.admin
                          ? 'Parola'
                          : 'Kişisel Personel Parolası',
                      prefixIcon: const Icon(
                        Icons.lock_outline_rounded,
                        size: 20,
                      ),
                      suffixIcon: IconButton(
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                  Material(
                    type: MaterialType.transparency,
                    child: CheckboxListTile(
                      key: const ValueKey('login_remember_username_checkbox'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _rememberUsername,
                      onChanged: (val) {
                        final next = val ?? false;
                        setState(() => _rememberUsername = next);
                        unawaited(
                          ref.read(loginPreferencesServiceProvider).save(
                                rememberUsername: next,
                                username: _usernameOrCardCtrl.text,
                                role: _selectedRole,
                              ),
                        );
                      },
                      title: Text(
                        'Kullanıcı adını hatırla',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: pal.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  if (_infoMessage != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFF0284C7).withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        _infoMessage!,
                        style: const TextStyle(
                          color: Color(0xFF0284C7),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  if (syncStatus.isDecryptionKeyMismatch) ...[
                    const SizedBox(height: 8),
                    Container(
                      key: const ValueKey('login_cloud_unlock_banner'),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.45),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            syncStatus.message,
                            style: TextStyle(
                              color: pal.textPrimary,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          FilledButton.tonalIcon(
                            key: const ValueKey('login_btn_unlock_cloud_backup'),
                            onPressed: isCloudBusy
                                ? null
                                : () => showCloudRestoreDialog(context, ref),
                            icon: const Icon(Icons.vpn_key_rounded, size: 16),
                            label: const Text(
                              'Şifreleme Parolası / Anahtar ile Aç',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (errorMsg != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color:
                              const Color(0xFFDC2626).withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        errorMsg,
                        style: const TextStyle(
                          color: Color(0xFFDC2626),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    key: const ValueKey('login_submit_button'),
                    style: FilledButton.styleFrom(
                      backgroundColor: pal.isDark
                          ? const Color(0xFF0284C7)
                          : const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _submitLogin,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                    label: const Text(
                      'Oturum Aç',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Divider(color: pal.border),
                      Container(
                        color: pal.card,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          isGoogleCloudConnected
                              ? 'Google Bulut Bağlantısı'
                              : 'veya Google ile Giriş',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: pal.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (isGoogleCloudConnected && !_showGoogleAccountSwitcher) ...[
                    const SizedBox(height: 10),
                    Container(
                      key: const ValueKey('login_google_connected_banner'),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF10B981).withValues(alpha: 0.40),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.cloud_done_rounded,
                                size: 18,
                                color: Color(0xFF10B981),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Google Bulut Oturumu Açık',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w800,
                                        color: pal.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      syncStatus.connectedGmail,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: pal.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              OutlinedButton.icon(
                                key: const ValueKey(
                                  'login_btn_pull_cloud_users',
                                ),
                                style: OutlinedButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: isCloudBusy
                                    ? null
                                    : _pullCloudUsersFromLogin,
                                icon: const Icon(
                                  Icons.cloud_download_outlined,
                                  size: 15,
                                ),
                                label: const Text('Buluttan Çek'),
                              ),
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: () => setState(
                                  () => _showGoogleAccountSwitcher = true,
                                ),
                                icon: const Icon(
                                  Icons.swap_horiz_rounded,
                                  size: 15,
                                ),
                                label: const Text('Hesap Değiştir'),
                              ),
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  foregroundColor: const Color(0xFFDC2626),
                                ),
                                onPressed: () async {
                                  await ref
                                      .read(pdksDashboardProvider.notifier)
                                      .disconnectGmailSyncAccount();
                                  if (mounted) {
                                    setState(() {
                                      _showGoogleAccountSwitcher = false;
                                      _infoMessage = null;
                                    });
                                  }
                                },
                                icon: const Icon(
                                  Icons.link_off_rounded,
                                  size: 15,
                                ),
                                label: const Text('Bağlantıyı Kes'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    if (!isNativeGoogleAuth) ...[
                      const SizedBox(height: 12),
                      TextField(
                        key: const ValueKey('login_google_email_field'),
                        controller: _googleEmailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        onSubmitted: (_) => _signInWithGoogleEmail(),
                        decoration: InputDecoration(
                          isDense: true,
                          labelText: 'Google E-Posta Adresi (Gmail)',
                          hintText: 'ornek@gmail.com',
                          prefixIcon: const Icon(
                            Icons.mail_outline_rounded,
                            size: 18,
                          ),
                          suffixIcon: IconButton(
                            tooltip: 'Google Cloud Console OAuth 2.0 Ayarları',
                            onPressed: () => setState(
                              () => _showGoogleConsoleConfig =
                                  !_showGoogleConsoleConfig,
                            ),
                            icon: Icon(
                              _showGoogleConsoleConfig
                                  ? Icons.expand_less_rounded
                                  : Icons.tune_rounded,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (!isNativeGoogleAuth && _showGoogleConsoleConfig) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: pal.subtle,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: pal.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Google Cloud Console (ihasibu) OAuth 2.0 PKCE Bilgileri',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: pal.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Redirect URI: http://127.0.0.1:43821/oauth2callback',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: pal.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              key: const ValueKey(
                                'login_google_client_id_field',
                              ),
                              controller: _googleClientIdCtrl,
                              decoration: const InputDecoration(
                                isDense: true,
                                labelText:
                                    'OAuth 2.0 Client ID (.apps.googleusercontent.com)',
                                prefixIcon: Icon(Icons.key_rounded, size: 16),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              key: const ValueKey(
                                'login_google_client_secret_field',
                              ),
                              controller: _googleClientSecretCtrl,
                              obscureText: true,
                              decoration: const InputDecoration(
                                isDense: true,
                                labelText:
                                    'OAuth 2.0 Client Secret (Masaüstü İstemcisi)',
                                prefixIcon:
                                    Icon(Icons.vpn_key_outlined, size: 16),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      key: const ValueKey('login_google_signin_button'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(
                          color:
                              const Color(0xFF0284C7).withValues(alpha: 0.55),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed:
                          _isGoogleSigningIn ? null : _signInWithGoogleEmail,
                      icon: _isGoogleSigningIn
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(
                              Icons.account_circle_outlined,
                              size: 18,
                              color: Color(0xFF0284C7),
                            ),
                      label: Text(
                        _isGoogleSigningIn
                            ? (isNativeGoogleAuth
                                ? 'Google Oturumu Bekleniyor...'
                                : 'Tarayıcıda Google Oturumu Bekleniyor...')
                            : (isNativeGoogleAuth
                                ? 'Google ile Oturum Aç'
                                : 'Google Hesabı ile Oturum Aç (Tarayıcı)'),
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (_showGoogleAccountSwitcher && isGoogleCloudConnected)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => setState(
                            () => _showGoogleAccountSwitcher = false,
                          ),
                          child: const Text('Vazgeç'),
                        ),
                      ),
                    const SizedBox(height: 6),
                    Text(
                      'Google ile 1 kez bağlandığınızda bulut eşitlemesi açık kalır; sonraki açılışlarda yalnız kullanıcı adı ve parolanızla giriş yaparsınız.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: pal.textMuted,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    _selectedRole == UserRole.admin
                        ? 'Yönetici veya yetkili kullanıcı adınız ile giriş yapın (İlk kurulum: admin / 123)'
                        : (kDebugMode
                            ? 'Örnek Personel: Kart No 00064 / Parola: 1234'
                            : 'Personel kart numaranız ve kişisel parolanız ile giriş yapın'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: pal.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    key: const ValueKey('login_release_notes_button'),
                    onPressed: () => showHasibuReleaseNotesDialog(context),
                    icon: const Icon(Icons.new_releases_outlined, size: 16),
                    label: const Text(
                      'Sürüm Notları • v$hasibuAppVersion',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
