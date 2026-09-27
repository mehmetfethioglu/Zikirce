import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/session/session_manager_service.dart';
import '../../../../core/session/session_providers.dart';
import '../../../../core/session/user_session.dart';
import '../../../../core/services/google_oauth_sheet.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/widgets/session_avatar_widget.dart';
import '../../../dashboard/presentation/widgets/account_switcher_sheet.dart';
import '../../../dashboard/presentation/widgets/session_pin_dialog.dart';

class SessionManagementScreen extends ConsumerStatefulWidget {
  const SessionManagementScreen({super.key});

  @override
  ConsumerState<SessionManagementScreen> createState() => _SessionManagementScreenState();
}

class _SessionManagementScreenState extends ConsumerState<SessionManagementScreen> {
  final List<String> _avatarPresets = [
    'assets/images/avatar_male_1.png',
    'assets/images/avatar_male_2.png',
    'assets/images/avatar_male_3.png',
    'assets/images/avatar_female_1.png',
    'assets/images/avatar_female_2.png',
    'assets/images/avatar_female_3.png',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sessionProvider.notifier).syncCloudProfiles();
    });
  }

  Widget _buildAvatar(String path, {double size = 52}) {
    return SessionAvatarWidget(avatarPath: path, size: size);
  }

  Future<void> _showEditProfileDialog(UserSession session) async {
    final colors = context.colors;
    final nameController = TextEditingController(text: session.displayName);
    String selectedAvatar = session.avatar;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          return AlertDialog(
            backgroundColor: colors.cardBackground,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              children: [
                Icon(Icons.edit_note_rounded, color: colors.accent, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Profili Düzenle',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: colors.primaryText,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Active Avatar Preview
                  Center(
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: colors.accent, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: colors.accent.withValues(alpha: 0.25),
                                blurRadius: 12,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: _buildAvatar(selectedAvatar, size: 80),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: colors.accent,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.photo_camera_rounded, size: 16, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Button to Pick Image from Device Gallery
                  SizedBox(
                    width: double.infinity,
                    height: 42,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.accent,
                        side: BorderSide(color: colors.accent, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.photo_library_rounded, size: 18),
                      label: const Text('Galeriden Fotoğraf Seç', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      onPressed: () async {
                        try {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.image,
                          );
                          if (result != null && result.files.single.path != null) {
                            final sourceFile = File(result.files.single.path!);
                            final docDir = await getApplicationDocumentsDirectory();
                            final ext = p.extension(sourceFile.path);
                            final targetPath = p.join(
                              docDir.path,
                              'profile_${session.id}_${DateTime.now().millisecondsSinceEpoch}$ext',
                            );
                            await sourceFile.copy(targetPath);
                            HapticService.lightImpact();
                            setDlgState(() => selectedAvatar = targetPath);
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Fotoğraf seçme hatası: $e')),
                            );
                          }
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text(
                    'Veya Hazır Avatar Seçin',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: colors.secondaryTextAlt,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _avatarPresets.map((av) {
                      final isSelected = av == selectedAvatar;
                      return GestureDetector(
                        onTap: () {
                          HapticService.lightImpact();
                          setDlgState(() => selectedAvatar = av);
                        },
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? colors.accent : colors.borderStroke,
                              width: isSelected ? 2.5 : 1,
                            ),
                          ),
                          child: ClipOval(
                            child: Image.asset(av, fit: BoxFit.cover, cacheWidth: 120, cacheHeight: 120),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),

                  Text(
                    'Görünen Profil Adı',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.secondaryTextAlt,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      hintText: 'Profil Adı',
                      filled: true,
                      fillColor: colors.primaryText.withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: colors.borderStroke),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dlgCtx).pop(false),
                child: Text('İptal', style: TextStyle(color: colors.secondaryTextAlt)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  if (nameController.text.trim().isEmpty) return;
                  Navigator.of(dlgCtx).pop(true);
                },
                child: const Text('Kaydet'),
              ),
            ],
          );
        },
      ),
    );

    if (saved == true && nameController.text.trim().isNotEmpty) {
      final updated = session.copyWith(
        displayName: nameController.text.trim(),
        avatar: selectedAvatar,
      );
      await ref.read(sessionProvider.notifier).updateSession(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil bilgileri ve fotoğrafı güncellendi.')),
        );
      }
    }
  }

  Future<void> _handlePinAction(UserSession session) async {
    if (session.hasPin) {
      // PIN değiştir veya kaldır seçeneği
      final action = await showModalBottomSheet<String>(
        context: context,
        useRootNavigator: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) {
          final colors = context.colors;
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colors.bottomSheetBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SafeArea(
              top: false,
              bottom: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'PIN Güvenliği Yönetimi',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: colors.primaryText,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: Icon(Icons.pin_rounded, color: colors.accent),
                    title: const Text('PIN Kodunu Değiştir'),
                    onTap: () => Navigator.of(ctx).pop('change'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.lock_open_rounded, color: Colors.redAccent),
                    title: const Text('PIN Korumasını Kaldır', style: TextStyle(color: Colors.redAccent)),
                    onTap: () => Navigator.of(ctx).pop('remove'),
                  ),
                ],
              ),
            ),
          );
        },
      );

      if (action == 'remove') {
        if (!mounted) return;
        // Mevcut PIN'i doğrula
        final verified = await SessionPinDialog.showVerify(
          context,
          title: 'PIN Kaldırma Onayı',
          subtitle: 'Korumayı kaldırmak için mevcut PIN kodunuzu girin',
          onVerify: (pin) => SessionManagerService.verifyPin(session, pin),
        );
        if (verified) {
          await ref.read(sessionProvider.notifier).removePin(session.id);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('PIN koruması kaldırıldı.')),
            );
          }
        }
      } else if (action == 'change') {
        if (!mounted) return;
        // Önce mevcut PIN'i doğrula
        final verified = await SessionPinDialog.showVerify(
          context,
          title: 'Mevcut PIN Doğrulama',
          onVerify: (pin) => SessionManagerService.verifyPin(session, pin),
        );
        if (verified) {
          if (!mounted) return;
          final newPin = await SessionPinDialog.showCreate(
            context,
            title: 'Yeni PIN Kodu Belirle',
          );
          if (newPin != null) {
            await ref.read(sessionProvider.notifier).setPin(session.id, newPin);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('PIN kodu başarıyla değiştirildi.')),
              );
            }
          }
        }
      }
    } else {
      // Yeni PIN belirle
      final newPin = await SessionPinDialog.showCreate(
        context,
        title: '${session.displayName} için PIN Belirle',
      );
      if (newPin != null) {
        await ref.read(sessionProvider.notifier).setPin(session.id, newPin);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PIN koruması aktif edildi.')),
          );
        }
      }
    }
  }

  Future<void> _handleGoogleAction(UserSession session) async {
    if (session.isCloud) {
      final action = await showModalBottomSheet<String>(
        context: context,
        useRootNavigator: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) {
          final colors = context.colors;
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colors.bottomSheetBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SafeArea(
              top: false,
              bottom: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Google Bulut Hesabı',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: colors.primaryText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    session.email ?? '',
                    style: TextStyle(fontSize: 13, color: colors.secondaryTextAlt),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: const Icon(Icons.sync_rounded, color: Colors.blueAccent),
                    title: const Text('Bulut Yedeğinden Bilgileri Yenile'),
                    subtitle: const Text('Buluttaki kullanıcı adı ve profil resmini günceller', style: TextStyle(fontSize: 12)),
                    onTap: () => Navigator.of(ctx).pop('sync'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.cloud_off_rounded, color: Colors.redAccent),
                    title: const Text('Google Bağlantısını Kes', style: TextStyle(color: Colors.redAccent)),
                    onTap: () => Navigator.of(ctx).pop('disconnect'),
                  ),
                ],
              ),
            ),
          );
        },
      );

      if (action == 'sync') {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bulut yedeğindeki profil bilgileri eşitleniyor...'),
            duration: Duration(seconds: 1),
          ),
        );
        await ref.read(sessionProvider.notifier).syncCloudProfileForSession(session.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bulut profili güncellendi.')),
          );
        }
      } else if (action == 'disconnect') {
        if (!mounted) return;
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Google Bağlantısını Kes'),
            content: Text('${session.email} hesabının bu profille olan bulut bağlantısı kesilsin mi? (Yerel verileriniz korunacaktır)'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Vazgeç'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Bağlantıyı Kes'),
              ),
            ],
          ),
        );

        if (confirm == true) {
          final updated = session.copyWith(isCloud: false, clearEmail: true);
          await ref.read(sessionProvider.notifier).updateSession(updated);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Google bulut hesabı bağlantısı kesildi.')),
            );
          }
        }
      }
    } else {
      // Google hesabı bağla
      final success = await GoogleOAuthSheet.startOAuth(context, sessionId: session.id);
      if (success) {
        final sp = await SharedPreferences.getInstance();
        final isDefault = session.id == UserSession.defaultSessionId;
        final email = sp.getString('GoogleDrive_UserEmail_${session.id}') ??
            (isDefault ? sp.getString('GoogleDrive_UserEmail') : null);
        if (email != null && email.isNotEmpty) {
          final updated = session.copyWith(isCloud: true, email: email);
          await ref.read(sessionProvider.notifier).updateSession(updated);

          // Bulut yedeğindeki profil bilgilerini anında çek ve senkronize et
          await ref.read(sessionProvider.notifier).syncCloudProfileForSession(session.id);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$email hesabı bu profile başarıyla bağlandı.')),
            );
          }
        }
      }
    }
  }

  Future<void> _handleDeleteSession(UserSession session) async {
    final allSessions = ref.read(sessionListProvider);
    if (allSessions.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Son kalan ana oturum silinemez.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('${session.displayName} Profilini Sil'),
        content: const Text('Bu oturumu ve cihaza ait tüm yerel verilerini kalıcı olarak silmek istediğinizden emin misiniz? Bu işlem geri alınamaz.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Kalıcı Olarak Sil'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await ref.read(sessionProvider.notifier).deleteSession(session.id);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${session.displayName} profili silindi.')),
          );
        }
      }
    }
  }

  Future<void> _handleSwitch(UserSession session) async {
    final active = ref.read(activeSessionProvider);
    if (session.id == active.id) return;

    if (session.hasPin && session.pinHash != null) {
      final verified = await SessionPinDialog.showVerify(
        context,
        title: '${session.displayName} Profilini Aç',
        onVerify: (pin) {
          return SessionManagerService.verifyPin(session, pin);
        },
      );
      if (!verified) return;
    }

    final success = await ref.read(sessionProvider.notifier).switchSession(
      session.id,
      bypassPinCheck: true,
    );

    if (mounted) {
      if (success) {
        HapticService.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${session.displayName} profiline geçildi.'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Oturum değiştirilemedi.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sessionState = ref.watch(sessionProvider);
    final activeSession = sessionState.activeSession;
    final allSessions = sessionState.sessions;

    return Scaffold(
      backgroundColor: colors.pageBackground,
      appBar: AppBar(
        backgroundColor: colors.cardBackground,
        elevation: 0,
        title: Text(
          'Oturum ve Hesap Yönetimi',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: colors.primaryText,
          ),
        ),
        iconTheme: IconThemeData(color: colors.primaryText),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync_rounded),
            tooltip: 'Bulut Profillerini Eşitle',
            onPressed: () async {
              HapticService.lightImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Bulut profilleri güncelleniyor...'),
                  duration: Duration(seconds: 1),
                ),
              );
              await ref.read(sessionProvider.notifier).syncCloudProfiles(forceNetwork: true);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Bulut profilleri başarıyla eşitlendi.')),
                );
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          // Info banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colors.accent.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: colors.accent, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Zikirce üzerinde birden fazla yerel veya Google bulut oturumu açabilirsiniz. Her oturumun verileri tamamen izole tutulur.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: colors.primaryText,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Text(
            'KAYITLI PROFİLLER (${allSessions.length})',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: colors.secondaryTextAlt,
            ),
          ),
          const SizedBox(height: 12),

          // Profile Cards
          ...allSessions.map((session) {
            final isActive = session.id == activeSession.id;

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: colors.cardBackground,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isActive ? colors.accent : colors.borderStroke,
                  width: isActive ? 2 : 1,
                ),
              ),
              child: Column(
                children: [
                  // Main Info Row (Clickable to switch when inactive)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                      onTap: isActive ? null : () => _handleSwitch(session),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isActive ? colors.accent : colors.borderStroke,
                                  width: 2,
                                ),
                              ),
                              child: ClipOval(
                                child: _buildAvatar(session.avatar, size: 52),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          session.displayName,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: colors.primaryText,
                                          ),
                                        ),
                                      ),
                                      if (isActive) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: colors.accent,
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: const Text(
                                            'Aktif',
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ] else ...[
                                        const SizedBox(width: 8),
                                        GestureDetector(
                                          onTap: () => _handleSwitch(session),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: colors.accent.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(color: colors.accent.withValues(alpha: 0.4)),
                                            ),
                                            child: Text(
                                              'Geçiş Yap',
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.bold,
                                                color: colors.accent,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                              const SizedBox(height: 4),
                              if (session.isCloud && session.email != null)
                                Row(
                                  children: [
                                    const Icon(Icons.cloud_done_rounded, size: 14, color: Colors.blueAccent),
                                    const SizedBox(width: 4),
                                    Text(
                                      session.email!,
                                      style: TextStyle(fontSize: 12, color: colors.secondaryTextAlt),
                                    ),
                                  ],
                                )
                              else
                                Text(
                                  'Yerel Profil',
                                  style: TextStyle(fontSize: 12, color: colors.secondaryTextAlt),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Divider(height: 1, color: colors.borderStroke.withValues(alpha: 0.5)),

                  // Action Buttons Row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        // Edit
                        TextButton.icon(
                          onPressed: () => _showEditProfileDialog(session),
                          icon: Icon(Icons.edit_outlined, size: 16, color: colors.primaryText),
                          label: Text('Düzenle', style: TextStyle(fontSize: 12, color: colors.primaryText)),
                        ),
                        // PIN
                        TextButton.icon(
                          onPressed: () => _handlePinAction(session),
                          icon: Icon(
                            session.hasPin ? Icons.lock_rounded : Icons.lock_open_rounded,
                            size: 16,
                            color: session.hasPin ? colors.accent : colors.secondaryTextAlt,
                          ),
                          label: Text(
                            session.hasPin ? 'PIN Değiştir' : 'PIN Ekle',
                            style: TextStyle(
                              fontSize: 12,
                              color: session.hasPin ? colors.accent : colors.secondaryTextAlt,
                            ),
                          ),
                        ),
                        // Google
                        TextButton.icon(
                          onPressed: () => _handleGoogleAction(session),
                          icon: Icon(
                            session.isCloud ? Icons.cloud_off_rounded : Icons.cloud_upload_outlined,
                            size: 16,
                            color: session.isCloud ? Colors.blueAccent : colors.secondaryTextAlt,
                          ),
                          label: Text(
                            session.isCloud ? 'Bulut' : 'Bulut Bağla',
                            style: TextStyle(
                              fontSize: 12,
                              color: session.isCloud ? Colors.blueAccent : colors.secondaryTextAlt,
                            ),
                          ),
                        ),
                        // Delete (if not single)
                        if (allSessions.length > 1)
                          IconButton(
                            onPressed: () => _handleDeleteSession(session),
                            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                            tooltip: 'Profili Sil',
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 20),

          // Add New Profile Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () => AccountSwitcherSheet.show(context),
              icon: const Icon(Icons.person_add_rounded, size: 20),
              label: const Text(
                'Yeni Oturum / Profil Ekle',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
