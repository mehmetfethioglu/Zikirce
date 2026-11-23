import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/release/hasibu_release_notes.dart';
import '../../domain/pdks_models.dart';
import '../providers/pdks_providers.dart';
import 'hasibu_release_notes_dialog.dart';
import 'hasibu_settings_view.dart';
import 'login_cloud_session_widgets.dart';
import 'login_security_dialogs.dart';

/// Hasibu Kurumsal Oturum Açma (Login Gate) Ekranı.
/// - Tek birleşik Kullanıcı Adı / Kart No + Parola formu sunar; yönetici, yetkili
///   kullanıcı veya personel hesabı otomatik algılanır.
/// - Kayıtlı kullanıcı isimleri güvenlik nedeniyle gizlenir; yalnızca "Kullanıcı adını hatırla"
///   işaretliyse son oturum açılan kullanıcı adı otomatik doldurulur.
/// - Üst bölümde Hasibu marka logosu, sağında minimalist Bulut Oturumu ikonu ve Tema seçici yer alır.
/// - Merkezde Ayarlar'dan gelen işletmenin kendi logosu ve işletme adı görüntülenir.
/// - İlk kurulum admin bilgisi güncellenene kadar gösterilir; ilk girişte zorunlu parola güncellemesi ister.
class HasibuLoginScreen extends ConsumerStatefulWidget {
  const HasibuLoginScreen({super.key});

  @override
  ConsumerState<HasibuLoginScreen> createState() => _HasibuLoginScreenState();
}

class _HasibuLoginScreenState extends ConsumerState<HasibuLoginScreen> {
  late final TextEditingController _usernameOrCardCtrl;
  late final TextEditingController _passwordOrPinCtrl;
  late final FocusNode _passwordFocusNode;
  bool _obscurePassword = true;
  bool _rememberUsername = true;
  String? _infoMessage;

  @override
  void initState() {
    super.initState();
    _usernameOrCardCtrl = TextEditingController();
    _passwordOrPinCtrl = TextEditingController();
    _passwordFocusNode = FocusNode();
    _loadSavedLoginPreferences();
  }

  Future<void> _loadSavedLoginPreferences() async {
    final prefs = await ref.read(loginPreferencesServiceProvider).load();
    if (!mounted) return;
    setState(() {
      _rememberUsername = prefs.rememberUsername;
      if (_usernameOrCardCtrl.text.trim().isEmpty &&
          prefs.rememberUsername &&
          prefs.username.isNotEmpty) {
        _usernameOrCardCtrl.text = prefs.username;
        _passwordOrPinCtrl.clear();
      }
    });
  }

