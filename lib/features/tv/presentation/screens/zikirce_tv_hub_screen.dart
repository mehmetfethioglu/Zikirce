import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/providers/tv_mode_provider.dart';
import '../../../../core/services/cloud_sync_engine.dart';
import '../../../../core/services/google_drive_backup_service.dart';
import '../../../../core/services/google_oauth_sheet.dart';
import '../../../../core/services/prayer_times_service.dart';
import '../../../../core/session/session_providers.dart';
import '../../../../core/session/user_session.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/utils/hijri_calendar.dart';
import '../../../../core/widgets/tv_focusable.dart';
import '../../../kuran/data/islamic_bookshelf_models.dart';
import '../../../namaz_vakitleri/presentation/widgets/city_selection_sheet.dart';
import '../../../namaz_vakitleri/providers/prayer_providers.dart';

/// Android TV / Google TV 10-Foot UI Ana Meydanı,
/// Zikirce Özgün Tema Paleti (Zümrüt Yeşili, Klasik Krem, Kahve Gece),
/// %100 Kumanda (D-Pad) Uyumlu Şehir/Google/Tema Kontrolü ve 40 Eserlik Külliyat Rahle Kitaplığı.
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
  late int _activeSection;
  int _selectedCategoryFilter = 0; // 0: Tümü, 1: Kur'ân & Meâl, 2: Tefsir, 3: Hadis, 4: Risale-i Nur
  bool _isGoogleSignedIn = false;
  String _googleUserEmail = '';

  @override
  void initState() {
    super.initState();
    _activeSection = widget.initialSection.clamp(0, 2);
    _refreshGoogleAuthState();
  }

  @override
  void didUpdateWidget(covariant ZikirceTvHubScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSection != widget.initialSection) {
      setState(() {
        _activeSection = widget.initialSection.clamp(0, 2);
      });
    }
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

  void _openCitySelectorModal() {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CitySelectionSheet(),
    );
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

  IslamicShelfBook _resolveLastReadBook(List<IslamicShelfBook> books) {
    if (books.isEmpty) {
      return IslamicBookshelfCatalog.defaultBooks().first;
    }
    final nonMushaf = books.where((b) => b.id != 'book_mushaf').toList();
    final pool = nonMushaf.isNotEmpty ? nonMushaf : books;

    IslamicShelfBook? bestByTime;
    for (final b in pool) {
      if (b.lastReadAtMs > 0) {
        if (bestByTime == null || b.lastReadAtMs > bestByTime.lastReadAtMs) {
          bestByTime = b;
        }
      }
    }
    if (bestByTime != null) return bestByTime;

    for (final b in pool) {
      if (b.hasStartedReading && b.currentPage > 1) {
        return b;
      }
    }

    return pool.firstWhere(
      (b) => b.id == 'book_rn_sozler' || b.id == 'book_tafseer_kuranyolu',
      orElse: () => pool.first,
    );
  }

  List<IslamicShelfBook> _filterBooks(List<IslamicShelfBook> allBooks) {
    switch (_selectedCategoryFilter) {
      case 1:
        return allBooks
            .where((b) =>
                b.category == IslamicBookCategory.quran ||
                b.category == IslamicBookCategory.meal)
            .toList();
      case 2:
        return allBooks
            .where((b) => b.category == IslamicBookCategory.tafseer)
            .toList();
      case 3:
        return allBooks
            .where((b) => b.category == IslamicBookCategory.hadith)
            .toList();
      case 4:
        return allBooks
            .where((b) => b.category == IslamicBookCategory.risale)
            .toList();
      default:
        return allBooks;
    }
  }

  void _openFullScreenEvMescidi() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TvEvMescidiAmbientScreen(
          onClose: () => Navigator.of(context).maybePop(),
        ),
      ),
    );
  }

  void _openBookInRahle(IslamicShelfBook book) {
    if (book.id == 'book_mushaf') {
      context.push('/mushaf?page=${book.currentPage}');
    } else {
      context.push('/kulliyat?bookId=${book.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_activeSection == 2) {
      return TvEvMescidiAmbientScreen(
        onClose: () => setState(() => _activeSection = 0),
      );
    }

    final colors = context.colors;
    final themeKey = ref.watch(themeNotifierProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final city = ref.watch(selectedCityProvider);
    final nextPrayer = ref.watch(nextPrayerInfoProvider);
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
              padding: const EdgeInsets.fromLTRB(28, 18, 28, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildZikirceTopBar(
                    colors: colors,
                    isDark: isDark,
                    themeKey: themeKey,
                    city: city,
                    nextPrayer: nextPrayer,
                    syncState: syncState,
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: _activeSection == 0
                        ? _buildMainHubSection(colors: colors, isDark: isDark)
                        : _buildKulliyatLibrarySection(
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
    required String city,
    required NextPrayerInfo? nextPrayer,
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
      cloudButtonLabel = '☁️ Google ile Giriş Yap';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
          // Sol: Zikirce Özgün Logo + Besmele-i Şerif & Hicri Tarih
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
                Icons.mosque_rounded,
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
                      'Zikirce',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: colors.primaryText,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Amiri',
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: colors.accent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${hijri.format()} • Cihazlar Arası Bulut Senkronizasyonlu Rahle & Mukabele',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.secondaryTextAlt,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Sağ: %100 Kumanda (D-Pad) Odaklanabilir Kontrol Butonları
          // 1. Şehir Seçimi Butonu (81 İl)
          TvFocusable(
            borderRadius: 14,
            onPressed: _openCitySelectorModal,
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
                    Icons.location_on_rounded,
                    size: 17,
                    color: colors.accent,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    city,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: colors.primaryText,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: colors.secondaryTextAlt,
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

  Widget _buildMainHubSection({
    required AppThemeColors colors,
    required bool isDark,
  }) {
    final mukabeleSync = ref.watch(mukabeleSyncProvider);
    final books = ref.watch(islamicBookshelfProvider);
    final lastBook = _resolveLastReadBook(books);
    final city = ref.watch(selectedCityProvider);
    final timingsAsync = ref.watch(prayerTimingsProvider);
    final nextPrayer = ref.watch(nextPrayerInfoProvider);
    final timings = timingsAsync.valueOrNull ??
        PrayerTimesService.calculateOfflinePrayerTimes(city, DateTime.now());

    final spreadStart = lastBook.currentPage;
    final spreadEnd = (spreadStart + 1).clamp(1, lastBook.totalPages);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ÜST HERO SATIRI: 2 Ferah ve Derinlikli Zikirce Ana Kartı
        Expanded(
          flex: 62,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // SOL HERO KART: Rahlede Açık Kitap (3B Açık Rahle Görselli Külliyat Okuma Kartı)
              Expanded(
                flex: 11,
                child: TvFocusable(
                  autofocus: true,
                  borderRadius: 26,
                  onPressed: () => _openBookInRahle(lastBook),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: colors.cardBackground,
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(
                        color: colors.accent.withValues(alpha: 0.45),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withValues(alpha: isDark ? 0.35 : 0.08),
                          blurRadius: 24,
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
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.accent.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: colors.accent.withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Text(
                                  '📖 RAHLEDE ÇİFT SAYFA OKUMA (OK)',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w900,
                                    color: colors.accent,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                lastBook.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: colors.primaryText,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                lastBook.author,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: colors.secondaryTextAlt,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Sayfa $spreadStart–$spreadEnd / ${lastBook.totalPages} • %${lastBook.progressPercent} Tamamlandı',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: colors.accent,
                                ),
                              ),
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  value: (lastBook.progressPercent / 100.0)
                                      .clamp(0.04, 1.0),
                                  minHeight: 7,
                                  backgroundColor:
                                      colors.borderStroke.withValues(alpha: 0.5),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    colors.accent,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Fiziki 3B sayfa çevirme animasyonu ve kaydırmasız çift yaprak rahle görünümü.',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: colors.secondaryTextAlt,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 18),
                        // Sağ Taraf: 3 Boyutlu Açık Rahle ve Kitap Minyatürü
                        SizedBox(
                          width: 175,
                          height: 185,
                          child: _MiniRahleSpreadIllustration(
                            book: lastBook,
                            spreadStart: spreadStart,
                            spreadEnd: spreadEnd,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),

              // SAĞ HERO KART: Kelime Takipli Mukabele & Hatim (Zikirce Zümrüt & Altın Kartı)
              Expanded(
                flex: 9,
                child: TvFocusable(
                  borderRadius: 26,
                  onPressed: () {
                    context.push('/mukabele?page=${mukabeleSync.lastPage}');
                  },
                  child: Container(
                    padding: const EdgeInsets.all(24),
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
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.55),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colors.accent
                              .withValues(alpha: isDark ? 0.25 : 0.22),
                          blurRadius: 24,
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
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD4AF37),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                '▶️ SESLİ MUKABELE & HATİM (OK)',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF1A1512),
                                ),
                              ),
                            ),
                            const Spacer(),
                            const Icon(
                              Icons.graphic_eq_rounded,
                              color: Color(0xFFD4AF37),
                              size: 28,
                            ),
                          ],
                        ),
                        const Spacer(),
                        const Text(
                          'Kelime Takipli Mukabele',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFFDF8EE),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Cüz ${mukabeleSync.lastJuz} • Sayfa ${mukabeleSync.lastPage} / 605',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFFFD56B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Telefonda veya tablette kaldığınız sayfadan sesli kelime vurgusuyla devam edin.',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: const Color(0xFFFDF8EE).withValues(alpha: 0.85),
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
        const SizedBox(height: 18),

        // ALT SATIR: Günün Namaz Vakitleri Şeridi + 40 Eserlik Külliyat Kitaplığına Geçiş Kartı
        Expanded(
          flex: 38,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Sol Alt: Günün Namaz Vakitleri & Canlı Geri Sayım (Tıklanınca Tam Ekran Ev Mescidi Açılır)
              Expanded(
                flex: 13,
                child: TvFocusable(
                  borderRadius: 24,
                  onPressed: _openFullScreenEvMescidi,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: colors.cardBackground,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: colors.borderStroke,
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withValues(alpha: isDark ? 0.25 : 0.05),
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
                              Icons.mosque_rounded,
                              size: 19,
                              color: colors.accent,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '$city Namaz Vakitleri',
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                                color: colors.primaryText,
                              ),
                            ),
                            const Spacer(),
                            if (nextPrayer != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.accent.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '${nextPrayer.name} Vaktine Kalan: ${nextPrayer.formattedRemaining}',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: colors.accent,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            for (final slot in <({String name, String time, int idx})>[
                              (name: 'İmsak', time: timings.fajr, idx: 0),
                              (name: 'Güneş', time: timings.sunrise, idx: 1),
                              (name: 'Öğle', time: timings.dhuhr, idx: 2),
                              (name: 'İkindi', time: timings.asr, idx: 3),
                              (name: 'Akşam', time: timings.maghrib, idx: 4),
                              (name: 'Yatsı', time: timings.isha, idx: 5),
                            ]) ...[
                              if (slot.idx > 0) const SizedBox(width: 10),
                              Expanded(
                                child: _ZikircePrayerPillSlot(
                                  label: slot.name,
                                  time: slot.time,
                                  isActive:
                                      nextPrayer?.activePrayerIndex == slot.idx,
                                  colors: colors,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 18),

              // Sağ Alt: 40 Eserlik Külliyat Kitaplığına Geçiş Kartı (3B Cilt Sırtları ile)
              Expanded(
                flex: 7,
                child: TvFocusable(
                  borderRadius: 24,
                  onPressed: () => setState(() => _activeSection = 1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: colors.cardBackground,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: colors.borderStroke,
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withValues(alpha: isDark ? 0.25 : 0.05),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '📚 40 Eserlik Külliyat',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: colors.primaryText,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Kur’ân, Meâl, Tefsir, Kütüb-i Sitte ve Risale-i Nur Rahle Kitaplığı',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: colors.secondaryTextAlt,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Kitaplığı Aç (OK) →',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: colors.accent,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // 3B Kitap Sırtları İllüstrasyonu
                        const _MiniBookshelfSpinesWidget(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKulliyatLibrarySection({
    required AppThemeColors colors,
    required bool isDark,
  }) {
    final allBooks = ref.watch(islamicBookshelfProvider);
    final filteredBooks = _filterBooks(allBooks);

    const filterLabels = <String>[
      'Tümü (40)',
      'Kur’ân & Meâl',
      'Tefsirler (6.236 Âyet)',
      'Kütüb-i Sitte & Hadis',
      'Risale-i Nur Külliyatı',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Üst Kategori Filtre Çipleri + Ana Meydana Dön Butonu
        SizedBox(
          height: 44,
          child: Row(
            children: [
              TvFocusable(
                borderRadius: 999,
                onPressed: () => setState(() => _activeSection = 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: colors.cardBackground,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: colors.borderStroke),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.arrow_back_rounded,
                        size: 16,
                        color: colors.accent,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Ana Meydan',
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
              const SizedBox(width: 12),
              Expanded(
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: filterLabels.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final isSelected = _selectedCategoryFilter == index;
                    return TvFocusable(
                      autofocus: index == 0,
                      borderRadius: 999,
                      onPressed: () {
                        setState(() => _selectedCategoryFilter = index);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? colors.accent
                              : colors.cardBackground,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: isSelected
                                ? colors.accent
                                : colors.borderStroke,
                          ),
                        ),
                        child: Text(
                          filterLabels[index],
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: isSelected
                                ? Colors.white
                                : colors.primaryText,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 4 Sütunlu 3B Cilt Görünümlü Külliyat Kitaplığı Izgarası
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 1.65,
            ),
            itemCount: filteredBooks.length,
            itemBuilder: (context, index) {
              final book = filteredBooks[index];
              final palette = book.palette;
              return TvFocusable(
                borderRadius: 20,
                onPressed: () => _openBookInRahle(book),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colors.cardBackground,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: colors.borderStroke,
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withValues(alpha: isDark ? 0.25 : 0.05),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Sol: 3B Klasik Tahrirli Kitap Cildi Minyatürü
                      Container(
                        width: 52,
                        height: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              palette.primaryLeather,
                              palette.secondaryLeather,
                            ],
                          ),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(6),
                            bottomLeft: Radius.circular(6),
                            topRight: Radius.circular(12),
                            bottomRight: Radius.circular(12),
                          ),
                          border: Border.all(
                            color: palette.goldAccent.withValues(alpha: 0.65),
                            width: 1.1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 6,
                              offset: const Offset(3, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.auto_stories_rounded,
                              size: 18,
                              color: palette.goldAccent,
                            ),
                            const SizedBox(height: 4),
                            Container(
                              width: 28,
                              height: 1.5,
                              color: palette.goldAccent.withValues(alpha: 0.6),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Sağ: Kitap Bilgileri ve İlerleme
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colors.accent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Rahlede Çift Sayfa',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: colors.accent,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              book.shortTitle.isNotEmpty
                                  ? book.shortTitle
                                  : book.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: colors.primaryText,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              book.author,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: colors.secondaryTextAlt,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Sayfa ${book.currentPage}/${book.totalPages} • %${book.progressPercent}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: colors.accent,
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
    );
  }
}

class _ZikircePrayerPillSlot extends StatelessWidget {
  final String label;
  final String time;
  final bool isActive;
  final AppThemeColors colors;

  const _ZikircePrayerPillSlot({
    required this.label,
    required this.time,
    required this.isActive,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: isActive ? colors.accent : colors.pageBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? colors.accent : colors.borderStroke,
          width: isActive ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isActive ? Colors.white.withValues(alpha: 0.9) : colors.secondaryTextAlt,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            time,
            style: TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.w900,
              color: isActive ? Colors.white : colors.primaryText,
            ),
          ),
        ],
      ),
    );
  }
}

/// Sol Hero Kart içinde yer alan 3B Açık Kitap & Rahle Minyatür İllüstrasyonu
class _MiniRahleSpreadIllustration extends StatelessWidget {
  final IslamicShelfBook book;
  final int spreadStart;
  final int spreadEnd;

  const _MiniRahleSpreadIllustration({
    required this.book,
    required this.spreadStart,
    required this.spreadEnd,
  });

  @override
  Widget build(BuildContext context) {
    final palette = book.palette;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            palette.primaryLeather,
            palette.secondaryLeather,
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: palette.goldAccent.withValues(alpha: 0.75),
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
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFF6EFE0),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          children: [
            // Sol minyatür yaprak
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: palette.goldAccent.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 6),
                  for (int i = 0; i < 6; i++) ...[
                    Container(
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 4),
                      width: i == 5 ? 36 : double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C1E18).withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                  const Spacer(),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Text(
                      '$spreadStart',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF5A4638),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Orta Cilt Sırtı
            Container(
              width: 6,
              margin: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.08),
                    Colors.black.withValues(alpha: 0.32),
                    Colors.black.withValues(alpha: 0.08),
                  ],
                ),
              ),
            ),
            // Sağ minyatür yaprak
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: palette.goldAccent.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 6),
                  for (int i = 0; i < 6; i++) ...[
                    Container(
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 4),
                      width: i == 5 ? 32 : double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C1E18).withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                  const Spacer(),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Text(
                      '$spreadEnd',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF5A4638),
                      ),
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
}

/// Külliyat Kartı Sağ Tarafında 4 Adet 3B Klasik Cilt Sırtı Gösteren Bileşen
class _MiniBookshelfSpinesWidget extends StatelessWidget {
  const _MiniBookshelfSpinesWidget();

  @override
  Widget build(BuildContext context) {
    const spines = <Color>[
      Color(0xFF144533),
      Color(0xFF6B1D1D),
      Color(0xFF1E3557),
      Color(0xFF4A2E1B),
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (int i = 0; i < spines.length; i++)
          Container(
            width: 16,
            height: 68.0 - (i.isEven ? 0 : 6),
            margin: const EdgeInsets.only(left: 4),
            decoration: BoxDecoration(
              color: spines[i],
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: const Color(0xFFD4AF37).withValues(alpha: 0.65),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(1, 2),
                ),
              ],
            ),
          ),
      ],
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

/// TV'yi salon mescidine dönüştüren, OLED ekran yanması (burn-in) korumalı
/// Tam Ekran Ambient Vakit & Ezan Panosu.
class TvEvMescidiAmbientScreen extends ConsumerStatefulWidget {
  final VoidCallback? onClose;

  const TvEvMescidiAmbientScreen({
    super.key,
    this.onClose,
  });

  @override
  ConsumerState<TvEvMescidiAmbientScreen> createState() =>
      _TvEvMescidiAmbientScreenState();
}

class _TvEvMescidiAmbientScreenState
    extends ConsumerState<TvEvMescidiAmbientScreen> {
  late final FocusNode _ambientFocusNode;
  Timer? _oledShiftTimer;
  int _oledStep = 0;
  int _wisdomIndex = 0;

  static const List<Offset> _oledOffsets = <Offset>[
    Offset(0, 0),
    Offset(3, -2),
    Offset(-4, 2),
    Offset(4, 3),
    Offset(-3, -3),
  ];

  static const List<({String arabic, String turkish, String source})>
      _dailyWisdoms = [
    (
      arabic: 'أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ',
      turkish: '“Biliniz ki kalpler ancak Allah’ı zikretmekle huzur bulur.”',
      source: 'Ra’d Sûresi, 28. Âyet-i Kerîme',
    ),
    (
      arabic: 'إِنَّ الصَّلَاةَ كَانَتْ عَلَى الْمُؤْمِينَ كِتَابًا مَوْقُوتًا',
      turkish: '“Şüphesiz namaz, müminler üzerine vakitleri belirlenmiş bir farzdır.”',
      source: 'Nisâ Sûresi, 103. Âyet-i Kerîme',
    ),
    (
      arabic: 'خَيْرُكُمْ مَنْ تَعَلَّمَ الْقُرْآنَ وَعَلَّمَهُ',
      turkish: '“Sizin en hayırlınız Kur’ân’ı öğrenen ve öğreteninizdir.”',
      source: 'Sahîh-i Buhârî, Fedâilü’l-Kur’ân 21',
    ),
    (
      arabic: 'الدُّعَاءُ مُخُّ الْعِبَادَةِ',
      turkish: '“Dua ibadetin özüdür.”',
      source: 'Tirmizî, Deavât 1',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _ambientFocusNode = FocusNode(debugLabel: 'TvEvMescidiAmbientFocus');
    _oledShiftTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) {
        setState(() {
          _oledStep = (_oledStep + 1) % _oledOffsets.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _oledShiftTimer?.cancel();
    _ambientFocusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.arrowRight) {
      setState(() {
        _wisdomIndex = (_wisdomIndex + 1) % _dailyWisdoms.length;
      });
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      setState(() {
        _wisdomIndex =
            (_wisdomIndex - 1 + _dailyWisdoms.length) % _dailyWisdoms.length;
      });
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.goBack) {
      if (widget.onClose != null) {
        widget.onClose!();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final city = ref.watch(selectedCityProvider);
    final timingsAsync = ref.watch(prayerTimingsProvider);
    final nextPrayer = ref.watch(nextPrayerInfoProvider);
    final nowAsync = ref.watch(timeTickerStreamProvider);
    final now = nowAsync.valueOrNull ?? DateTime.now();

    final timings = timingsAsync.valueOrNull ??
        PrayerTimesService.calculateOfflinePrayerTimes(city, now);
    final hijri = HijriDate.fromGregorian(now);
    final shift = _oledOffsets[_oledStep];
    final wisdom = _dailyWisdoms[_wisdomIndex];

    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

    final prayerItems = <({String label, String time, int idx})>[
      (label: 'İmsak', time: timings.fajr, idx: 0),
      (label: 'Güneş', time: timings.sunrise, idx: 1),
      (label: 'Öğle', time: timings.dhuhr, idx: 2),
      (label: 'İkindi', time: timings.asr, idx: 3),
      (label: 'Akşam', time: timings.maghrib, idx: 4),
      (label: 'Yatsı', time: timings.isha, idx: 5),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF14110E),
      body: Focus(
        focusNode: _ambientFocusNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.2,
              colors: [
                Color(0xFF231E19),
                Color(0xFF16120F),
                Color(0xFF0E0B09),
              ],
            ),
          ),
          child: SafeArea(
            child: Transform.translate(
              offset: shift,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(36, 24, 36, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Üst Bilgi & Kapatma Şeridi
                    Row(
                      children: [
                        const Icon(
                          Icons.mosque_rounded,
                          color: Color(0xFFD4A574),
                          size: 26,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'ZİKİRCE EV MESCİDİ • ${city.toUpperCase()}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                            color: Color(0xFFD4A574),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${hijri.format()} • ${now.day}.${now.month.toString().padLeft(2, '0')}.${now.year}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFE8DDD0),
                          ),
                        ),
                        if (widget.onClose != null) ...[
                          const SizedBox(width: 18),
                          TvFocusable(
                            onPressed: widget.onClose,
                            borderRadius: 12,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            child: const Text(
                              '✕ Meydana Dön',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFFDF8EE),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const Spacer(),
                    // Dev Dijital Saat ve Sıradaki Vakte Kalan Süre
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            timeStr,
                            style: const TextStyle(
                              fontSize: 68,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2.5,
                              color: Color(0xFFE8DDD0),
                            ),
                          ),
                          if (nextPrayer != null) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 22,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD4A574)
                                    .withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: const Color(0xFFD4A574)
                                      .withValues(alpha: 0.55),
                                ),
                              ),
                              child: Text(
                                '${nextPrayer.nextPrayerNameWithSuffix}: ${nextPrayer.formattedRemaining}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFD4A574),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Spacer(),
                    // 6 Vaktin Yan Yana Işıltılı Kartları
                    Row(
                      children: [
                        for (int i = 0; i < prayerItems.length; i++) ...[
                          if (i > 0) const SizedBox(width: 12),
                          Expanded(
                            child: _AmbientPrayerSlotCard(
                              label: prayerItems[i].label,
                              time: prayerItems[i].time,
                              isActive:
                                  nextPrayer?.activePrayerIndex ==
                                  prayerItems[i].idx,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 22),
                    // Günün Âyet-i Kerîmesi / Hadis-i Şerîfi (Sol/Sağ ok ile değiştirilebilir)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF241F1B).withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color:
                              const Color(0xFFD4A574).withValues(alpha: 0.35),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            wisdom.arabic,
                            textDirection: TextDirection.rtl,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'AmasyaAbay',
                              fontSize: 24,
                              color: Color(0xFFD4A574),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            wisdom.turkish,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFE8DDD0),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${wisdom.source}  •  [◀ / ▶ Hikmet Değiştir]',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFA89888),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AmbientPrayerSlotCard extends StatelessWidget {
  final String label;
  final String time;
  final bool isActive;

  const _AmbientPrayerSlotCard({
    required this.label,
    required this.time,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      decoration: BoxDecoration(
        gradient: isActive
            ? const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF236B56),
                  Color(0xFF17493A),
                ],
              )
            : null,
        color: isActive ? null : const Color(0xFF241F1B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isActive
              ? const Color(0xFFD4A574)
              : const Color(0xFFD4A574).withValues(alpha: 0.32),
          width: isActive ? 2.0 : 1.1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: isActive
                  ? const Color(0xFFFDF8EE)
                  : const Color(0xFFD4A574),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            time,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Color(0xFFFDF8EE),
            ),
          ),
        ],
      ),
    );
  }
}
