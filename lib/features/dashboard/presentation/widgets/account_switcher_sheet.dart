import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
import 'session_pin_dialog.dart';

class AccountSwitcherSheet extends ConsumerStatefulWidget {
  const AccountSwitcherSheet({super.key});

  static Future<void> show(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const AccountSwitcherSheet(),
    );
  }

  @override
  ConsumerState<AccountSwitcherSheet> createState() => _AccountSwitcherSheetState();
}

class _AccountSwitcherSheetState extends ConsumerState<AccountSwitcherSheet> {
  bool _isCreatingSession = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sessionProvider.notifier).syncCloudProfiles();
    });
  }

  Widget _buildAvatar(String path, {double size = 44}) {
    return SessionAvatarWidget(avatarPath: path, size: size);
  }

  Future<void> _handleSwitch(UserSession session) async {
    final active = ref.read(activeSessionProvider);
    if (session.id == active.id) {
      Navigator.of(context).pop();
      return;
    }

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
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${session.displayName} oturumuna geçildi.'),
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

  Future<void> _showCreateLocalDialog() async {
    final colors = context.colors;
    final nameController = TextEditingController();
    String selectedAvatar = 'assets/images/avatar_male_1.png';
    String? createdPin;

    final avatarPresets = [
      'assets/images/avatar_male_1.png',
      'assets/images/avatar_male_2.png',
      'assets/images/avatar_male_3.png',
      'assets/images/avatar_female_1.png',
      'assets/images/avatar_female_2.png',
      'assets/images/avatar_female_3.png',
    ];

    final created = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          return AlertDialog(
            backgroundColor: colors.cardBackground,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Text(
              'Yeni Yerel Oturum Oluştur',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: colors.primaryText,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Profil Adı',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.secondaryTextAlt,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Örn: Ahmet, Ayşe, Misafir...',
                      filled: true,
                      fillColor: colors.primaryText.withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: colors.borderStroke),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Avatar Picker Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Avatar Seçin',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colors.secondaryTextAlt,
                        ),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () async {
                          try {
                            final result = await FilePicker.platform.pickFiles(type: FileType.image);
                            if (result != null && result.files.single.path != null) {
                              final sourceFile = File(result.files.single.path!);
                              final docDir = await getApplicationDocumentsDirectory();
                              final ext = p.extension(sourceFile.path);
                              final targetPath = p.join(
                                docDir.path,
                                'profile_custom_${DateTime.now().millisecondsSinceEpoch}$ext',
                              );
                              await sourceFile.copy(targetPath);
                              HapticService.lightImpact();
                              setDlgState(() => selectedAvatar = targetPath);
                            }
                          } catch (_) {}
                        },
                        icon: Icon(Icons.photo_library_rounded, size: 15, color: colors.accent),
                        label: Text('Galeriden', style: TextStyle(fontSize: 12, color: colors.accent, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      if (!selectedAvatar.startsWith('assets/'))
                        GestureDetector(
                          onTap: () {},
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: colors.accent, width: 2.5),
                            ),
                            child: ClipOval(
                              child: _buildAvatar(selectedAvatar, size: 48),
                            ),
                          ),
                        ),
                      ...avatarPresets.map((av) {
                        final isSelected = av == selectedAvatar;
                        return GestureDetector(
                          onTap: () {
                            HapticService.lightImpact();
                            setDlgState(() => selectedAvatar = av);
                          },
                          child: Container(
                            width: 48,
                            height: 48,
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
                      }),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'PIN Koruması',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colors.primaryText,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () async {
                          final pin = await SessionPinDialog.showCreate(
                            context,
                            title: 'Profil PIN Belirle',
                          );
                          if (pin != null) {
                            setDlgState(() => createdPin = pin);
                          }
                        },
                        icon: Icon(
                          createdPin != null ? Icons.lock_rounded : Icons.lock_open_rounded,
                          size: 16,
                          color: createdPin != null ? colors.accent : colors.secondaryTextAlt,
                        ),
                        label: Text(
                          createdPin != null ? 'PIN Ayarlandı' : 'PIN Belirle',
                          style: TextStyle(
                            fontSize: 12,
                            color: createdPin != null ? colors.accent : colors.secondaryTextAlt,
                          ),
                        ),
                      ),
                    ],
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
                child: const Text('Oluştur'),
              ),
            ],
          );
        },
      ),
    );

    if (created == true && nameController.text.trim().isNotEmpty) {
      setState(() => _isCreatingSession = true);
      try {
        final newSession = await ref.read(sessionProvider.notifier).createLocalSession(
          name: nameController.text.trim(),
          avatar: selectedAvatar,
          pin: createdPin,
        );
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${newSession.displayName} oturumu oluşturuldu ve açıldı.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hata: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isCreatingSession = false);
      }
    }
  }

  Future<void> _showCreateCloudDialog() async {
    final tempSessionId = 'usr_${DateTime.now().millisecondsSinceEpoch}';
    final success = await GoogleOAuthSheet.startOAuth(context, sessionId: tempSessionId);

    if (success) {
      setState(() => _isCreatingSession = true);
      try {
        final sp = await SharedPreferences.getInstance();
        final email = sp.getString('GoogleDrive_UserEmail_$tempSessionId') ??
            sp.getString('GoogleDrive_UserEmail') ??
            'Google Kullanıcısı';
        final name = sp.getString('GoogleDrive_UserName_$tempSessionId') ??
            sp.getString('GoogleDrive_UserName') ??
            email.split('@').first;

        final avatar = sp.getString('UserProfileImage_$tempSessionId') ??
            sp.getString('avatar_$tempSessionId') ??
            'assets/images/avatar_male_1.png';

        final created = await ref.read(sessionProvider.notifier).createCloudSession(
          id: tempSessionId,
          name: name,
          avatar: avatar,
          email: email,
        );

        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${created.displayName} ($email) bulut oturumu açıldı.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hata: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isCreatingSession = false);
      }
    }
  }

  void _showAddSessionPicker() {
    final colors = context.colors;
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.borderStroke,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Yeni Oturum Türü Seçin',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colors.primaryText,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  tileColor: colors.primaryText.withValues(alpha: 0.04),
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: colors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.phone_android_rounded, color: colors.accent),
                  ),
                  title: Text(
                    'Yeni Yerel Oturum Aç',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: colors.primaryText,
                    ),
                  ),
                  subtitle: Text(
                    'Sadece bu cihazda saklanan bağımsız profil',
                    style: TextStyle(fontSize: 12, color: colors.secondaryTextAlt),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _showCreateLocalDialog();
                  },
                ),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  tileColor: colors.primaryText.withValues(alpha: 0.04),
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.cloud_sync_rounded, color: Colors.blueAccent),
                  ),
                  title: Text(
                    'Google ile Bulut Oturumu Aç',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: colors.primaryText,
                    ),
                  ),
                  subtitle: Text(
                    'Google Drive ile otomatik senkronize profil',
                    style: TextStyle(fontSize: 12, color: colors.secondaryTextAlt),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _showCreateCloudDialog();
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = colors.statusBrightness == Brightness.light;
    final sessionState = ref.watch(sessionProvider);
    final activeSession = sessionState.activeSession;
    final allSessions = sessionState.sessions;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: colors.bottomSheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.15),
            blurRadius: 30,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 44,
                height: 4.5,
                decoration: BoxDecoration(
                  color: colors.borderStroke,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header Title & Manage Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colors.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.people_alt_rounded, color: colors.accent, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Kullanıcı Oturumları',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colors.primaryText,
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.push('/sessions');
                  },
                  icon: Icon(Icons.settings_suggest_rounded, size: 16, color: colors.accent),
                  label: Text(
                    'Yönet',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.accent,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Sessions List
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: allSessions.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (ctx, index) {
                  final s = allSessions[index];
                  final isActive = s.id == activeSession.id;

                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _handleSwitch(s),
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isActive
                              ? colors.accent.withValues(alpha: 0.1)
                              : colors.cardBackground,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isActive ? colors.accent : colors.borderStroke,
                            width: isActive ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            // Avatar
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isActive ? colors.accent : colors.borderStroke,
                                  width: 2,
                                ),
                              ),
                              child: ClipOval(
                                child: _buildAvatar(s.avatar, size: 46),
                              ),
                            ),
                            const SizedBox(width: 14),

                            // Name & Email / Badges
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          s.displayName,
                                          style: TextStyle(
                                            fontSize: 15.5,
                                            fontWeight: FontWeight.bold,
                                            color: colors.primaryText,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (s.hasPin) ...[
                                        const SizedBox(width: 6),
                                        Icon(Icons.lock_rounded, size: 14, color: colors.secondaryTextAlt),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      if (s.isCloud && s.email != null) ...[
                                        const Icon(Icons.cloud_done_rounded, size: 13, color: Colors.blueAccent),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            s.email!,
                                            style: TextStyle(fontSize: 12, color: colors.secondaryTextAlt),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ] else ...[
                                        Icon(Icons.phone_android_rounded, size: 13, color: colors.secondaryTextAlt),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Yerel Cihaz Oturumu',
                                          style: TextStyle(fontSize: 12, color: colors.secondaryTextAlt),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Active Tag or Switch Icon
                            if (isActive)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: colors.accent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Aktif',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              )
                            else
                              Icon(
                                Icons.chevron_right_rounded,
                                color: colors.secondaryTextAlt,
                                size: 22,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // Add Account Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.accent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _isCreatingSession ? null : _showAddSessionPicker,
                icon: _isCreatingSession
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.add_circle_outline_rounded, size: 20),
                label: Text(
                  _isCreatingSession ? 'Oturum Hazırlanıyor...' : 'Yeni Oturum Ekle',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