  @override
  void dispose() {
    _usernameOrCardCtrl.dispose();
    _passwordOrPinCtrl.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  void _fillInitialAdminCredentials(String adminUsername) {
    setState(() {
      _usernameOrCardCtrl.text = adminUsername;
      _passwordOrPinCtrl.text = CompanySettings.defaultAdminPassword;
    });
    _passwordFocusNode.requestFocus();
  }

  Future<void> _submitLogin() async {
    final notifier = ref.read(pdksDashboardProvider.notifier);
    final result = notifier.attemptUnifiedLogin(
      identifier: _usernameOrCardCtrl.text,
      password: _passwordOrPinCtrl.text,
    );

    bool authenticated = false;
    UserRole resolvedRole = result.resolvedRole ?? UserRole.admin;
    String resolvedUser = result.resolvedUsername.isNotEmpty
        ? result.resolvedUsername
        : _usernameOrCardCtrl.text.trim();

    if (result.outcome == AdminLoginOutcome.requiresInitialPasswordUpdate) {
      if (!mounted) return;
      authenticated = await showForceAdminPasswordUpdateDialog(
        context,
        username: resolvedUser,
        currentPassword: _passwordOrPinCtrl.text,
      );
      resolvedRole = UserRole.admin;
    } else {
      authenticated = result.outcome == AdminLoginOutcome.authenticated;
    }

    if (authenticated) {
      unawaited(
        ref.read(loginPreferencesServiceProvider).save(
              rememberUsername: _rememberUsername,
              username: resolvedUser,
              role: resolvedRole,
            ),
      );
    }
  }

  void _toggleRememberUsername(bool next) {
    final cleanUser = _usernameOrCardCtrl.text.trim();
    setState(() => _rememberUsername = next);
    unawaited(
      ref.read(loginPreferencesServiceProvider).save(
            rememberUsername: next,
            username: cleanUser,
            role: UserRole.admin,
          ),
    );
  }

  Future<void> _openForgotPassword() async {
    final recoveredUsername = await showForgotPasswordDialog(
      context,
      initialIdentifier: _usernameOrCardCtrl.text.trim(),
    );
    if (!mounted ||
        recoveredUsername == null ||
        recoveredUsername.isEmpty) {
      return;
    }
    setState(() {
      _usernameOrCardCtrl.text = recoveredUsername;
      _passwordOrPinCtrl.clear();
      _infoMessage =
          '✓ Parolanız güncellendi. Yeni parolanız ile oturum açabilirsiniz.';
    });
    _passwordFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final companySettings = ref.watch(
      pdksDashboardProvider.select((s) => s.companySettings),
    );
    final errorMsg = ref.watch(
      pdksDashboardProvider.select((s) => s.authSession.errorMessage),
    );
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        key: const ValueKey('login_hasibu_brand'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.asset(
                              'assets/icon/hasibu_icon.png',
                              width: 24,
                              height: 24,
                              fit: BoxFit.cover,
                              filterQuality: FilterQuality.high,
                              isAntiAlias: true,
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.auto_awesome_rounded,
                                size: 20,
                                color: pal.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            'Hasibu',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: pal.textPrimary,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          LoginCloudSessionIconButton(
                            onSessionUpdated: (outcome) {
                              if (!mounted) return;
                              setState(() {
                                if (outcome.infoMessage != null) {
                                  _infoMessage = outcome.infoMessage;
                                }
                                final suggested =
                                    outcome.suggestedUsername?.trim() ?? '';
                                if (suggested.isNotEmpty) {
                                  _usernameOrCardCtrl.text = suggested;
                                  _passwordOrPinCtrl.clear();
                                }
                              });
                              if ((outcome.suggestedUsername ?? '')
                                  .trim()
                                  .isNotEmpty) {
                                _passwordFocusNode.requestFocus();
                              }
                            },
                          ),
                          const SizedBox(width: 6),
                          const UserThemeSelectorBar(compact: true),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: CompanyLogoBadge(
                      key: const ValueKey('login_company_logo_badge'),
                      settings: companySettings,
                      size: 70,
                      borderRadius: 16,
                      preferCompanyMonogramWhenDefault: true,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    companySettings.displayCompanyNameForLogin,
                    key: const ValueKey('login_company_name_text'),
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
                  if (companySettings.requiresInitialAdminPasswordChange) ...[
                    const SizedBox(height: 16),
                    LoginInitialSetupCard(
                      adminUsername: companySettings.adminUsername,
                      onFillCredentials: () => _fillInitialAdminCredentials(
                        companySettings.adminUsername,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  TextField(
                    key: const ValueKey('login_username_field'),
                    controller: _usernameOrCardCtrl,
                    onSubmitted: (_) => _submitLogin(),
                    decoration: const InputDecoration(
                      labelText: 'Kullanıcı Adı / Kart No',
                      hintText: 'Kullanıcı adı veya personel kart no',
                      prefixIcon: Icon(
                        Icons.person_outline_rounded,
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
                      labelText: 'Parola',
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
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () =>
                              _toggleRememberUsername(!_rememberUsername),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: Checkbox(
                                    key: const ValueKey(
                                      'login_remember_username_checkbox',
                                    ),
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    value: _rememberUsername,
                                    onChanged: (val) =>
                                        _toggleRememberUsername(val ?? false),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'Kullanıcı adını hatırla',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: pal.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      TextButton(
                        key: const ValueKey('login_forgot_password_button'),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                        ),
                        onPressed: _openForgotPassword,
                        child: const Text(
                          'Şifremi unuttum?',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
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
                  const SizedBox(height: 16),
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
                  const SizedBox(height: 12),
                  Text(
                    'Kullanıcı adınız veya personel kart numaranız ile giriş yapın; yetkileriniz otomatik yüklenir.',
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
