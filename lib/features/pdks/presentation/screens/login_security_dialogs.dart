import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/password_recovery_service.dart';
import '../../domain/pdks_models.dart';
import '../providers/pdks_providers.dart';
import 'hasibu_settings_view.dart';

/// Yalnız ilk kurulumda (varsayılan yönetici parolası henüz güncellenmediğinde)
/// gösterilen bilgilendirme kartı. Parola güncellendikten sonra otomatik gizlenir.
class LoginInitialSetupCard extends StatelessWidget {
  final String adminUsername;
  final VoidCallback onFillCredentials;

  const LoginInitialSetupCard({
    super.key,
    required this.adminUsername,
    required this.onFillCredentials,
  });

  @override
  Widget build(BuildContext context) {
    final pal = HasibuPalette.of(context);
    final accent =
        pal.isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7);

    return Container(
      key: const ValueKey('login_first_setup_info_card'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: pal.isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.admin_panel_settings_outlined,
                size: 18,
                color: accent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'İlk Kurulum Yönetici Erişimi',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: pal.textPrimary,
                  ),
                ),
              ),
              TextButton(
                key: const ValueKey('login_fill_initial_admin_button'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                ),
                onPressed: onFillCredentials,
                child: const Text(
                  'Doldur',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _CredentialPill(label: 'Kullanıcı', value: adminUsername),
              const _CredentialPill(
                label: 'Geçici Parola',
                value: CompanySettings.defaultAdminPassword,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'İlk yönetici girişinde yeni parola belirlemeniz zorunludur; güncellendikten sonra bu bilgi bir daha gösterilmez.',
            style: TextStyle(
              fontSize: 11,
              height: 1.35,
              color: pal.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _CredentialPill extends StatelessWidget {
  final String label;
  final String value;

  const _CredentialPill({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final pal = HasibuPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: pal.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: pal.border),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: pal.textPrimary,
        ),
      ),
    );
  }
}

/// İlk kurulumdaki varsayılan yönetici bilgileriyle girişte kapatılamayan
/// zorunlu parola güncelleme penceresini açar.
Future<bool> showForceAdminPasswordUpdateDialog(
  BuildContext context, {
  required String username,
  required String currentPassword,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => ForceAdminPasswordUpdateDialog(
      username: username,
      currentPassword: currentPassword,
    ),
  );
  return result ?? false;
}

class ForceAdminPasswordUpdateDialog extends ConsumerStatefulWidget {
  final String username;
  final String currentPassword;

  const ForceAdminPasswordUpdateDialog({
    super.key,
    required this.username,
    required this.currentPassword,
  });

  @override
  ConsumerState<ForceAdminPasswordUpdateDialog> createState() =>
      _ForceAdminPasswordUpdateDialogState();
}

class _ForceAdminPasswordUpdateDialogState
    extends ConsumerState<ForceAdminPasswordUpdateDialog> {
  late final TextEditingController _newPassCtrl;
  late final TextEditingController _confirmPassCtrl;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isSaving = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _newPassCtrl = TextEditingController();
    _confirmPassCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitUpdate() async {
    final next = _newPassCtrl.text.trim();
    final confirm = _confirmPassCtrl.text.trim();

    if (next.length < 6) {
      setState(
        () => _errorText = 'Yeni yönetici parolası en az 6 karakter olmalıdır.',
      );
      return;
    }
    if (next == CompanySettings.defaultAdminPassword) {
      setState(
        () => _errorText =
            'Güvenliğiniz için varsayılan geçici parola (123) kullanılamaz.',
      );
      return;
    }
    if (next.toLowerCase() == widget.username.trim().toLowerCase()) {
      setState(
        () => _errorText = 'Yeni parola yönetici kullanıcı adı ile aynı olamaz.',
      );
      return;
    }
    if (next != confirm) {
      setState(() => _errorText = 'Girilen parolalar birbiriyle eşleşmiyor.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    try {
      final err = await ref
          .read(pdksDashboardProvider.notifier)
          .completeInitialAdminPasswordUpdateAndLogin(
            username: widget.username,
            currentPassword: widget.currentPassword,
            newPassword: next,
          );
      if (!mounted) return;
      if (err != null) {
        setState(() {
          _errorText = err;
          _isSaving = false;
        });
        return;
      }
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorText = 'Parola güncellenemedi: $e';
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = HasibuPalette.of(context);
    return PopScope(
      canPop: false,
      child: AlertDialog(
        key: const ValueKey('force_admin_password_dialog'),
        title: const Row(
          children: [
            Icon(Icons.security_update_good_rounded, color: Color(0xFF0284C7)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'İlk Kurulum Parola Güncellemesi',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'İlk kez yönetici (${widget.username}) olarak giriş yapıyorsunuz. '
                  'Güvenliğiniz için devam etmeden önce yeni bir yönetici parolası belirlemelisiniz.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: pal.textSecondary,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  key: const ValueKey('force_admin_new_password_field'),
                  controller: _newPassCtrl,
                  obscureText: _obscureNew,
                  onSubmitted: (_) => _submitUpdate(),
                  decoration: InputDecoration(
                    labelText: 'Yeni Yönetici Parolası',
                    helperText:
                        'En az 6 karakter, "123" ve kullanıcı adından farklı',
                    prefixIcon: const Icon(Icons.lock_reset_rounded, size: 20),
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _obscureNew = !_obscureNew),
                      icon: Icon(
                        _obscureNew
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('force_admin_confirm_password_field'),
                  controller: _confirmPassCtrl,
                  obscureText: _obscureConfirm,
                  onSubmitted: (_) => _submitUpdate(),
                  decoration: InputDecoration(
                    labelText: 'Yeni Parola (Tekrar)',
                    prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 18,
                      ),
                    ),
                  ),
                ),
                if (_errorText != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFFDC2626).withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      _errorText!,
                      style: const TextStyle(
                        color: Color(0xFFDC2626),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
            child: const Text('İptal'),
          ),
          FilledButton.icon(
            key: const ValueKey('force_admin_password_submit_button'),
            onPressed: _isSaving ? null : _submitUpdate,
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.verified_user_rounded, size: 18),
            label: const Text('Parolayı Güncelle ve Giriş Yap'),
          ),
        ],
      ),
    );
  }
}

/// Şifremi Unuttum penceresini açar ve parola sıfırlanırsa kullanıcı adını/kart no'yu döndürür.
Future<String?> showForgotPasswordDialog(
  BuildContext context, {
  required String initialIdentifier,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => ForgotPasswordDialog(
      initialIdentifier: initialIdentifier,
    ),
  );
}

class ForgotPasswordDialog extends ConsumerStatefulWidget {
  final String initialIdentifier;

  const ForgotPasswordDialog({
    super.key,
    required this.initialIdentifier,
  });

  @override
  ConsumerState<ForgotPasswordDialog> createState() =>
      _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends ConsumerState<ForgotPasswordDialog> {
  late final TextEditingController _identifierCtrl;
  late final TextEditingController _codeCtrl;
  late final TextEditingController _newPassCtrl;
  late final TextEditingController _confirmPassCtrl;

  int _step = 1;
  bool _isGoogleIdentityMode = false;
  bool _isBusy = false;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _showGoogleFallbackHint = false;
  String _maskedEmail = '';
  String? _infoText;
  String? _errorText;
  UserRole _resolvedRole = UserRole.admin;

  @override
  void initState() {
    super.initState();
    _identifierCtrl = TextEditingController(text: widget.initialIdentifier);
    _codeCtrl = TextEditingController();
    _newPassCtrl = TextEditingController();
    _confirmPassCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _identifierCtrl.dispose();
    _codeCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendVerificationCode() async {
    setState(() {
      _isBusy = true;
      _errorText = null;
      _infoText = null;
      _showGoogleFallbackHint = false;
    });
    try {
      final notifier = ref.read(pdksDashboardProvider.notifier);
      final lookup = notifier.lookupRecoverableAccount(
        identifier: _identifierCtrl.text,
      );
      if (lookup.resolvedRole != null) {
        _resolvedRole = lookup.resolvedRole!;
      }
      final outcome = await notifier.sendPasswordResetCodeToCompanyGmail(
        identifier: _identifierCtrl.text,
      );
      if (!mounted) return;
      if (outcome.success) {
        setState(() {
          _step = 2;
          _isGoogleIdentityMode = false;
          _maskedEmail = outcome.maskedEmail;
          _infoText = outcome.message;
        });
      } else {
        setState(() {
          _maskedEmail = outcome.maskedEmail;
          _errorText = outcome.message;
          _showGoogleFallbackHint = outcome.canUseGoogleIdentityFallback;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorText = 'Doğrulama kodu gönderilemedi: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _verifyWithGoogleOAuth() async {
    setState(() {
      _isBusy = true;
      _errorText = null;
      _infoText = null;
    });
    try {
      final notifier = ref.read(pdksDashboardProvider.notifier);
      final lookup = notifier.lookupRecoverableAccount(
        identifier: _identifierCtrl.text,
      );
      if (lookup.resolvedRole != null) {
        _resolvedRole = lookup.resolvedRole!;
      }
      final outcome = await notifier.verifyCompanyGmailOwnershipViaGoogleOAuth(
        identifier: _identifierCtrl.text,
      );
      if (!mounted) return;
      if (outcome.success) {
        setState(() {
          _step = 2;
          _isGoogleIdentityMode = true;
          _maskedEmail = outcome.maskedEmail;
          _infoText = outcome.message;
        });
      } else {
        setState(() => _errorText = outcome.message);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorText = 'Google hesap doğrulaması başarısız: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _submitReset() async {
    final nextPass = _newPassCtrl.text.trim();
    final confirmPass = _confirmPassCtrl.text.trim();
    if (!_isGoogleIdentityMode && _codeCtrl.text.trim().isEmpty) {
      setState(
        () => _errorText = 'Lütfen Gmail hesabınıza gelen 6 haneli kodu girin.',
      );
      return;
    }
    if (nextPass != confirmPass) {
      setState(() => _errorText = 'Girilen parolalar birbiriyle eşleşmiyor.');
      return;
    }

    setState(() {
      _isBusy = true;
      _errorText = null;
    });
    try {
      final err = await ref
          .read(pdksDashboardProvider.notifier)
          .completePasswordReset(
            identifier: _identifierCtrl.text,
            verificationCode: _isGoogleIdentityMode ? null : _codeCtrl.text,
            newPassword: nextPass,
          );
      if (!mounted) return;
      if (err != null) {
        setState(() {
          _errorText = err;
          _isBusy = false;
        });
        return;
      }
      Navigator.of(context).pop(_identifierCtrl.text.trim());
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorText = 'Parola sıfırlanamadı: $e';
          _isBusy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = HasibuPalette.of(context);
    final companyGmail = ref.watch(
      pdksDashboardProvider.select((s) => s.companySettings.syncGmailAccount),
    );
    final hasGmail =
        companyGmail.trim().isNotEmpty && companyGmail.contains('@');
    final maskedCompanyGmail = PasswordRecoveryService.maskEmail(companyGmail);

    return AlertDialog(
      key: const ValueKey('forgot_password_dialog'),
      title: const Row(
        children: [
          Icon(Icons.lock_reset_rounded, color: Color(0xFF0284C7)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Şifremi Unuttum',
              style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_step == 1) ...[
                TextField(
                  key: const ValueKey('forgot_username_field'),
                  controller: _identifierCtrl,
                  onSubmitted: (_) => _sendVerificationCode(),
                  decoration: const InputDecoration(
                    labelText: 'Kullanıcı Adı / Kart No',
                    hintText: 'Örn. admin, mehmet_akar veya 00064',
                    prefixIcon: Icon(
                      Icons.person_outline_rounded,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: pal.subtle,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: pal.border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        hasGmail
                            ? Icons.mark_email_read_outlined
                            : Icons.mail_lock_outlined,
                        size: 18,
                        color: hasGmail
                            ? const Color(0xFF0284C7)
                            : const Color(0xFFD97706),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          hasGmail
                              ? 'Tek kullanımlık 6 haneli doğrulama kodu şirketin kayıtlı Gmail hesabına ($maskedCompanyGmail) gönderilecektir.'
                              : 'Şirket Gmail hesabı henüz bağlı değil. Önce sağ üstteki bulut simgesinden veya Ayarlar bölümünden şirketin Gmail hesabını bağlayın.',
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.35,
                            color: pal.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  key: const ValueKey('forgot_send_code_button'),
                  onPressed: (_isBusy || !hasGmail) ? null : _sendVerificationCode,
                  icon: _isBusy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded, size: 17),
                  label: const Text('Doğrulama Kodu Gönder'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  key: const ValueKey('forgot_verify_google_button'),
                  onPressed: (_isBusy || !hasGmail) ? null : _verifyWithGoogleOAuth,
                  icon: const Icon(Icons.verified_user_outlined, size: 17),
                  label: const Text('Google Hesabı ile Doğrula'),
                ),
                if (_showGoogleFallbackHint) ...[
                  const SizedBox(height: 6),
                  Text(
                    'İpucu: E-posta gönderimi mümkün değilse yukarıdaki "Google Hesabı ile Doğrula" seçeneği ile şirket Gmail sahipliğini doğrulayıp parolanızı hemen yenileyebilirsiniz.',
                    style: TextStyle(
                      fontSize: 11,
                      color: pal.textMuted,
                    ),
                  ),
                ],
              ] else ...[
                if (_isGoogleIdentityMode)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF10B981).withValues(alpha: 0.40),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.verified_rounded,
                          size: 18,
                          color: Color(0xFF10B981),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Google hesap sahipliği doğrulandı ($_maskedEmail).',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: pal.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  TextField(
                    key: const ValueKey('forgot_otp_code_field'),
                    controller: _codeCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: InputDecoration(
                      labelText: '6 Haneli Doğrulama Kodu',
                      hintText: '123456',
                      counterText: '',
                      prefixIcon: const Icon(Icons.pin_outlined, size: 18),
                      suffixIcon: TextButton(
                        key: const ValueKey('forgot_resend_code_button'),
                        onPressed: _isBusy ? null : _sendVerificationCode,
                        child: const Text(
                          'Tekrar Gönder',
                          style: TextStyle(fontSize: 11.5),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('forgot_new_password_field'),
                  controller: _newPassCtrl,
                  obscureText: _obscureNew,
                  decoration: InputDecoration(
                    labelText: 'Yeni Parola',
                    helperText: _resolvedRole == UserRole.admin
                        ? 'En az 6 karakter'
                        : 'En az 4 karakter',
                    prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _obscureNew = !_obscureNew),
                      icon: Icon(
                        _obscureNew
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('forgot_confirm_password_field'),
                  controller: _confirmPassCtrl,
                  obscureText: _obscureConfirm,
                  onSubmitted: (_) => _submitReset(),
                  decoration: InputDecoration(
                    labelText: 'Yeni Parola (Tekrar)',
                    prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ],
              if (_infoText != null) ...[
                const SizedBox(height: 10),
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
                    _infoText!,
                    style: const TextStyle(
                      color: Color(0xFF0284C7),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              if (_errorText != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFDC2626).withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    _errorText!,
                    style: const TextStyle(
                      color: Color(0xFFDC2626),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (_step == 2)
          TextButton(
            onPressed: _isBusy
                ? null
                : () => setState(() {
                      _step = 1;
                      _errorText = null;
                    }),
            child: const Text('Geri'),
          ),
        TextButton(
          onPressed: _isBusy ? null : () => Navigator.of(context).pop(),
          child: const Text('İptal'),
        ),
        if (_step == 2)
          FilledButton.icon(
            key: const ValueKey('forgot_reset_submit_button'),
            onPressed: _isBusy ? null : _submitReset,
            icon: _isBusy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_rounded, size: 17),
            label: const Text('Parolayı Güncelle'),
          ),
      ],
    );
  }
}
