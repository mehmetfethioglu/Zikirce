import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/drift.dart' hide Column;
import '../../../../core/database/app_database.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/providers/database_provider.dart';
import '../../../../core/services/google_oauth_sheet.dart';
import '../../../../core/services/google_drive_backup_service.dart';
import '../../../../core/session/session_providers.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../gamification/providers/gamification_providers.dart';
import '../../../../core/services/changelog_service.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  final bool isFromSettings;

  const OnboardingScreen({super.key, this.isFromSettings = false});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _totalPages = 5;

  // Profile setup in Step 5
  late TextEditingController _nameController;
  int _dailyZikirTarget = 100;
  int _dailyQuranTarget = 2;
  bool _isGoogleConnected = false;
  String? _googleUserEmail;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: 'Zâkir');
    _checkGoogleStatus();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  bool _isProcessingBackup = false;

  Future<void> _checkGoogleStatus() async {
    final service = ref.read(googleDriveBackupServiceProvider);
    final isSigned = await service.isSignedIn();
    final email = await service.getUserEmail();
    if (mounted) {
      setState(() {
        _isGoogleConnected = isSigned;
        _googleUserEmail = email;
      });
    }
  }

  Future<void> _handleGoogleSignIn() async {
    HapticFeedback.selectionClick();
    if (_isGoogleConnected) {
      await _restoreFromCloud();
      return;
    }

    final activeSession = ref.read(activeSessionProvider);
    final success = await GoogleOAuthSheet.startOAuth(context, sessionId: activeSession.id);
    if (success) {
      await _checkGoogleStatus();
      final prefs = await SharedPreferences.getInstance();
      final googleEmail = prefs.getString('GoogleDrive_UserEmail') ?? prefs.getString('GoogleDrive_UserEmail_${activeSession.id}');

      if (googleEmail != null && googleEmail.isNotEmpty) {
        final updatedSession = activeSession.copyWith(
          isCloud: true,
          email: googleEmail,
        );
        ref.read(sessionProvider.notifier).updateSession(updatedSession);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.translate('Settings_GoogleDriveConnected')),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        // Automatically ask to restore from cloud
        await _restoreFromCloud();
      }
    }
  }

  Future<void> _restoreFromCloud() async {
    final service = ref.read(googleDriveBackupServiceProvider);
    setState(() => _isProcessingBackup = true);

    try {
      final backups = await service.listCloudBackups();
      setState(() => _isProcessingBackup = false);

      if (!mounted) return;

      if (backups.isEmpty) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Text(context.l10n.translate('Settings_RestoreFromCloud'), style: const TextStyle(fontWeight: FontWeight.bold)),
            content: Text(context.l10n.isTurkish
                ? 'Google Drive bulutundaki varsayılan yedek dosyası indirilip geri yüklenecektir.'
                : 'The default backup file on Google Drive cloud will be downloaded and restored.'),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(context.l10n.translate('Common_Cancel'))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF236B56),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(context.l10n.translate('Settings_RestoreFromCloud')),
              ),
            ],
          ),
        );

        if (confirm != true) return;
        setState(() => _isProcessingBackup = true);
        final count = await service.restoreFromCloud();
        await _onRestoreSuccess(count, 'Varsayılan Yedek');
        return;
      }

      final selectedBackup = await showModalBottomSheet<CloudBackupInfo>(
        context: context,
        useRootNavigator: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (ctx) {
          final colors = context.colors;
          final l10n = context.l10n;
          return Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
            padding: const EdgeInsets.all(20),
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
                Row(
                  children: [
                    const Text('☁️', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 8),
                    Text(
                      l10n.translate('Settings_SelectCloudBackup'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colors.primaryText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.translate('Settings_SelectCloudBackupDesc'),
                  style: TextStyle(fontSize: 12, color: colors.secondaryTextAlt),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: backups.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, index) {
                      final item = backups[index];
                      final dateStr = '${item.modifiedTime.day.toString().padLeft(2, '0')}.${item.modifiedTime.month.toString().padLeft(2, '0')}.${item.modifiedTime.year} ${item.modifiedTime.hour.toString().padLeft(2, '0')}:${item.modifiedTime.minute.toString().padLeft(2, '0')}';
                      return InkWell(
                        onTap: () => Navigator.of(ctx).pop(item),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: colors.cardBackground,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: index == 0 ? colors.accent : colors.borderStroke,
                              width: index == 0 ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: index == 0
                                      ? colors.accent.withValues(alpha: 0.15)
                                      : colors.pageBackground,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(item.isLocal ? '💾' : (index == 0 ? '⭐' : '☁️'), style: const TextStyle(fontSize: 18)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          item.displayName,
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.bold,
                                            color: colors.primaryText,
                                          ),
                                        ),
                                        if (index == 0) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF10B981),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(context.l10n.translate('Settings_Newest'), style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '📅 $dateStr • 📱 ${item.deviceName}',
                                      style: TextStyle(fontSize: 11, color: colors.secondaryTextAlt),
                                    ),
                                    if (item.streakCount != null || item.zikirCount != null) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        '🔥 Seri: ${item.streakCount ?? 0} • 📿 Zikir: ${item.zikirCount ?? 0}',
                                        style: TextStyle(fontSize: 11, color: colors.accent, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Icon(Icons.download_rounded, color: colors.accent, size: 22),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

      if (selectedBackup == null) return;

      setState(() => _isProcessingBackup = true);
      final count = await service.restoreFromCloud(
        fileId: selectedBackup.fileId,
        revisionId: selectedBackup.revisionId,
      );
      await _onRestoreSuccess(count, selectedBackup.displayName);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Geri yükleme hatası: $e')));
      }
    } finally {
      if (mounted) setState(() => _isProcessingBackup = false);
    }
  }

  Future<void> _onRestoreSuccess(int count, String backupName) async {
    final db = ref.read(databaseProvider);
    final profile = (await db.select(db.userProfiles).get()).firstOrNull;
    final prefs = await SharedPreferences.getInstance();
    final activeSession = ref.read(activeSessionProvider);
    final googleEmail = prefs.getString('GoogleDrive_UserEmail') ?? prefs.getString('GoogleDrive_UserEmail_${activeSession.id}') ?? activeSession.email;

    if (profile != null && mounted) {
      setState(() {
        _nameController.text = profile.userName;
        _dailyZikirTarget = profile.dailyZikirTarget;
      });

      final updatedSession = activeSession.copyWith(
        displayName: profile.userName,
        avatar: profile.avatar.isNotEmpty ? profile.avatar : activeSession.avatar,
        isCloud: googleEmail != null && googleEmail.isNotEmpty,
        email: googleEmail,
      );
      ref.read(sessionProvider.notifier).updateSession(updatedSession);
    }

    ref.read(badgeRefreshTriggerProvider.notifier).state++;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ $count zikir ve tüm verileriniz ($backupName) başarıyla geri yüklendi!'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    }
  }

  Future<void> _finishOnboarding() async {
    HapticFeedback.mediumImpact();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('IsOnboardingCompleted', true);
    await ChangelogService.markCurrentVersionAsSeen();

    // Save profile name & targets if edited
    final name = _nameController.text.trim();
    if (name.isNotEmpty) {
      final db = ref.read(databaseProvider);
      final profile = (await db.select(db.userProfiles).get()).firstOrNull;
      if (profile != null) {
        await (db.update(db.userProfiles)..where((t) => t.id.equals(profile.id))).write(
          UserProfilesCompanion(
            userName: Value(name),
            dailyZikirTarget: Value(_dailyZikirTarget),
          ),
        );
      }
      await prefs.setString('UserName', name);
      await prefs.setInt('DailyZikirTarget', _dailyZikirTarget);
      await prefs.setInt('DailyQuranTarget', _dailyQuranTarget);

      final activeSession = ref.read(activeSessionProvider);
      ref.read(sessionProvider.notifier).updateSession(activeSession.copyWith(displayName: name));
    }

    if (mounted) {
      if (widget.isFromSettings) {
        Navigator.of(context).pop();
      } else {
        context.go('/');
      }
    }
  }

  void _nextPage() {
    HapticFeedback.selectionClick();
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finishOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: colors.pageBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar (Skip & Indicator)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: colors.accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Zikirce 2.0',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: colors.accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_currentPage < _totalPages - 1)
                    TextButton(
                      onPressed: _finishOnboarding,
                      style: TextButton.styleFrom(
                        foregroundColor: colors.secondaryTextAlt,
                        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      child: Text(l10n.translate('Onboarding_Skip')),
                    )
                  else
                    const SizedBox(height: 36),
                ],
              ),
            ),

            // PageView Content
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                children: [
                  _buildSlide1(colors, l10n),
                  _buildSlide2(colors, l10n),
                  _buildSlide3(colors, l10n),
                  _buildSlide4(colors, l10n),
                  _buildSlide5(colors, l10n),
                ],
              ),
            ),

            // Bottom Navigation Bar with Dots & Next Button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Dots Indicator
                  Row(
                    children: List.generate(
                      _totalPages,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(right: 6),
                        height: 7,
                        width: _currentPage == index ? 24 : 7,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? colors.accent
                              : colors.borderStroke.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),

                  // Next / Start Button
                  ElevatedButton(
                    onPressed: _nextPage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 3,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _currentPage == _totalPages - 1
                              ? l10n.translate('Onboarding_StartBtn')
                              : l10n.translate('Onboarding_NextBtn'),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          _currentPage == _totalPages - 1
                              ? Icons.check_circle_rounded
                              : Icons.arrow_forward_rounded,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Slide 1: Zikirmatik & Manevi Seriler (Streak)
  Widget _buildSlide1(AppThemeColors colors, AppLocalizations l10n) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Column(
        children: [
          Container(
            height: 180,
            width: double.infinity,
            alignment: Alignment.center,
            child: Lottie.asset(
              'assets/animations/zikirtamamlandi.json',
              repeat: true,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.translate('Onboarding_Slide1Title'),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: colors.primaryText,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.translate('Onboarding_WelcomeDesc'),
            style: TextStyle(fontSize: 13, color: colors.secondaryTextAlt, height: 1.4),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          _buildFeatureCard(
            icon: '📿',
            title: l10n.translate('Onboarding_Slide1Item1Title'),
            desc: l10n.translate('Onboarding_Slide1Item1Desc'),
            colors: colors,
          ),
          const SizedBox(height: 10),
          _buildFeatureCard(
            icon: '🔥',
            title: l10n.translate('Onboarding_Slide1Item2Title'),
            desc: l10n.translate('Onboarding_Slide1Item2Desc'),
            colors: colors,
          ),
          const SizedBox(height: 10),
          _buildFeatureCard(
            icon: '📊',
            title: l10n.translate('Onboarding_Slide1Item3Title'),
            desc: l10n.translate('Onboarding_Slide1Item3Desc'),
            colors: colors,
          ),
        ],
      ),
    );
  }

  // Slide 2: Kur'an-ı Kerim ve Hatim
  Widget _buildSlide2(AppThemeColors colors, AppLocalizations l10n) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Column(
        children: [
          Container(
            height: 180,
            width: double.infinity,
            alignment: Alignment.center,
            child: Lottie.asset(
              'assets/animations/progress.json',
              repeat: true,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.translate('Onboarding_Slide2Title'),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: colors.primaryText,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.isTurkish
                ? 'Diyanet mühürlü Mushaf sayfaları, gelişmiş hatim yönetimi ve ayet takipli tilavet.'
                : 'Quran pages with authentic mushaf layout, advanced hatim management, and synchronized audio.',
            style: TextStyle(fontSize: 13, color: colors.secondaryTextAlt, height: 1.4),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          _buildFeatureCard(
            icon: '📖',
            title: l10n.translate('Onboarding_Slide2Item1Title'),
            desc: l10n.translate('Onboarding_Slide2Item1Desc'),
            colors: colors,
          ),
          const SizedBox(height: 10),
          _buildFeatureCard(
            icon: '🤝',
            title: l10n.translate('Onboarding_Slide2Item2Title'),
            desc: l10n.translate('Onboarding_Slide2Item2Desc'),
            colors: colors,
          ),
          const SizedBox(height: 10),
          _buildFeatureCard(
            icon: '🎙️',
            title: l10n.translate('Onboarding_Slide2Item3Title'),
            desc: l10n.translate('Onboarding_Slide2Item3Desc'),
            colors: colors,
          ),
        ],
      ),
    );
  }

  // Slide 3: İnteraktif Ezber, Talim ve Fıkıh
  Widget _buildSlide3(AppThemeColors colors, AppLocalizations l10n) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Column(
        children: [
          Container(
            height: 170,
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildModeBadge('🧩', 'Kelime\nBulmaca', const Color(0xFF10B981)),
                const SizedBox(width: 12),
                _buildModeBadge('✍️', 'Boşluk\nDoldurma', const Color(0xFF3B82F6)),
                const SizedBox(width: 12),
                _buildModeBadge('🔗', 'Sonraki\nAyet', const Color(0xFF8B5CF6)),
                const SizedBox(width: 12),
                _buildModeBadge('🎙️', 'Tilavet\nTalimi', const Color(0xFFF59E0B)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.translate('Onboarding_Slide3Title'),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: colors.primaryText,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.isTurkish
                ? 'Kur\'an ayetlerini oyunlaştırılmış modlarla kolayca ezberleyin, ilmihal ve fıkıh bilgilerine başvurun.'
                : 'Memorize Quran verses easily through interactive modes and explore fiqh references.',
            style: TextStyle(fontSize: 13, color: colors.secondaryTextAlt, height: 1.4),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          _buildFeatureCard(
            icon: '🧠',
            title: l10n.translate('Onboarding_Slide3Item1Title'),
            desc: l10n.translate('Onboarding_Slide3Item1Desc'),
            colors: colors,
          ),
          const SizedBox(height: 10),
          _buildFeatureCard(
            icon: '📚',
            title: l10n.translate('Onboarding_Slide3Item2Title'),
            desc: l10n.translate('Onboarding_Slide3Item2Desc'),
            colors: colors,
          ),
        ],
      ),
    );
  }

  // Slide 4: Namaz Vakitleri, Kaza ve 9 Widget
  Widget _buildSlide4(AppThemeColors colors, AppLocalizations l10n) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Column(
        children: [
          Container(
            height: 170,
            alignment: Alignment.center,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF065F46), Color(0xFF047857)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF059669).withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('🕋', style: TextStyle(fontSize: 42)),
                  SizedBox(width: 14),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hassas Vakitler & Kaza',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '9 Ana Ekran Widget Desteği 📱',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.translate('Onboarding_Slide4Title'),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: colors.primaryText,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.isTurkish
                ? 'Dünya genelinde namaz vakitleri, kaza namazı eritme havuzu ve kilit ekranı widget\'ları.'
                : 'Accurate prayer times worldwide, missed prayer tracking, and home screen widgets.',
            style: TextStyle(fontSize: 13, color: colors.secondaryTextAlt, height: 1.4),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          _buildFeatureCard(
            icon: '⏰',
            title: l10n.translate('Onboarding_Slide4Item1Title'),
            desc: l10n.translate('Onboarding_Slide4Item1Desc'),
            colors: colors,
          ),
          const SizedBox(height: 10),
          _buildFeatureCard(
            icon: '📱',
            title: l10n.translate('Onboarding_Slide4Item2Title'),
            desc: l10n.translate('Onboarding_Slide4Item2Desc'),
            colors: colors,
          ),
          const SizedBox(height: 10),
          _buildFeatureCard(
            icon: '⏳',
            title: l10n.isTurkish ? 'Kaza Eritme Havuzu' : 'Missed Prayers Pool',
            desc: l10n.isTurkish
                ? 'Kaza namazlarınızı düzenli olarak takip edin ve sıfırlayın.'
                : 'Track and complete your missed prayers regularly.',
            colors: colors,
          ),
        ],
      ),
    );
  }

  // Slide 5: Makam Kuşları, Hazine, Hedefler & Google Bulut Girişi
  Widget _buildSlide5(AppThemeColors colors, AppLocalizations l10n) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              height: 100,
              width: 100,
              alignment: Alignment.center,
              child: Lottie.asset(
                'assets/animations/yeni_bird.json',
                repeat: true,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.translate('Onboarding_Slide5Title'),
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
              color: colors.primaryText,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            l10n.translate('Onboarding_Slide5Desc'),
            style: TextStyle(fontSize: 12.5, color: colors.secondaryTextAlt),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // Google Cloud Backup Card (Requested by user)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _isGoogleConnected
                    ? [const Color(0xFF065F46), const Color(0xFF047857)]
                    : [const Color(0xFF1E293B), const Color(0xFF0F172A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _isGoogleConnected ? const Color(0xFF10B981) : colors.borderStroke,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('☁️', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Text(
                      l10n.translate('Onboarding_Slide5BackupTitle'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                      ),
                    ),
                    const Spacer(),
                    if (_isGoogleConnected)
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _isGoogleConnected
                      ? 'Bağlı Hesap: ${_googleUserEmail ?? 'Google Drive'}'
                      : l10n.translate('Onboarding_Slide5BackupDesc'),
                  style: const TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.3),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: ElevatedButton.icon(
                    onPressed: _isProcessingBackup ? null : _handleGoogleSignIn,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isGoogleConnected ? const Color(0xFF059669) : Colors.white,
                      foregroundColor: _isGoogleConnected ? Colors.white : Colors.black87,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 1,
                    ),
                    icon: _isProcessingBackup
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : (_isGoogleConnected
                            ? const Icon(Icons.cloud_download_rounded, size: 18)
                            : const Text('G', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF4285F4)))),
                    label: Text(
                      _isProcessingBackup
                          ? (l10n.isTurkish ? 'Yedekler Aranıyor...' : 'Searching Backups...')
                          : (_isGoogleConnected
                              ? (l10n.isTurkish ? 'Buluttaki Yedeği Geri Yükle 📥' : 'Restore Backup from Cloud 📥')
                              : l10n.translate('Onboarding_Slide5GoogleBtn')),
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // User Name Input
          Text(
            l10n.translate('Settings_ProfileName'),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors.primaryText),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _nameController,
            style: TextStyle(color: colors.primaryText, fontSize: 14),
            decoration: InputDecoration(
              filled: true,
              fillColor: colors.cardBackgroundAlt,
              hintText: l10n.translate('Onboarding_Slide5NamePlaceholder'),
              hintStyle: TextStyle(color: colors.secondaryTextAlt, fontSize: 13),
              prefixIcon: const Icon(Icons.person_rounded, size: 18),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: colors.borderStroke),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: colors.borderStroke),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Targets: Zikir & Quran
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.cardBackgroundAlt,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colors.borderStroke),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.translate('Onboarding_Slide5ZikirGoal'),
                        style: TextStyle(fontSize: 11, color: colors.secondaryTextAlt, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('$_dailyZikirTarget', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: colors.accent)),
                          Row(
                            children: [
                              _buildMiniStepBtn(Icons.remove, () {
                                if (_dailyZikirTarget > 33) {
                                  setState(() => _dailyZikirTarget -= 33);
                                }
                              }, colors),
                              const SizedBox(width: 4),
                              _buildMiniStepBtn(Icons.add, () {
                                setState(() => _dailyZikirTarget += 33);
                              }, colors),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.cardBackgroundAlt,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colors.borderStroke),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.translate('Onboarding_Slide5QuranGoal'),
                        style: TextStyle(fontSize: 11, color: colors.secondaryTextAlt, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('$_dailyQuranTarget sf', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: colors.accent)),
                          Row(
                            children: [
                              _buildMiniStepBtn(Icons.remove, () {
                                if (_dailyQuranTarget > 1) {
                                  setState(() => _dailyQuranTarget -= 1);
                                }
                              }, colors),
                              const SizedBox(width: 4),
                              _buildMiniStepBtn(Icons.add, () {
                                setState(() => _dailyQuranTarget += 1);
                              }, colors),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildMiniStepBtn(IconData icon, VoidCallback onTap, AppThemeColors colors) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: colors.cardBackground,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 14, color: colors.primaryText),
      ),
    );
  }

  Widget _buildModeBadge(String emoji, String title, Color color) {
    return Container(
      width: 72,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color, height: 1.1),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required String icon,
    required String title,
    required String desc,
    required AppThemeColors colors,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.cardBackgroundAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.borderStroke.withValues(alpha: 0.8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.cardBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(icon, style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: colors.primaryText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.secondaryTextAlt,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
