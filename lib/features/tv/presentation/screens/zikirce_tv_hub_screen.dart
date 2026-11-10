import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/surah_data_provider.dart';
import '../../../../core/providers/tv_mode_provider.dart';
import '../../../../core/services/cloud_sync_engine.dart';
import '../../../../core/services/google_drive_backup_service.dart';
import '../../../../core/services/google_oauth_sheet.dart';
import '../../../../core/session/session_providers.dart';
import '../../../../core/session/user_session.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/utils/hijri_calendar.dart';
import '../../../../core/widgets/tv_focusable.dart';
import '../../../kuran/providers/kuran_providers.dart';

/// Android TV / Google TV Yalın 10-Foot UI Ana Ekranı.
/// Yalnızca Sesli & Kelime Takipli Mukabele ve Kur'ân-ı Kerîm (Rahle & Mushaf)
/// okuma modüllerini içerir; Zikirce tasarım diline (%100 Zümrüt Yeşili,
/// Klasik Krem ve Kahve Gece paleti + Selçuklu yıldızı dokusu) sadıktır.
class ZikirceTvHubScreen extends ConsumerStatefulWidget {
  final int initialSection;

  const ZikirceTvHubScreen({
    super.key,
    this.initialSection = 0,
  });

  @override
  ConsumerState<ZikirceTvHubScreen> createState() => _ZikirceTvHubScreenState();
}

class _ZikirceTvHubScreenState extends ConsumerState<ZikirceTvHubScreen> {
  final FocusNode _mukabeleHeroFocusNode = FocusNode(debugLabel: 'MukabeleHero');
  final FocusNode _mushafHeroFocusNode = FocusNode(debugLabel: 'MushafHero');
  bool _isGoogleSignedIn = false;
  String _googleUserEmail = '';

  static const List<int> _juzStartPages = <int>[
    1, 22, 42, 62, 82, 102, 122, 142, 162, 182,
    202, 222, 242, 262, 282, 302, 322, 342, 362, 382,
    402, 422, 442, 462, 482, 502, 522, 542, 562, 582,
  ];

  @override
  void initState() {
    super.initState();
    _refreshGoogleAuthState();
    _loadIndependentMushafProgress();
  }

  Future<void> _loadIndependentMushafProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedPage = prefs.getInt('mushaf_independent_last_page');
      if (savedPage != null && savedPage >= 1 && savedPage <= 605 && mounted) {
        ref.read(currentMushafPageProvider.notifier).state = savedPage;
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _mukabeleHeroFocusNode.dispose();
    _mushafHeroFocusNode.dispose();
    super.dispose();
  }

  Future<void> _refreshGoogleAuthState() async {
    try {
      final driveService = ref.read(googleDriveBackupServiceProvider);
      final signedIn = await driveService.isSignedIn();
      final email = await driveService.getUserEmail() ?? '';
      if (mounted) {
        setState(() {
          _isGoogleSignedIn = signedIn;
          _googleUserEmail = email;
        });
      }
    } catch (_) {}
  }

  Future<void> _handleGoogleCloudButton() async {
    if (!_isGoogleSignedIn) {
      final activeSession = ref.read(activeSessionProvider);
      final success = await GoogleOAuthSheet.startOAuth(
        context,
        sessionId: activeSession.id,
      );
      if (success) {
        final sp = await SharedPreferences.getInstance();
        final isDefault = activeSession.id == UserSession.defaultSessionId;
        final email = sp.getString('GoogleDrive_UserEmail_${activeSession.id}') ??
            (isDefault ? sp.getString('GoogleDrive_UserEmail') : null);
        if (email != null && email.isNotEmpty) {
          final updated = activeSession.copyWith(isCloud: true, email: email);
          await ref.read(sessionProvider.notifier).updateSession(updated);
        }
        await _refreshGoogleAuthState();
        if (mounted) {
          unawaited(CloudSyncEngine.instance.pullAndMerge(ref, force: true));
        }
      }
    } else {
      await CloudSyncEngine.instance.pullAndMerge(ref, force: true);
      await _refreshGoogleAuthState();
    }
  }

