import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/google_drive_sync_service.dart';
import '../../domain/pdks_models.dart';
import '../providers/pdks_providers.dart';
import 'cloud_backup_center_dialog.dart';
import 'hasibu_settings_view.dart';

/// Bulut oturumu penceresinden giriş ekranına dönen yönlendirme bilgisi.
@immutable
class LoginCloudSessionDialogOutcome {
  final String? suggestedUsername;
  final String? infoMessage;

  const LoginCloudSessionDialogOutcome({
    this.suggestedUsername,
    this.infoMessage,
  });
}

/// Giriş ekranı üst çubuğunda tema seçicinin yanında yer alan minimalist Google Bulut ikonu.
class LoginCloudSessionIconButton extends ConsumerWidget {
  final void Function(LoginCloudSessionDialogOutcome outcome)? onSessionUpdated;

  const LoginCloudSessionIconButton({
    super.key,
    this.onSessionUpdated,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGoogleCloudConnected = ref.watch(
      pdksDashboardProvider.select((s) => s.isGoogleCloudConnected),
    );
    final isCloudBusy = ref.watch(
      pdksDashboardProvider.select((s) => s.isCloudBusy),
    );
    final syncStatus = ref.watch(
      pdksDashboardProvider.select((s) => s.syncStatus),
    );
    final pal = HasibuPalette.of(context);

    final bool hasMismatch = syncStatus.isDecryptionKeyMismatch;
    final Color statusColor;
    final IconData statusIcon;
    final String tooltipText;

    if (hasMismatch) {
      statusColor = const Color(0xFFD97706);
      statusIcon = Icons.cloud_sync_rounded;
      tooltipText =
          'Bulut Yedeği Kilitli — Anahtar Gerekli (${syncStatus.connectedGmail})';
    } else if (isGoogleCloudConnected) {
      statusColor = const Color(0xFF10B981);
      statusIcon = Icons.cloud_done_rounded;
      tooltipText = 'Google Bulut Oturumu Açık (${syncStatus.connectedGmail})';
    } else {
      statusColor = pal.textSecondary;
      statusIcon = Icons.cloud_off_outlined;
      tooltipText = 'Google Bulut Bağlantısı Yok — Bağlamak için tıklayın';
    }

    return Tooltip(
      message: tooltipText,
      child: InkWell(
        key: const ValueKey('login_cloud_session_button'),
        borderRadius: BorderRadius.circular(8),
        onTap: () async {
          final outcome = await showLoginCloudSessionDialog(context, ref);
          if (outcome != null) {
            onSessionUpdated?.call(outcome);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: hasMismatch
                ? const Color(0xFFF59E0B).withValues(alpha: 0.12)
                : (isGoogleCloudConnected
                    ? const Color(0xFF10B981).withValues(alpha: 0.12)
                    : pal.subtle),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: hasMismatch
                  ? const Color(0xFFF59E0B).withValues(alpha: 0.45)
                  : (isGoogleCloudConnected
                      ? const Color(0xFF10B981).withValues(alpha: 0.45)
                      : pal.border),
            ),
          ),
          child: isCloudBusy
              ? SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: statusColor,
                  ),
                )
              : Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(statusIcon, size: 16, color: statusColor),
                    if (isGoogleCloudConnected || hasMismatch)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Minimalist bulut ikonuna tıklandığında açılan Google Bulut Oturumu & Eşitleme penceresi.
Future<LoginCloudSessionDialogOutcome?> showLoginCloudSessionDialog(
  BuildContext context,
  WidgetRef ref,
) {
  return showDialog<LoginCloudSessionDialogOutcome>(
    context: context,
    builder: (_) => const LoginCloudSessionDialog(),
  );
}

class LoginCloudSessionDialog extends ConsumerStatefulWidget {
  const LoginCloudSessionDialog({super.key});

  @override
  ConsumerState<LoginCloudSessionDialog> createState() =>
      _LoginCloudSessionDialogState();
}

class _LoginCloudSessionDialogState
    extends ConsumerState<LoginCloudSessionDialog> {
  late final TextEditingController _googleEmailCtrl;
  late final TextEditingController _googleClientIdCtrl;
  late final TextEditingController _googleClientSecretCtrl;
  bool _showGoogleConsoleConfig = false;
  bool _showGoogleAccountSwitcher = false;
  bool _isGoogleSigningIn = false;
  String? _infoMessage;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final initialEmail =
        ref.read(pdksDashboardProvider).syncStatus.connectedGmail;
    _googleEmailCtrl = TextEditingController(text: initialEmail);
    _googleClientIdCtrl = TextEditingController();
    _googleClientSecretCtrl = TextEditingController();
    _loadSavedGoogleConsoleCredentials();
  }

  Future<void> _loadSavedGoogleConsoleCredentials() async {
    try {
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
    } catch (e) {
      debugPrint('LoginCloudSessionDialog: OAuth ayar okuma uyarısı: $e');
    }
  }

  @override
  void dispose() {
    _googleEmailCtrl.dispose();
    _googleClientIdCtrl.dispose();
    _googleClientSecretCtrl.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogleEmail() async {
    setState(() {
      _isGoogleSigningIn = true;
      _infoMessage = null;
      _errorMessage = null;
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
      if (!mounted) return;
      if (res.success && res.requiresUserLogin) {
        Navigator.of(context).pop(
          LoginCloudSessionDialogOutcome(
            suggestedUsername: res.suggestedUsername,
            infoMessage: res.message,
          ),
        );
        return;
      }
      setState(() {
        _showGoogleAccountSwitcher = false;
        if (res.success) {
          _infoMessage = res.message;
        } else {
          _errorMessage = res.message;
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Google oturumu açılamadı: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isGoogleSigningIn = false);
      }
    }
  }

  Future<void> _pullCloudUsers() async {
    setState(() {
      _infoMessage = null;
      _errorMessage = null;
    });
    try {
      final res = await ref
          .read(pdksDashboardProvider.notifier)
          .restoreFromCloudNow(mode: CloudRestoreMode.merge, cloudOnly: true);
      if (!mounted) return;
      setState(() {
        if (res.summary != null) {
          _infoMessage =
              '✓ Bulut verisi güncellendi: ${res.summary!.toTurkishSummary()}';
        } else if (res.status.stage == DriveSyncStage.error) {
          _errorMessage = res.status.message;
        } else {
          _infoMessage = res.status.message;
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Bulut verisi çekilemedi: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
    final pal = HasibuPalette.of(context);

    return AlertDialog(
      key: const ValueKey('login_cloud_session_dialog'),
      title: const Row(
        children: [
          Icon(Icons.cloud_outlined, color: Color(0xFF0284C7)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Google Bulut Bağlantısı',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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
              if (syncStatus.isDecryptionKeyMismatch) ...[
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
                        label: const Text('Şifreleme Parolası / Anahtar ile Aç'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
              if (isGoogleCloudConnected && !_showGoogleAccountSwitcher) ...[
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
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          OutlinedButton.icon(
                            key: const ValueKey('login_btn_pull_cloud_users'),
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: isCloudBusy ? null : _pullCloudUsers,
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
                              try {
                                await ref
                                    .read(pdksDashboardProvider.notifier)
                                    .disconnectGmailSyncAccount();
                                if (mounted) {
                                  setState(() {
                                    _showGoogleAccountSwitcher = false;
                                    _infoMessage =
                                        'Google Bulut bağlantısı kesildi.';
                                    _errorMessage = null;
                                  });
                                }
                              } catch (e) {
                                if (mounted) {
                                  setState(
                                    () => _errorMessage =
                                        'Bağlantı kesilirken hata: $e',
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.link_off_rounded, size: 15),
                            label: const Text('Bağlantıyı Kes'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ] else ...[
                if (!isNativeGoogleAuth) ...[
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
                          key: const ValueKey('login_google_client_id_field'),
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
                            prefixIcon: Icon(Icons.vpn_key_outlined, size: 16),
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
                      color: const Color(0xFF0284C7).withValues(alpha: 0.55),
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
                const SizedBox(height: 8),
                Text(
                  'Google ile 1 kez bağlandığınızda bulut eşitlemesi açık kalır; sonraki açılışlarda yalnız kullanıcı adı ve parolanızla giriş yaparsınız.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: pal.textMuted,
                  ),
                ),
              ],
              if (_infoMessage != null) ...[
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
                    _infoMessage!,
                    style: const TextStyle(
                      color: Color(0xFF0284C7),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              if (_errorMessage != null) ...[
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
                    _errorMessage!,
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
        TextButton(
          onPressed: () => Navigator.of(context).pop(
            _infoMessage == null
                ? null
                : LoginCloudSessionDialogOutcome(infoMessage: _infoMessage),
          ),
          child: const Text('Kapat'),
        ),
      ],
    );
  }
}
