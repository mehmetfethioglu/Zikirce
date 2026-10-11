import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/surah_data_provider.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../gamification/providers/gamification_providers.dart';
import '../../../hatim/providers/hatim_providers.dart';
import '../../providers/kuran_providers.dart';
import '../widgets/mushaf_page_widget.dart';
import '../widgets/audio_sync_player_bar.dart';
import '../widgets/desktop_mushaf_nav_button.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/providers/database_provider.dart';
import '../../../gamification/services/daily_streak_service.dart';
import '../../../../core/services/screen_awake_service.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../../../core/session/session_providers.dart';
import '../../../../core/session/user_session.dart';
import 'surah_juz_index_screen.dart';
import 'quran_search_screen.dart';
import '../../../../core/services/cloud_sync_engine.dart';
import '../../../../core/services/celebration_service.dart';
import '../../../../core/utils/pref_utils.dart';
import '../../data/tilavet_secdesi_data.dart';
import '../../providers/tilavet_secdesi_provider.dart';
import '../widgets/tilavet_secdesi_floating_banner.dart';
import '../widgets/tilavet_secdesi_exit_dialog.dart';
import '../widgets/tilavet_secdesi_guide_sheet.dart';
import '../../../gamification/services/custom_badge_service.dart';
import '../widgets/add_custom_quran_badge_sheet.dart';

class MushafScreen extends ConsumerStatefulWidget {
  final int initialPage;
  final Hatim? activeHatim;
  final SureItem? targetSurah;
  final String? streakKey;

  const MushafScreen({
    super.key,
    this.initialPage = 1,
    this.activeHatim,
    this.targetSurah,
    this.streakKey,
  });

  @override
  ConsumerState<MushafScreen> createState() => _MushafScreenState();
}

class _MushafScreenState extends ConsumerState<MushafScreen> {
  late PageController _pageController;
  late final FocusNode _focusNode;
  int _startPage = 1;
  bool _hasMarkedAsRead = false;
  final Set<int> _completedSurahIdsInSession = <int>{};
  final Set<int> _encounteredSecdePages = <int>{};
  bool _dismissedBannerForCurrentPage = false;
  int? _lastBannerPage;
  bool _showDebtReminderBanner = false;
  bool _hideReadBanner = false;
  Timer? _hideReadBannerTimer;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    final startPage = ref.read(currentMushafPageProvider);
    final targetPage = widget.initialPage > 0 ? widget.initialPage : startPage;
    _startPage = targetPage.clamp(1, 605);
    _pageController = PageController(initialPage: _startPage - 1);

    if (TilavetSecdesiData.isSecdePage(_startPage)) {
      _encounteredSecdePages.add(_startPage);
    }

    // Synchronize initial page to current provider and verify screen awake
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(currentMushafPageProvider.notifier).state =
          targetPage.clamp(1, 605);
      if (ref.read(settingsProvider).isKeepScreenAwakeEnabled) {
        ScreenAwakeService.setKeepAwake(true);
      }