  void _cycleZikirceTheme() {
    final currentKey = ref.read(themeNotifierProvider);
    final String nextKey;
    if (currentKey == AppThemeKeys.greenLight) {
      nextKey = AppThemeKeys.creamLight;
    } else if (currentKey == AppThemeKeys.creamLight) {
      nextKey = AppThemeKeys.dark;
    } else {
      nextKey = AppThemeKeys.greenLight;
    }
    ref.read(themeNotifierProvider.notifier).setTheme(nextKey);
  }

  String _themeLabel(String key) {
    switch (key) {
      case AppThemeKeys.creamLight:
        return 'Açık Krem';
      case AppThemeKeys.dark:
      case AppThemeKeys.oledBlack:
        return 'Kahve Gece';
      default:
        return 'Zümrüt Yeşil';
    }
  }

  void _openJuzActionModal(int juzNumber, int startPage) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: colors.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
            side: BorderSide(color: colors.accent.withValues(alpha: 0.45), width: 1.5),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(26),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: colors.accent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '$juzNumber. CÜZ • SAYFA $startPage',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: colors.accent,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const Spacer(),
                      TvFocusable(
                        borderRadius: 12,
                        onPressed: () => Navigator.of(ctx).pop(),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        child: Text(
                          '✕ Kapat',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: colors.secondaryTextAlt,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '$juzNumber. Cüzü Nasıl Açmak İstersiniz?',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                      color: colors.primaryText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Sesli kelime takipli mukabele dinleyebilir veya tam ekran Mushaf görünümünde okuyabilirsiniz.',
                    style: TextStyle(
                      fontSize: 13.5,
                      color: colors.secondaryTextAlt,
                    ),
                  ),
                  const SizedBox(height: 22),
                  TvFocusable(
                    autofocus: true,
                    borderRadius: 18,
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      ref.read(mukabeleSyncProvider.notifier).saveProgress(startPage);
                      context.push('/mukabele?page=$startPage&juz=$juzNumber');
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? const [Color(0xFF2B231C), Color(0xFF1F1914)]
                              : [
                                  colors.accent,
                                  Color.lerp(colors.accent, const Color(0xFF0E382C), 0.45)!,
                                ],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color(0xFFD4AF37).withValues(alpha: 0.65),
                          width: 1.4,
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.play_circle_fill_rounded, color: Color(0xFFD4AF37), size: 28),
                          SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Sesli & Kelime Takipli Mukabele Başlat',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFFFDF8EE),
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Ok ile kelime takibi ve sesli tilâvet',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: Color(0xFFFFD56B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFFD4AF37), size: 16),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TvFocusable(
                    borderRadius: 18,
                    onPressed: () async {
                      Navigator.of(ctx).pop();
                      ref.read(currentMushafPageProvider.notifier).state = startPage;
                      try {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setInt('mushaf_independent_last_page', startPage);
                      } catch (_) {}
                      if (mounted) {
                        context.push('/mushaf?page=$startPage');
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        color: colors.pageBackground,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: colors.accent.withValues(alpha: 0.45),
                          width: 1.4,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.auto_stories_rounded, color: colors.accent, size: 26),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tam Ekran Kur’ân-ı Kerîm Oku (Mushaf & Meâl)',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: colors.primaryText,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'TV ekranına özel büyük Mushaf hattı ve Türkçe meâl',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: colors.secondaryTextAlt,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.arrow_forward_ios_rounded, color: colors.accent, size: 16),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _openSurahSelectorDialog() {
    final colors = context.colors;
    const surahs = SurahDataProvider.surahs;

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: colors.cardBackground,
          insetPadding: const EdgeInsets.symmetric(horizontal: 42, vertical: 28),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
            side: BorderSide(color: colors.borderStroke, width: 1.4),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.menu_book_rounded, color: colors.accent, size: 24),
                    const SizedBox(width: 10),
                    Text(
                      'Sûre Fihristi (114 Sûre-i Celîle)',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: colors.primaryText,
                      ),
                    ),
                    const Spacer(),
                    TvFocusable(
                      borderRadius: 12,
                      onPressed: () => Navigator.of(ctx).pop(),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      child: Text(
                        '✕ Kapat',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: colors.secondaryTextAlt,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 2.8,
                    ),
                    itemCount: surahs.length,
                    itemBuilder: (context, index) {
                      final surah = surahs[index];
                      return TvFocusable(
                        autofocus: index == 0,
                        borderRadius: 16,
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _openJuzActionModal(surah.juzNumber, surah.startPage);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: colors.pageBackground,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: colors.borderStroke),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: colors.accent.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${surah.id}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    color: colors.accent,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      surah.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: colors.primaryText,
                                      ),
                                    ),
                                    Text(
                                      'Sayfa ${surah.startPage} • ${surah.ayetSayisi} Âyet',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: colors.secondaryTextAlt,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
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
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final themeKey = ref.watch(themeNotifierProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final syncState = ref.watch(cloudSyncProvider);

    return Scaffold(
      backgroundColor: colors.pageBackground,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Zikirce Özgün Selçuklu Yıldızı & Yumuşak Işık Atmosferi
          IgnorePointer(
            child: CustomPaint(
              painter: _ZikirceSeljukBackgroundPainter(
                accentColor: colors.accent,
                isDark: isDark,
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 20, 32, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildZikirceTopBar(
                    colors: colors,
                    isDark: isDark,
                    themeKey: themeKey,
                    syncState: syncState,
                  ),
                  const SizedBox(height: 22),
                  Expanded(
                    child: _buildSimplifiedTvBody(
                      colors: colors,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZikirceTopBar({
    required AppThemeColors colors,
    required bool isDark,
    required String themeKey,
    required CloudSyncState syncState,
  }) {
    final isSyncing = syncState.status == CloudSyncStatus.checking ||
        syncState.status == CloudSyncStatus.syncing;
    final hijri = HijriDate.fromGregorian(DateTime.now());

    final String cloudButtonLabel;
    if (isSyncing) {
      cloudButtonLabel = '⏳ Eşitleniyor...';
    } else if (_isGoogleSignedIn) {
      final shortMail = _googleUserEmail.contains('@')
          ? _googleUserEmail.split('@').first
          : 'Bulut Bağlı';
      cloudButtonLabel = '☁️ $shortMail • Eşitle';
    } else {
      cloudButtonLabel = '☁️ Google ile Eşitle';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colors.borderStroke,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Image.asset(
              'assets/images/zikirce_logo.png',
              width: 30,
              height: 30,
              errorBuilder: (_, __, ___) => Icon(
                Icons.menu_book_rounded,
                size: 26,
                color: colors.accent,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'Zikirce TV',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: colors.primaryText,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Flexible(
                      child: Text(
                        'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Amiri',
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: colors.accent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${hijri.format()} • Tam Ekran Kur’ân-ı Kerîm Okuma & Kelime Takipli Sesli Mukabele',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: colors.secondaryTextAlt,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // 1. Sûre Fihristi Butonu (114 Sûre)
          TvFocusable(
            borderRadius: 14,
            onPressed: _openSurahSelectorDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: colors.pageBackground,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: colors.accent.withValues(alpha: 0.45),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.menu_book_rounded,
                    size: 17,
                    color: colors.accent,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '114 Sûre Fihristi',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: colors.primaryText,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),

          // 2. Google Giriş & Bulut Eşitleme Butonu
          TvFocusable(
            borderRadius: 14,
            onPressed: _handleGoogleCloudButton,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: _isGoogleSignedIn
                    ? colors.accent.withValues(alpha: 0.14)
                    : colors.accent,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.accent),
              ),
              child: Text(
                cloudButtonLabel,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: _isGoogleSignedIn ? colors.accent : Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // 3. Zikirce Tema Değiştirme Butonu (Zümrüt Yeşil / Açık Krem / Kahve Gece)
          TvFocusable(
            borderRadius: 14,
            onPressed: _cycleZikirceTheme,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: colors.pageBackground,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.borderStroke),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.palette_outlined,
                    size: 17,
                    color: colors.accent,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _themeLabel(themeKey),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: colors.primaryText,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimplifiedTvBody({
    required AppThemeColors colors,
    required bool isDark,
  }) {
    final mukabeleSync = ref.watch(mukabeleSyncProvider);
    final currentMushafPage = ref.watch(currentMushafPageProvider);
    final effectiveMushafPage = currentMushafPage.clamp(1, 605);
    final mushafJuz = (((effectiveMushafPage - 1) ~/ 20) + 1).clamp(1, 30);
    final mushafProgressPercent =
        ((effectiveMushafPage / 605.0) * 100).round().clamp(1, 100);
    final mukabeleProgressPercent =
        ((mukabeleSync.lastPage / 605.0) * 100).round().clamp(1, 100);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ÜST HERO SATIRI: Sadece 2 Ana Modül (Sesli Mukabele & Kur'ân-ı Kerîm Rahle Okuma)
        Expanded(
          flex: 65,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // SOL HERO KART: Sesli & Kelime Takipli Mukabele (Zikirce Zümrüt & Altın İmza Kartı)
              Expanded(
                flex: 10,
                child: TvFocusable(
                  focusNode: _mukabeleHeroFocusNode,
                  autofocus: true,
                  borderRadius: 28,
                  onPressed: () async {
                    await context.push('/mukabele?page=${mukabeleSync.lastPage}');
                    if (mounted) {
                      _mukabeleHeroFocusNode.requestFocus();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? const [
                                Color(0xFF2B231C),
                                Color(0xFF1F1914),
                              ]
                            : [
                                colors.accent,
                                Color.lerp(
                                    colors.accent, const Color(0xFF0E382C), 0.45)!,
                              ],
                      ),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.65),
                        width: 1.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colors.accent
                              .withValues(alpha: isDark ? 0.28 : 0.24),
                          blurRadius: 26,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD4AF37),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                '▶️ SESLİ MUKABELE & HATİM (OK)',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF1A1512),
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                            const Spacer(),
                            const Icon(
                              Icons.graphic_eq_rounded,
                              color: Color(0xFFD4AF37),
                              size: 32,
                            ),
                          ],
                        ),
                        const Spacer(),
                        const Text(
                          'Kelime Takipli Sesli Mukabele',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFFDF8EE),
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Cüz ${mukabeleSync.lastJuz} • Sayfa ${mukabeleSync.lastPage} / 605 • %$mukabeleProgressPercent',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFFFD56B),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: (mukabeleSync.lastPage / 605.0).clamp(0.03, 1.0),
                            minHeight: 8,
                            backgroundColor: Colors.white.withValues(alpha: 0.18),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFFD4AF37),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Diyanet “Ok ile Takip” kelime vurgusu ve sesli tilâvet ile kaldığınız sayfadan devam edin.',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            color: const Color(0xFFFDF8EE).withValues(alpha: 0.88),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 22),

              // SAĞ HERO KART: Rahlede Kur'ân-ı Kerîm Okuma (Çift Sayfa Mushaf & Meâl)
              Expanded(
                flex: 10,
                child: TvFocusable(
                  focusNode: _mushafHeroFocusNode,
                  borderRadius: 28,
                  onPressed: () async {
                    await context.push('/mushaf?page=$effectiveMushafPage');
                    if (mounted) {
                      _mushafHeroFocusNode.requestFocus();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: colors.cardBackground,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: colors.accent.withValues(alpha: 0.5),
                        width: 1.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withValues(alpha: isDark ? 0.35 : 0.08),
                          blurRadius: 26,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 6,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.accent.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: colors.accent.withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Text(
                                  '📖 KUR’ÂN-I KERÎM OKUMA (OK)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    color: colors.accent,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                'Kur’ân-ı Kerîm Mushaf & Meâl',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 25,
                                  fontWeight: FontWeight.w900,
                                  color: colors.primaryText,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Cüz $mushafJuz • Sayfa $effectiveMushafPage / 605 • %$mushafProgressPercent',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 18.5,
                                  fontWeight: FontWeight.w900,
                                  color: colors.accent,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  value: (effectiveMushafPage / 605.0).clamp(0.03, 1.0),
                                  minHeight: 8,
                                  backgroundColor:
                                      colors.borderStroke.withValues(alpha: 0.5),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    colors.accent,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'TV ekranını dolduran büyük Mushaf hattı, gelişmiş yazı boyutu ayarı ve Türkçe meâl.',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  color: colors.secondaryTextAlt,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 18),
                        SizedBox(
                          width: 150,
                          height: 185,
                          child: _MiniMushafSinglePageIllustration(
                            pageNo: effectiveMushafPage,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ALT SATIR: 1–30. Cüz Hızlı Seçim Şeridi (Kumanda ile Doğrudan Cüze Geçiş)
        Expanded(
          flex: 35,
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
            decoration: BoxDecoration(
              color: colors.cardBackground,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: colors.borderStroke,
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.auto_stories_rounded,
                      size: 19,
                      color: colors.accent,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Hızlı Cüz Seçimi (1 – 30. Cüz)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: colors.primaryText,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '◀ / ▶ Kumanda ile Cüz Seçin • OK ile Mukabele veya Mushaf Açın',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: colors.secondaryTextAlt,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: 30,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final juzNo = index + 1;
                      final startPage = _juzStartPages[index];
                      final isCurrentJuz = mukabeleSync.lastJuz == juzNo;

                      return TvFocusable(
                        borderRadius: 18,
                        onPressed: () => _openJuzActionModal(juzNo, startPage),
                        child: Container(
                          width: 132,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isCurrentJuz
                                ? colors.accent
                                : colors.pageBackground,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isCurrentJuz
                                  ? const Color(0xFFD4AF37)
                                  : colors.borderStroke,
                              width: isCurrentJuz ? 1.8 : 1.1,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$juzNo. Cüz',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w900,
                                  color: isCurrentJuz
                                      ? Colors.white
                                      : colors.primaryText,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isCurrentJuz
                                    ? 'Kaldığınız Cüz'
                                    : 'Sayfa $startPage',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isCurrentJuz
                                      ? const Color(0xFFFFD56B)
                                      : colors.secondaryTextAlt,
                                ),
                              ),
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
        ),
      ],
    );
  }
}

/// Sağ Hero Kart içinde yer alan Tek Sayfa Tam Ekran Mushaf-ı Şerîf Minyatür İllüstrasyonu
class _MiniMushafSinglePageIllustration extends StatelessWidget {
  final int pageNo;

  const _MiniMushafSinglePageIllustration({
    required this.pageNo,
  });

  @override
  Widget build(BuildContext context) {
    const primaryLeather = Color(0xFF144533);
    const secondaryLeather = Color(0xFF0B291E);
    const goldAccent = Color(0xFFD4AF37);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primaryLeather,
            secondaryLeather,
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: goldAccent.withValues(alpha: 0.75),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFF6EFE0),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: goldAccent.withValues(alpha: 0.55),
            width: 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 14,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: goldAccent.withValues(alpha: 0.26),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'سُورَةُ الْبَقَرَةِ',
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF5A4638),
                ),
              ),
            ),
            const SizedBox(height: 8),
            for (int i = 0; i < 7; i++) ...[
              Container(
                height: 5,
                margin: const EdgeInsets.only(bottom: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C1E18).withValues(alpha: 0.38),
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ],
            const Spacer(),
            Align(
              alignment: Alignment.bottomCenter,
              child: Text(
                'Sayfa $pageNo',
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF5A4638),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Zikirce Arka Plan Selçuklu Sekiz Köşeli Yıldız & Geometrik Desen Ressamı
class _ZikirceSeljukBackgroundPainter extends CustomPainter {
  final Color accentColor;
  final bool isDark;

  const _ZikirceSeljukBackgroundPainter({
    required this.accentColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = accentColor.withValues(alpha: isDark ? 0.045 : 0.055)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final centers = <Offset>[
      Offset(size.width * 0.88, size.height * 0.18),
      Offset(size.width * 0.14, size.height * 0.82),
    ];

    for (final c in centers) {
      for (final radius in <double>[65, 115, 165]) {
        _drawEightPointedStar(canvas, c, radius, paint);
      }
    }
  }

  void _drawEightPointedStar(
    Canvas canvas,
    Offset center,
    double radius,
    Paint paint,
  ) {
    final path = Path();
    const points = 8;
    for (int i = 0; i < points * 2; i++) {
      final r = i.isEven ? radius : radius * 0.68;
      final angle = (i * math.pi) / points;
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ZikirceSeljukBackgroundPainter oldDelegate) {
    return oldDelegate.accentColor != accentColor ||
        oldDelegate.isDark != isDark;
  }
}