      final initialDebt = ref.read(tilavetSecdesiDebtProvider);
      if (initialDebt > 0 && !TilavetSecdesiData.isSecdePage(_startPage)) {
        if (mounted) {
          setState(() {
            _showDebtReminderBanner = true;
          });
        }
        Future.delayed(const Duration(seconds: 6), () {
          if (mounted && _showDebtReminderBanner) {
            setState(() {
              _showDebtReminderBanner = false;
            });
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _hideReadBannerTimer?.cancel();
    _focusNode.dispose();
    _pageController.dispose();
    CloudSyncEngine.instance
        .triggerDebouncedSync(null, delay: const Duration(seconds: 1));
    try {
      ref.read(kuranAudioNotifierProvider.notifier).stop();
    } catch (_) {}
    super.dispose();
  }

  void _goToNextPage() {
    final currentPage = ref.read(currentMushafPageProvider);
    if (currentPage < 605) {
      final next = currentPage + 1;
      ref.read(currentMushafPageProvider.notifier).state = next;
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          next - 1,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutCubic,
        );
      }
    }
  }

  void _goToPreviousPage() {
    final currentPage = ref.read(currentMushafPageProvider);
    if (currentPage > 1) {
      final prev = currentPage - 1;
      ref.read(currentMushafPageProvider.notifier).state = prev;
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          prev - 1,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutCubic,
        );
      }
    }
  }

  Future<void> _promptSecdeDebtIfNeeded() async {
    if (_encounteredSecdePages.isNotEmpty && mounted) {
      final list = _encounteredSecdePages
          .map((p) => TilavetSecdesiData.getSecdeForPage(p))
          .whereType<TilavetSecdeItem>()
          .toList();
      if (list.isNotEmpty) {
        final choice = await TilavetSecdesiExitDialog.show(context,
            encounteredSecdes: list);
        if (choice == TilavetExitChoice.borcaEkle && mounted) {
          await ref
              .read(tilavetSecdesiDebtProvider.notifier)
              .incrementDebt(list.length);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Text('🕌 ', style: TextStyle(fontSize: 18)),
                    Expanded(
                      child: Text(
                        '${list.length} tilâvet secdesi borcunuza eklendi.',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                backgroundColor: const Color(0xFFD97706),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            );
          }
        }
      }
      _encounteredSecdePages.clear();
    }
  }

  Future<void> _handleExit() async {
    final currentPage = ref.read(currentMushafPageProvider);

    if (widget.activeHatim != null) {
      final totalHatimPages = widget.activeHatim?.totalPages ?? 605;
      final isLastPage = currentPage >= totalHatimPages || currentPage >= 604;
      final shouldSave = await showDialog<bool?>(
        context: context,
        builder: (ctx) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final cardBg = isDark ? const Color(0xFF23262F) : Colors.white;
          final textColor =
              isDark ? const Color(0xFFE8DDD0) : const Color(0xFF1E2B27);
          final subColor =
              isDark ? const Color(0xFFA89888) : const Color(0xFF506861);

          if (isLastPage) {
            return AlertDialog(
              backgroundColor: cardBg,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
              title: Row(
                children: [
                  const Text('🎉 ', style: TextStyle(fontSize: 22)),
                  Expanded(
                    child: Text(
                      'Hatim Tamamlandı mı?',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor),
                    ),
                  ),
                ],
              ),
              content: Text(
                '$currentPage. sayfadasınız. "${widget.activeHatim!.title}" hatminizi tamamladınız mı?',
                style: TextStyle(fontSize: 14.5, color: subColor, height: 1.4),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(null),
                  child: Text(
                    'Kaydetme',
                    style: TextStyle(
                        color: isDark ? Colors.white60 : Colors.black54,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(
                    '$currentPage\'te Kaldım',
                    style: const TextStyle(
                        color: Color(0xFF2D7D76),
                        fontWeight: FontWeight.bold),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D7D76),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Evet, Bitir',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          }

          return AlertDialog(
            backgroundColor: cardBg,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              children: [
                const Text('🕌 ', style: TextStyle(fontSize: 22)),
                Expanded(
                  child: Text(
                    'Hatim İlerlemesi',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor),
                  ),
                ),
              ],
            ),
            content: Text(
              'Kaldığınız yer ($currentPage. Sayfa) "${widget.activeHatim!.title}" hatminize kaydedilsin mi?',
              style: TextStyle(fontSize: 14.5, color: subColor, height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(null),
                child: Text(
                  'Kaydetme',
                  style: TextStyle(
                      color: isDark ? Colors.white60 : Colors.black54,
                      fontWeight: FontWeight.bold),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D7D76),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Kaydet',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      );

      if (shouldSave != null && mounted) {
        final bool isHatimCompleted = isLastPage && shouldSave == true;
        final int targetCompletedPages = isHatimCompleted
            ? (widget.activeHatim?.totalPages ?? 605)
            : (currentPage - 1).clamp(0, 605);

        try {
          await ref.read(hatimNotifierProvider).updateHatimPageProgress(
                hatimId: widget.activeHatim!.id,
                targetPage: targetCompletedPages,
              );
          HapticService.targetReached();
          if (mounted) {
            final snackBarText = isHatimCompleted
                ? 'Tebrikler! Hatm-i Şerifiniz başarıyla tamamlandı. 🎉'
                : 'Hatim ilerlemeniz ($currentPage. Sayfa) kaydedildi.';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Text(isHatimCompleted ? '🎉 ' : '📖 ',
                        style: const TextStyle(fontSize: 18)),
                    Expanded(
                      child: Text(
                        snackBarText,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                backgroundColor: const Color(0xFF2D7D76),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } catch (e) {
          debugPrint('[_MushafScreenState] _handleExit save error: $e');
        }
        if (mounted) {
          await _promptSecdeDebtIfNeeded();
          if (mounted) {
            Navigator.of(context).pop();
          }
        }
        return;
      } else if (shouldSave == null && mounted) {
        await _promptSecdeDebtIfNeeded();
        if (mounted) {
          Navigator.of(context).pop();
        }
        return;
      }
    } else {
      final delta = (currentPage - _startPage).clamp(0, 605);
      if (delta > 0) {
        final prefs = await SharedPreferences.getInstance();
        final activeSession = ref.read(activeSessionProvider);
        final isDefault = activeSession.id == UserSession.defaultSessionId;
        final sfx = isDefault ? '' : '_${activeSession.id}';
        final todayStr =
            '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';

        final curTodayKey = isDefault
            ? 'TodayReadPages_$todayStr'
            : 'TodayReadPages_${todayStr}_${activeSession.id}';
        final curToday = prefs.getInt(curTodayKey) ?? 0;
        await prefs.setInt(curTodayKey, curToday + delta);
        if (isDefault) {
          await prefs.setInt('TodayReadPages_$todayStr', curToday + delta);
        }

        final totalKey = isDefault
            ? 'TotalReadQuranPages'
            : 'TotalReadQuranPages_${activeSession.id}';
        final curTotal = prefs.getInt(totalKey) ??
            (isDefault ? prefs.getInt('TotalReadQuranPages') ?? 0 : 0);
        await prefs.setInt(totalKey, curTotal + delta);
        if (isDefault) {
          await prefs.setInt('TotalReadQuranPages', curTotal + delta);
        }

        await prefs.setString('LastReadDate$sfx', todayStr);
        if (isDefault) {
          await prefs.setString('LastReadDate', todayStr);
          await prefs.setString('last_read_date', todayStr);
        }

        final db = ref.read(databaseProvider);
        await DailyStreakService.recordDailyActivity(db);

        // Award gold for pages read (+10 Gold per page)
        await ref.read(gamificationNotifierProvider).addGold(delta * 10);

        // Check if daily Quran page goal is newly reached today
        final kuranGoal = PrefUtils.getIntFromKeys(prefs, ['DailyQuranGoal$sfx', 'KuranDailyGoal$sfx', 'DailyQuranGoal', 'KuranDailyGoal'], 5);
        final claimedQuranGoalKey = 'DailyQuranRewardClaimed_$todayStr$sfx';
        final alreadyClaimedQuran = prefs.getBool(claimedQuranGoalKey) ?? (isDefault ? prefs.getBool('DailyQuranRewardClaimed_$todayStr') ?? false : false);
        if (!alreadyClaimedQuran && (curToday + delta) >= kuranGoal) {
          await prefs.setBool(claimedQuranGoalKey, true);
          if (isDefault) await prefs.setBool('DailyQuranRewardClaimed_$todayStr', true);
          await ref.read(gamificationNotifierProvider).addGold(25);
          ref.read(celebrationProvider.notifier).trigger(
            CelebrationEvent.dailyGoalCompleted(
              goalTitle: 'Günlük $kuranGoal Sayfa Kur\'an Hedefi Tamamlandı! (+25 🪙)',
            ),
          );
        }

        ref.read(badgeRefreshTriggerProvider.notifier).state++;
        CloudSyncEngine.instance
            .triggerDebouncedSync(ref, delay: const Duration(seconds: 1));
      }
      if (mounted) {
        await _promptSecdeDebtIfNeeded();
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    }
  }

  void _handleSurahCompleted(SureItem surah) async {
    final activeSession = ref.read(activeSessionProvider);
    final hasCustom = await CustomBadgeService.hasCustomBadgeForSurah(surah.id, activeSession.id);
    const builtInSurahIds = [18, 36, 48, 55, 56, 67, 78, 112, 113, 114];
    final hasBuiltIn = builtInSurahIds.contains(surah.id);

    if (!hasCustom && !hasBuiltIn && mounted) {
      final shouldCreate = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final cardBg = isDark ? const Color(0xFF1E2129) : Colors.white;
          final textColor = isDark ? const Color(0xFFE8DDD0) : const Color(0xFF1E2B27);
          final subColor = isDark ? const Color(0xFFA89888) : const Color(0xFF506861);

          return AlertDialog(
            backgroundColor: cardBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              children: [
                const Text('🎉 ', style: TextStyle(fontSize: 22)),
                Expanded(
                  child: Text(
                    '${surah.name} Sûresi Tamamlandı',
                    style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: textColor),
                  ),
                ),
              ],
            ),
            content: Text(
              'Mâşâallâh! Bu sure için rozet kartı oluşturup okumalarınızı takip etmek ister misiniz?',
              style: TextStyle(fontSize: 13.5, color: subColor, height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text('Şimdilik Değil', style: TextStyle(color: subColor, fontWeight: FontWeight.w600)),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D7D76),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Rozet Oluştur', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      );

      if (shouldCreate == true && mounted) {
        await AddCustomQuranBadgeSheet.show(
          context,
          initialSurahId: surah.id,
          onBadgeCreated: () {
            ref.read(badgeRefreshTriggerProvider.notifier).state++;
          },
        );
      }
    }

    setState(() {
      _hasMarkedAsRead = true;
      _completedSurahIdsInSession.add(surah.id);
    });
    HapticService.targetReached();

    final result = await ref
        .read(gamificationNotifierProvider)
        .recordSurahReadingCompleted(
          surah: surah,
          streakKey: widget.streakKey,
        );

    if (!mounted) return;

    // Show celebration modal
    await showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final cardBg = isDark ? const Color(0xFF1E2129) : Colors.white;
        final textColor =
            isDark ? const Color(0xFFE8DDD0) : const Color(0xFF1E2B27);
        final subColor =
            isDark ? const Color(0xFFA89888) : const Color(0xFF506861);

        return Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            bottom: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('🌟', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 12),
                Text(
                  'Tebrikler! Mâşâallâh',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${surah.name} Sûresi tilavetiniz başarıyla kaydedildi.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: subColor),
                ),
                const SizedBox(height: 20),

                // Rewards Card
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D7D76).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: const Color(0xFF2D7D76).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          const Text('⚡', style: TextStyle(fontSize: 22)),
                          const SizedBox(height: 4),
                          Text(
                            '+${result.xpGained} XP',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2D7D76),
                            ),
                          ),
                          Text('Kazanıldı',
                              style: TextStyle(fontSize: 11, color: subColor)),
                        ],
                      ),
                      if (result.readCount > 0) ...[
                        Container(
                            width: 1,
                            height: 36,
                            color: Colors.grey.withValues(alpha: 0.3)),
                        Column(
                          children: [
                            const Text('📖', style: TextStyle(fontSize: 22)),
                            const SizedBox(height: 4),
                            Text(
                              '${result.readCount}/40 Okuma',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2D7D76),
                              ),
                            ),
                            Text('Toplam Okuma',
                                style:
                                    TextStyle(fontSize: 11, color: subColor)),
                          ],
                        ),
                      ],
                      if (result.currentStreak > 1) ...[
                        Container(
                            width: 1,
                            height: 36,
                            color: Colors.grey.withValues(alpha: 0.3)),
                        Column(
                          children: [
                            const Text('🔥', style: TextStyle(fontSize: 22)),
                            const SizedBox(height: 4),
                            Text(
                              '${result.currentStreak} Gün',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFD97706),
                              ),
                            ),
                            Text('Günlük Seri',
                                style:
                                    TextStyle(fontSize: 11, color: subColor)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                if (result.isBadgeUnlocked &&
                    result.unlockedBadgeName != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color:
                              const Color(0xFFD97706).withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Text('🏆 ', style: TextStyle(fontSize: 22)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Yeni Rozet Açıldı!',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFD97706),
                                ),
                              ),
                              Text(
                                result.unlockedBadgeName!,
                                style:
                                    TextStyle(fontSize: 12, color: textColor),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () async {
                          Navigator.of(ctx).pop();
                          await _promptSecdeDebtIfNeeded();
                          if (mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                        child: const Text('Tamamla & Çık',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2D7D76),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Okumaya Devam',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (mounted) {
      _hideReadBannerTimer?.cancel();
      _hideReadBannerTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _hideReadBanner = true;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentPage = ref.watch(currentMushafPageProvider);
    final pageAsync = ref.watch(quranPageDataProvider(currentPage));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final scaffoldBg =
        isDark ? const Color(0xFF101216) : const Color(0xFFFBF8F1);
    final titleColor = isDark ? Colors.white : const Color(0xFF1E2B27);
    final subtitleColor =
        isDark ? const Color(0xFF8A9BAE) : const Color(0xFF6B7280);
    final iconColor = isDark ? Colors.white70 : const Color(0xFF1E2B27);
    final goldColor = isDark ? AppColors.gold400 : const Color(0xFFB57D15);

    final audioState = ref.watch(kuranAudioNotifierProvider);
    final isAudioActive = audioState.isBarVisible;

    // Detect effective surah ending on this page
    SureItem? detectedSurah;
    if (widget.targetSurah != null) {
      detectedSurah = widget.targetSurah;
    } else {
      pageAsync.whenData((data) {
        for (final ayat in data.quranAyats) {
          final s = SurahDataProvider.surahs
              .where((item) => item.id == ayat.sureId)
              .firstOrNull;
          if (s != null && ayat.ayetId == s.ayetSayisi) {
            detectedSurah = s;
            break;
          }
        }
      });
    }

    final effectiveSurah = detectedSurah;
    final bool isSurahEnd = effectiveSurah != null &&
        pageAsync.maybeWhen(
          data: (data) =>
              data.quranAyats.any((a) =>
                  a.sureId == effectiveSurah.id &&
                  a.ayetId == effectiveSurah.ayetSayisi) ||
              currentPage >=
                  SurahDataProvider.getSurahEndPage(effectiveSurah.id),
          orElse: () =>
              currentPage >=
              SurahDataProvider.getSurahEndPage(effectiveSurah.id),
        );
    final bool isMarkedAsRead = effectiveSurah != null &&
        (_completedSurahIdsInSession.contains(effectiveSurah.id) ||
            (widget.targetSurah != null &&
                widget.targetSurah!.id == effectiveSurah.id &&
                _hasMarkedAsRead));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleExit();
      },
      child: Scaffold(
        backgroundColor: scaffoldBg,
        appBar: AppBar(
          backgroundColor: scaffoldBg,
          elevation: 0,
          scrolledUnderElevation: 0,
          iconTheme: IconThemeData(color: iconColor),
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: iconColor),
            tooltip: 'Geri',
            onPressed: _handleExit,
          ),
          title: pageAsync.when(
            data: (data) => Column(
              children: [
                Text(
                  '${data.mealSureLabel} • Cüz ${data.cuzNo}',
                  style: AppTypography.headingSmall(color: titleColor),
                ),
                Text(
                  'Sayfa ${data.pageNo} / 605',
                  style: TextStyle(color: subtitleColor, fontSize: 12),
                ),
              ],
            ),
            loading: () =>
                Text('Kur’ân-ı Kerîm', style: TextStyle(color: titleColor)),
            error: (_, __) =>
                Text('Kur’ân-ı Kerîm', style: TextStyle(color: titleColor)),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.search_rounded, color: iconColor),
              tooltip: 'Âyet Ara',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const QuranSearchScreen()),
                );
              },
            ),
            IconButton(
              icon: Icon(Icons.menu_book_rounded, color: goldColor),
              tooltip: 'Fihrist & Cüzler',
              onPressed: () async {
                final selectedPage = await Navigator.of(context).push<int>(
                  MaterialPageRoute(
                      builder: (_) => const SurahJuzIndexScreen()),
                );
                if (selectedPage != null &&
                    selectedPage >= 1 &&
                    selectedPage <= 605) {
                  ref.read(currentMushafPageProvider.notifier).state =
                      selectedPage;
                  _pageController.jumpToPage(selectedPage - 1);
                }
              },
            ),
            IconButton(
              icon: Icon(Icons.skip_next_rounded, color: iconColor),
              tooltip: 'Sayfaya Git',
              onPressed: () => _showJumpToPageDialog(context, isDark),
            ),
          ],
        ),
        body: Focus(
          focusNode: _focusNode,
          autofocus: true,
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent) {
              // Arapça Mushaf RTL olduğu için Sol Ok -> Sonraki Sayfa (İleri), Sağ Ok -> Önceki Sayfa (Geri)
              if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
                  event.logicalKey == LogicalKeyboardKey.pageDown ||
                  event.logicalKey == LogicalKeyboardKey.space) {
                _goToNextPage();
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
                  event.logicalKey == LogicalKeyboardKey.pageUp) {
                _goToPreviousPage();
                return KeyEventResult.handled;
              }
            }
            return KeyEventResult.ignored;
          },
          child: Stack(
            children: [
              // 605 PageView (RTL Swiping for Quran reading)
              PageView.builder(
                controller: _pageController,
                reverse: true, // Right-to-Left standard for Arabic Mushaf
                itemCount: 605,
                onPageChanged: (pageIndex) {
                  final newPage = pageIndex + 1;
                  if (_hideReadBanner) {
                    _hideReadBanner = false;
                  }
                  ref.read(currentMushafPageProvider.notifier).state = newPage;
                  if (TilavetSecdesiData.isSecdePage(newPage)) {
                    _encounteredSecdePages.add(newPage);
                    if (_lastBannerPage != newPage) {
                      setState(() {
                        _lastBannerPage = newPage;
                        _dismissedBannerForCurrentPage = false;
                        _showDebtReminderBanner = false;
                      });
                    }
                  }
                },
                itemBuilder: (context, index) {
                  final pageNum = index + 1;
                  final pageDataAsync =
                      ref.watch(quranPageDataProvider(pageNum));

                  return pageDataAsync.when(
                    data: (data) => MushafPageWidget(pageData: data),
                    loading: () => Center(
                      child: CircularProgressIndicator(color: goldColor),
                    ),
                    error: (err, _) => Center(
                      child: Text('Sayfa yüklenemedi: $err',
                          style: const TextStyle(color: Colors.red)),
                    ),
                  );
                },
              ),

              // Floating Tilâvet Secdesi Banner & Debt Reminder
              if (TilavetSecdesiData.getSecdeForPage(currentPage) != null &&
                  !_dismissedBannerForCurrentPage)
                Positioned(
                  top: 6,
                  left: 0,
                  right: 0,
                  child: TilavetSecdesiFloatingBanner(
                    secdeItem:
                        TilavetSecdesiData.getSecdeForPage(currentPage)!,
                    onDismiss: () {
                      setState(() {
                        _dismissedBannerForCurrentPage = true;
                      });
                    },
                  ),
                ),

              if (_showDebtReminderBanner &&
                  TilavetSecdesiData.getSecdeForPage(currentPage) == null &&
                  ref.watch(tilavetSecdesiDebtProvider) > 0)
                Positioned(
                  top: 6,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: (isDark
                              ? const Color(0xFF2C2216)
                              : const Color(0xFFFFF8E7))
                          .withValues(alpha: 0.96),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: const Color(0xFFD97706), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          TilavetSecdesiGuideSheet.show(context);
                        },
                        child: Row(
                          children: [
                            const Text('📌 ',
                                style: TextStyle(fontSize: 16)),
                            Expanded(
                              child: Text(
                                '${ref.watch(tilavetSecdesiDebtProvider)} adet tilâvet secdesi borcunuz bulunuyor.',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? const Color(0xFFFFD56B)
                                      : const Color(0xFF8C5400),
                                ),
                              ),
                            ),
                            Text(
                              'Rehber →',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF8C5400),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _showDebtReminderBanner = false;
                                });
                              },
                              child: Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: isDark
                                    ? Colors.white70
                                    : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // Floating "Sureyi Okudum" Action Button (at the end of the surah)
              // Hatim ve Mukabele modlarında genel hedef hatim tamamlamak olduğu için sûre okundu butonu gösterilmez
              if (widget.activeHatim == null && effectiveSurah != null && isSurahEnd && (!isMarkedAsRead || !_hideReadBanner))
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: isAudioActive ? 84 : 20,
                  child: SafeArea(
                    top: false,
                    child: AnimatedOpacity(
                      opacity: 1.0,
                      duration: const Duration(milliseconds: 300),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: isMarkedAsRead
                              ? const LinearGradient(
                                  colors: [
                                    Color(0xFF0F766E),
                                    Color(0xFF047857)
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : const LinearGradient(
                                  colors: [
                                    Color(0xFF0D4335),
                                    Color(0xFF156651)
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isMarkedAsRead
                                ? const Color(0xFF34D399)
                                : const Color(0xFFD4AF37),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (isMarkedAsRead
                                      ? const Color(0xFF0F766E)
                                      : const Color(0xFF0D4335))
                                  .withValues(alpha: 0.45),
                              blurRadius: 16,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              if (!isMarkedAsRead) {
                                _handleSurahCompleted(effectiveSurah);
                              } else {
                                HapticService.tapClick();
                              }
                            },
                            borderRadius: BorderRadius.circular(24),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 13),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    isMarkedAsRead ? '✓' : '✨',
                                    style: const TextStyle(
                                        fontSize: 18, color: Colors.white),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    isMarkedAsRead
                                        ? '${effectiveSurah.name} Sûresi Okundu'
                                        : '${effectiveSurah.name} Sûresini Okudum',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  if (!isMarkedAsRead) ...[
                                    const SizedBox(width: 8),
                                    const Icon(Icons.check_circle_rounded,
                                        color: AppColors.gold300, size: 20),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // Floating Bottom Audio Player
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: AudioSyncPlayerBar(),
              ),

              // Masaüstü İleri / Geri Sayfa Butonları (Sol: Sonraki, Sağ: Önceki)
              if (isDesktopMushafPlatform && currentPage < 605)
                Positioned(
                  left: 14,
                  top: 0,
                  bottom: isAudioActive ? 74 : 0,
                  child: Center(
                    child: DesktopMushafNavButton(
                      icon: Icons.chevron_left_rounded,
                      tooltip: 'Sonraki Sayfa (Sol Ok)',
                      onPressed: _goToNextPage,
                      isDark: isDark,
                    ),
                  ),
                ),
              if (isDesktopMushafPlatform && currentPage > 1)
                Positioned(
                  right: 14,
                  top: 0,
                  bottom: isAudioActive ? 74 : 0,
                  child: Center(
                    child: DesktopMushafNavButton(
                      icon: Icons.chevron_right_rounded,
                      tooltip: 'Önceki Sayfa (Sağ Ok)',
                      onPressed: _goToPreviousPage,
                      isDark: isDark,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showJumpToPageDialog(BuildContext context, bool isDark) {
    final controller = TextEditingController();
    final cardBg = isDark ? AppColors.darkCard : const Color(0xFFFFFDF8);
    final textColor = isDark ? Colors.white : const Color(0xFF1E2B27);
    final borderColor = isDark ? AppColors.darkBorder : const Color(0xFFE2DDD2);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Sayfaya Git (1 - 605)',
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            hintText: 'Sayfa Numarası (1-605)',
            hintStyle: const TextStyle(color: Color(0xFF8A9BAE)),
            filled: true,
            fillColor:
                isDark ? AppColors.darkBackground : const Color(0xFFF4EFE6),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: borderColor),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('İptal',
                style: TextStyle(
                    color: isDark ? Colors.white60 : const Color(0xFF6B7280))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isDark ? AppColors.gold500 : AppColors.emerald700,
              foregroundColor: isDark ? Colors.black : Colors.white,
            ),
            onPressed: () {
              final p = int.tryParse(controller.text.trim());
              if (p != null && p >= 1 && p <= 605) {
                ref.read(currentMushafPageProvider.notifier).state = p;
                _pageController.jumpToPage(p - 1);
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('Git',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
