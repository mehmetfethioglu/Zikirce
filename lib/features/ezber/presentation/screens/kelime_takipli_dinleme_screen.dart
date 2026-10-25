import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../../../../core/constants/surah_data_provider.dart';
import '../../../../core/services/audio_download_service.dart';
import '../../../../core/services/audio_sync_service.dart';
import '../../../../core/services/ios_now_playing_service.dart';
import '../../../../core/services/quran_page_repository.dart';
import '../../../../core/utils/quran_word_highlighter.dart';
import '../../../kuran/presentation/widgets/besmele_playback_banner.dart';
import '../../../kuran/presentation/widgets/zikirce_ayah_stop_marker.dart';
import '../../../kuran/providers/kuran_providers.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../../core/session/session_providers.dart';
import '../../../gamification/providers/gamification_providers.dart';
import '../../../gamification/services/custom_badge_service.dart';
import '../../../kuran/presentation/widgets/add_custom_quran_badge_sheet.dart';
import '../../../zikir/presentation/widgets/zikir_share_card_widget.dart';
import '../../../zikir/presentation/widgets/zikir_share_preview_modal.dart';

enum TalimTargetType { page, surah, juz, ashr }

class _CleanWordInfo {
  final String pureWord;
  final List<String> stops;
  const _CleanWordInfo({required this.pureWord, required this.stops});
}

class _PlaylistItemMeta {
  final int verseIndex;
  final bool isBesmele;
  final int repeatIteration;

  const _PlaylistItemMeta({
    required this.verseIndex,
    required this.isBesmele,
    this.repeatIteration = 0,
  });
}

class TalimSelectionResult {
  final TalimTargetType type;
  final int id; // pageNumber, surahId, or juzNumber
  final String title;
  final int? startAyah;
  final int? endAyah;
  final String? customTitle;

  const TalimSelectionResult({
    required this.type,
    required this.id,
    required this.title,
    this.startAyah,
    this.endAyah,
    this.customTitle,
  });
}

class KelimeTakipliDinlemeScreen extends ConsumerStatefulWidget {
  final TalimTargetType targetType;
  final int targetId; // Page: 1-604, Surah: 1-114, Juz: 1-30
  final int initialVerseIndex;
  final int? startAyah;
  final int? endAyah;
  final String? customTitle;

  const KelimeTakipliDinlemeScreen({
    super.key,
    required this.targetType,
    required this.targetId,
    this.initialVerseIndex = 0,
    this.startAyah,
    this.endAyah,
    this.customTitle,
  });

  @override
  ConsumerState<KelimeTakipliDinlemeScreen> createState() =>
      _KelimeTakipliDinlemeScreenState();
}

class _KelimeTakipliDinlemeScreenState
    extends ConsumerState<KelimeTakipliDinlemeScreen> {
  final AudioPlayer _player = AudioPlayer();
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _verseKeys = {};
  final GlobalKey _activeWordKey = GlobalKey();

  bool _isLoading = true;
  List<QuranAyatModel> _verses = [];
  Map<String, String> _meals = {}; // key: "surahId_ayahId" -> meal text
  List<_PlaylistItemMeta> _playlistItems = [];

  int _currentVerseIndex = 0;
  int _activeWordOrder = 0;
  bool _isPlaying = false;
  bool _isAudioBuffering = false;
  bool _isPlayingBesmele = false;
  double _playbackSpeed = 1.0;
  int _repeatMode = 1; // 1 = Once, 3 = 3x, 5 = 5x, 0 = Infinite for current ayah
  bool _isScopeLoopEnabled = false; // Loop whole Surah/Juz/Ashr/Page when finished
  bool _autoAdvancePage = true; // Auto advance to next page in Page mode
  late int _currentPageId;
  bool _showMeal = true;
  bool _maskingMode = false; // Ezber için henüz okunmayan kelimeleri gizleme
  double _fontSize = 26.0;
  bool _isBatchDownloading = false;
  bool _isCurrentScopeDownloaded = false;
  bool _hasMarkedSurahAsCompleted = false;
  int _lastHandledQueueIndex = -1;
  int _queueGeneration = 0;
  bool _isAdvancingWindowsItem = false;
  DateTime _lastQueueTransitionTime = DateTime.fromMillisecondsSinceEpoch(0);
  final Stopwatch _verseStopwatch = Stopwatch();
  double _verseSeekAnchorMs = 0.0;
  Timer? _wordSyncTimer;

  StreamSubscription? _posSub;
  StreamSubscription? _playerStateSub;
  StreamSubscription<int?>? _currentIndexSub;

  @override
  void initState() {
    super.initState();
    _currentPageId = widget.targetId;
    _fontSize = ref.read(quranFontSizeProvider);
    IosNowPlayingService.setRemoteCommandCallback(_handleRemoteCommand);
    _initDataAndPlayer();
  }

  void _handleRemoteCommand(String cmd) {
    if (!mounted) return;
    switch (cmd) {
      case 'play':
        if (!_isPlaying) _togglePlayPause();
        break;
      case 'pause':
        if (_isPlaying) _togglePlayPause();
        break;
      case 'togglePlayPause':
        _togglePlayPause();
        break;
      case 'next':
        if (!_isPlayingBesmele && _currentVerseIndex < _verses.length - 1) {
          _goToVerse(_currentVerseIndex + 1);
        }
        break;
      case 'previous':
        if (!_isPlayingBesmele && _currentVerseIndex > 0) {
          _goToVerse(_currentVerseIndex - 1);
        }
        break;
    }
  }

  Future<void> _initDataAndPlayer() async {
    await AudioSyncService.initialize();
    await _loadVerses();
    _checkScopeDownloaded();
    _initAudioListeners();

    if (_verses.isNotEmpty) {
      final startIndex = widget.initialVerseIndex.clamp(0, _verses.length - 1);
      _currentVerseIndex = startIndex;
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        await _buildAndPlayQueue(
          _currentVerseIndex,
          includeInitialBesmele: true,
        );
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadVerses() async {
    final loadedVerses = <QuranAyatModel>[];
    final loadedMeals = <String, String>{};

    try {
      if (widget.targetType == TalimTargetType.page) {
        final pageData = await QuranPageRepository.getPage(_currentPageId);
        loadedVerses.addAll(pageData.quranAyats);
        for (final m in pageData.mealAyats) {
          loadedMeals['${m.sureId}_${m.ayetId}'] = m.ayetText;
        }
      } else if (widget.targetType == TalimTargetType.surah) {
        final (startPage, endPage) = SurahDataProvider.getSurahDiyanetPageRange(widget.targetId);

        for (int p = startPage; p <= endPage; p++) {
          final pData = await QuranPageRepository.getPage(p);
          for (final a in pData.quranAyats) {
            if (a.sureId == widget.targetId) {
              if (!loadedVerses.any((v) => v.sureId == a.sureId && v.ayetId == a.ayetId)) {
                loadedVerses.add(a);
              }
            }
          }
          for (final m in pData.mealAyats) {
            if (m.sureId == widget.targetId) {
              loadedMeals['${m.sureId}_${m.ayetId}'] = m.ayetText;
            }
          }
        }
      } else if (widget.targetType == TalimTargetType.juz) {
        final (startPage, endPage) = AudioSyncService.getJuzPageRange(widget.targetId);
        for (int p = startPage; p <= endPage; p++) {
          final pData = await QuranPageRepository.getPage(p);
          for (final a in pData.quranAyats) {
            if (!loadedVerses.any((v) => v.sureId == a.sureId && v.ayetId == a.ayetId)) {
              loadedVerses.add(a);
            }
          }
          for (final m in pData.mealAyats) {
            loadedMeals['${m.sureId}_${m.ayetId}'] = m.ayetText;
          }
        }
      } else if (widget.targetType == TalimTargetType.ashr) {
        final startAyah = widget.startAyah ?? 1;
        final endAyah = widget.endAyah ?? 999;
        final (startPage, endPage) = SurahDataProvider.getSurahDiyanetPageRange(widget.targetId);

        for (int p = startPage; p <= endPage; p++) {
          final pData = await QuranPageRepository.getPage(p);
          for (final a in pData.quranAyats) {
            if (a.sureId == widget.targetId && a.ayetId >= startAyah && a.ayetId <= endAyah) {
              if (!loadedVerses.any((v) => v.sureId == a.sureId && v.ayetId == a.ayetId)) {
                loadedVerses.add(a);
              }
            }
          }
          for (final m in pData.mealAyats) {
            if (m.sureId == widget.targetId && m.ayetId >= startAyah && m.ayetId <= endAyah) {
              loadedMeals['${m.sureId}_${m.ayetId}'] = m.ayetText;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[KelimeTakipliDinlemeScreen] Error loading verses: $e');
    }

    _verses = loadedVerses;
    _meals = loadedMeals;
    _verseKeys.clear();
    for (int i = 0; i < _verses.length; i++) {
      _verseKeys[i] = GlobalKey();
    }
  }

  void _resetVerseClock({int seekMs = 0, bool isPlaying = true}) {
    _verseSeekAnchorMs = seekMs.toDouble();
    _verseStopwatch.reset();
    final isReady = _player.processingState == ProcessingState.ready;
    if (isPlaying && !_isAudioBuffering && isReady) {
      _verseStopwatch.start();
    }
  }

  double _currentEffectivePositionMs() {
    if (_player.processingState == ProcessingState.loading ||
        _player.processingState == ProcessingState.buffering ||
        _player.processingState == ProcessingState.idle) {
      return _verseSeekAnchorMs;
    }

    final stopwatchMs = _verseSeekAnchorMs +
        (_verseStopwatch.elapsedMilliseconds * _playbackSpeed);
    final playerMs = _player.position.inMilliseconds.toDouble();
    final timeSinceTransitionMs =
        DateTime.now().difference(_lastQueueTransitionTime).inMilliseconds;

    // Handle LoopMode.one wrap-around when repeating a single verse
    if ((_repeatMode == 0 || _isScopeLoopEnabled) &&
        stopwatchMs > 1800 &&
        playerMs >= 0 &&
        playerMs < 600 &&
        timeSinceTransitionMs > 1500) {
      _verseSeekAnchorMs = playerMs;
      _verseStopwatch.reset();
      if (_isPlaying && !_isAudioBuffering) {
        _verseStopwatch.start();
      }
      return playerMs;
    }

    if (!Platform.isWindows) {
      if (timeSinceTransitionMs < 350 && playerMs > 1200 && _verseSeekAnchorMs == 0) {
        return 0.0;
      }
      return playerMs.clamp(0.0, 600000.0);
    }

    if (timeSinceTransitionMs < 350 && playerMs > stopwatchMs + 300) {
      return stopwatchMs.clamp(0.0, 600000.0);
    }
    if ((playerMs - stopwatchMs).abs() <= 280 && playerMs >= 0) {
      return playerMs;
    }
    return stopwatchMs.clamp(0.0, 600000.0);
  }

  void _applyQueueIndexTransition(int qIdx) {
    if (qIdx < 0 || qIdx >= _playlistItems.length || qIdx == _lastHandledQueueIndex) {
      return;
    }
    _lastHandledQueueIndex = qIdx;
    _lastQueueTransitionTime = DateTime.now();
    final meta = _playlistItems[qIdx];
    final prevVerseIndex = _currentVerseIndex;
    final wasPlayingBesmele = _isPlayingBesmele;
    _isPlayingBesmele = meta.isBesmele;
    _currentVerseIndex = meta.verseIndex;
    _resetVerseClock(seekMs: 0, isPlaying: _player.playing);

    if (mounted) {
      setState(() {
        _activeWordOrder = meta.isBesmele ? 0 : 1;
      });
    }

    if (!meta.isBesmele && (prevVerseIndex != _currentVerseIndex || wasPlayingBesmele)) {
      _scrollToActiveVerse();
      _prefetchUpcomingVerses(_currentVerseIndex);
    }
    _syncNowPlaying();
  }

  void _tickWordSync() {
    if (!mounted) return;
    if (!Platform.isWindows) {
      final currentQIdx = _player.currentIndex;
      if (currentQIdx != null && currentQIdx != _lastHandledQueueIndex) {
        _applyQueueIndexTransition(currentQIdx);
      }
    }
    if (_isPlayingBesmele) {
      // 1_1.mp3 speech finishes at 6270ms ("er-Rahîm"); trim only trailing silence after 6380ms
      final besmeleMs = _currentEffectivePositionMs();
      if (besmeleMs >= 6380 &&
          _lastHandledQueueIndex >= 0 &&
          _lastHandledQueueIndex + 1 < _playlistItems.length) {
        final nextIdx = _lastHandledQueueIndex + 1;
        if (Platform.isWindows) {
          if (!_isAdvancingWindowsItem) {
            _isAdvancingWindowsItem = true;
            unawaited(_playWindowsSingleQueueItem(nextIdx));
          }
        } else if (_player.hasNext) {
          _applyQueueIndexTransition(nextIdx);
          unawaited(_player.seek(Duration.zero, index: nextIdx));
        }
      }
      return;
    }
    if (!_isPlaying && !_player.playing) return;
    if (_verses.isEmpty || _currentVerseIndex >= _verses.length) return;

    final currentVerse = _verses[_currentVerseIndex];
    final ms = _currentEffectivePositionMs();
    final wordCount = _parseAyahWords(currentVerse.ayetText).length;

    final activeWord = AudioSyncService.getActiveWordOrder(
      currentVerse.sureId,
      currentVerse.ayetId,
      ms,
      renderedWordCount: wordCount,
    );

    if (activeWord != _activeWordOrder && mounted) {
      setState(() {
        _activeWordOrder = activeWord;
      });
      _scrollToActiveWord();
    }
  }

  void _initAudioListeners() {
    _currentIndexSub = _player.currentIndexStream.listen((qIdx) {
      if (Platform.isWindows || qIdx == null) return;
      _applyQueueIndexTransition(qIdx);
    });

    _posSub = _player
        .createPositionStream(
          steps: 1000,
          minPeriod: const Duration(milliseconds: 16),
          maxPeriod: const Duration(milliseconds: 24),
        )
        .listen((_) => _tickWordSync());

    _wordSyncTimer?.cancel();
    _wordSyncTimer = Timer.periodic(
      const Duration(milliseconds: 20),
      (_) => _tickWordSync(),
    );

    _playerStateSub = _player.playerStateStream.listen((state) {
      if (!mounted) return;
      final wasPlaying = _isPlaying;
      final isBuffering = state.processingState == ProcessingState.buffering ||
          state.processingState == ProcessingState.loading;
      final isReady = state.processingState == ProcessingState.ready;

      if (state.playing && isReady) {
        if (!_verseStopwatch.isRunning) {
          _verseStopwatch.start();
        }
      } else {
        if (_verseStopwatch.isRunning) {
          _verseStopwatch.stop();
        }
      }

      setState(() {
        _isPlaying = state.playing;
        _isAudioBuffering = isBuffering;
      });
      if (wasPlaying != state.playing) {
        _syncNowPlaying();
      }

      if (state.processingState == ProcessingState.completed) {
        if (Platform.isWindows) {
          if (!_isAdvancingWindowsItem &&
              _verseStopwatch.elapsedMilliseconds > 220) {
            _isAdvancingWindowsItem = true;
            if (_repeatMode == 0 && !_isPlayingBesmele) {
              unawaited(_playWindowsSingleQueueItem(_lastHandledQueueIndex));
            } else if (_lastHandledQueueIndex >= 0 &&
                _lastHandledQueueIndex + 1 < _playlistItems.length) {
              unawaited(_playWindowsSingleQueueItem(_lastHandledQueueIndex + 1));
            } else {
              _isAdvancingWindowsItem = false;
              _handlePlaylistCompleted();
            }
          }
        } else {
          final atLastQueueItem = _playlistItems.isEmpty ||
              ((_player.currentIndex ?? _lastHandledQueueIndex) >=
                  _playlistItems.length - 1);
          if (atLastQueueItem && _verseStopwatch.elapsedMilliseconds > 350) {
            _handlePlaylistCompleted();
          }
        }
      }
    });
  }

  void _syncNowPlaying() {
    if (_verses.isEmpty || _currentVerseIndex >= _verses.length) return;
    final verse = _verses[_currentVerseIndex];
    final surahName = verse.sure?.sureNameTurkish ?? '${verse.sureId}. Sûre';
    final title = _isPlayingBesmele
        ? 'Besmele-i Şerif ($surahName)'
        : '$surahName · ${verse.ayetId}. Âyet';
    IosNowPlayingService.updateNowPlaying(
      title: title,
      subtitle: 'Zikirce • ${_getScreenTitle()}',
      isPlaying: _isPlaying,
      durationMs: _player.duration?.inMilliseconds ?? 0,
      positionMs: _player.position.inMilliseconds,
      speed: _playbackSpeed,
    );
  }

  void _handlePlaylistCompleted() {
    if (_isScopeLoopEnabled) {
      _goToVerse(0);
    } else if (widget.targetType == TalimTargetType.page &&
        _autoAdvancePage &&
        _currentPageId < 604) {
      _loadAndPlayNextPage();
    } else {
      setState(() {
        _isPlaying = false;
        _isPlayingBesmele = false;
        _activeWordOrder = 0;
      });
      IosNowPlayingService.clearNowPlaying();
      if (widget.targetType == TalimTargetType.surah) {
        _handleSurahCompleted();
      }
    }
  }

  Future<void> _handleSurahCompleted() async {
    if (_hasMarkedSurahAsCompleted || widget.targetType != TalimTargetType.surah) return;

    final surah = SurahDataProvider.surahs
        .where((s) => s.id == widget.targetId)
        .firstOrNull;
    if (surah == null) return;

    final activeSession = ref.read(activeSessionProvider);
    final hasCustom = await CustomBadgeService.hasCustomBadgeForSurah(
        surah.id, activeSession.id);
    const builtInSurahIds = [18, 36, 48, 55, 56, 67, 78, 112, 113, 114];
    final hasBuiltIn = builtInSurahIds.contains(surah.id);

    if (!hasCustom && !hasBuiltIn && mounted) {
      final shouldCreate = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final cardBg = isDark ? const Color(0xFF1E2129) : Colors.white;
          final textColor =
              isDark ? const Color(0xFFE8DDD0) : const Color(0xFF1E2B27);
          final subColor =
              isDark ? const Color(0xFFA89888) : const Color(0xFF506861);

          return AlertDialog(
            backgroundColor: cardBg,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              children: [
                const Text('🎉 ', style: TextStyle(fontSize: 22)),
                Expanded(
                  child: Text(
                    '${surah.name} Sûresi Tamamlandı',
                    style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.bold,
                        color: textColor),
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
                child: Text('Şimdilik Değil',
                    style: TextStyle(
                        color: subColor, fontWeight: FontWeight.w600)),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9488),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Rozet Oluştur',
                    style: TextStyle(fontWeight: FontWeight.bold)),
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

    if (!mounted) return;
    setState(() {
      _hasMarkedSurahAsCompleted = true;
    });
    HapticService.targetReached();

    final result = await ref
        .read(gamificationNotifierProvider)
        .recordSurahReadingCompleted(surah: surah);

    if (!mounted) return;

    showModalBottomSheet(
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
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${surah.name} Sûresi kelime takipli dinleme & okuma kaydı başarıyla işlendi.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: subColor,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF262A34)
                        : const Color(0xFFF4F6F8),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF383D4D)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          const Text('📖', style: TextStyle(fontSize: 22)),
                          const SizedBox(height: 4),
                          Text(
                            '${result.readCount}/40 Okuma',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0D9488),
                            ),
                          ),
                          Text('Toplam Okuma',
                              style: TextStyle(fontSize: 11, color: subColor)),
                        ],
                      ),
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
                      Container(
                          width: 1,
                          height: 36,
                          color: Colors.grey.withValues(alpha: 0.3)),
                      Column(
                        children: [
                          const Text('✨', style: TextStyle(fontSize: 22)),
                          const SizedBox(height: 4),
                          Text(
                            '+${result.xpGained} XP',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          Text('Kazanılan Puan',
                              style: TextStyle(fontSize: 11, color: subColor)),
                        ],
                      ),
                    ],
                  ),
                ),
                if (result.isBadgeUnlocked && result.unlockedBadgeName != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFD97706), width: 1.2),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🏅', style: TextStyle(fontSize: 20)),
                        const SizedBox(width: 8),
                        Text(
                          'Yeni Rozet: ${result.unlockedBadgeName}!',
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFD97706),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D9488),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text(
                      'Tamam',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _loadAndPlayNextPage() async {
    if (_currentPageId >= 604) {
      setState(() => _isPlaying = false);
      IosNowPlayingService.clearNowPlaying();
      return;
    }
    await IosNowPlayingService.beginTransitionTask();
    _currentPageId++;
    setState(() {
      _isLoading = true;
      _activeWordOrder = 0;
    });
    await _loadVerses();
    _checkScopeDownloaded();
    if (_verses.isNotEmpty && mounted) {
      _currentVerseIndex = 0;
      setState(() => _isLoading = false);
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0.0);
      }
      await _buildAndPlayQueue(0, includeInitialBesmele: true);
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  bool _shouldPlayBesmeleForVerse(QuranAyatModel verse, {required bool isSessionStart}) {
    final isBesmeleEnabled = ref.read(settingsProvider).isPlayBesmeleOnStartEnabled;
    if (!isBesmeleEnabled) return false;

    // Surah 1 (Fatihah) 1st ayah is already Besmele
    if (verse.sureId == 1 && verse.ayetId == 1) return false;

    // Surah 9 (Tawbah) 1st ayah does NOT have Besmele
    if (verse.sureId == 9 && verse.ayetId == 1) return false;

    if (isSessionStart) return true;

    // In-session surah transition (new surah starts at verse 1, except Fatihah & Tawbah)
    if (verse.ayetId == 1 && verse.sureId != 1 && verse.sureId != 9) return true;

    return false;
  }

  AudioSource _createAyahAudioSource(
    String soundsDirPath,
    int surahId,
    int ayahId, {
    int? pageId,
    required bool useFallbackCdn,
  }) {
    final localPath = '$soundsDirPath${Platform.pathSeparator}audio_${surahId}_$ayahId.mp3';
    final localFile = File(localPath);
    if (AudioDownloadService.isValidDiyanetAudioFile(localFile)) {
      return AudioSource.file(localPath);
    }
    final url = AudioDownloadService.getDiyanetAudioUrl(
      surahId,
      ayahId,
      pageId: pageId,
    );
    return AudioSource.uri(Uri.parse(url));
  }

  void _prefetchUpcomingVerses(int fromVerseIndex) {
    for (int offset = 0; offset <= 3; offset++) {
      final idx = fromVerseIndex + offset;
      if (idx >= 0 && idx < _verses.length) {
        final v = _verses[idx];
        unawaited(AudioDownloadService.ensureVerseDownloaded(
          v.sureId,
          v.ayetId,
          pageId: v.page,
        ));
      }
    }
  }

  Future<void> _playWindowsSingleQueueItem(
    int qIdx, {
    int seekMs = 0,
    bool useFallbackCdn = false,
  }) async {
    if (qIdx < 0 || qIdx >= _playlistItems.length || _verses.isEmpty) {
      _isAdvancingWindowsItem = false;
      return;
    }

    final myGen = ++_queueGeneration;
    _isAdvancingWindowsItem = true;
    final meta = _playlistItems[qIdx];
    final prevVerseIndex = _currentVerseIndex;
    final wasPlayingBesmele = _isPlayingBesmele;

    _lastHandledQueueIndex = qIdx;
    _lastQueueTransitionTime = DateTime.now();
    _isPlayingBesmele = meta.isBesmele;
    _currentVerseIndex = meta.verseIndex;
    _resetVerseClock(seekMs: seekMs, isPlaying: false);

    if (mounted) {
      setState(() {
        _activeWordOrder = meta.isBesmele ? 0 : 1;
      });
    }

    try {
      final soundsDir = await AudioDownloadService.getSoundsDirectory();
      final soundsDirPath = soundsDir.path;
      final verse = _verses[meta.verseIndex];
      final targetSurah = meta.isBesmele ? 1 : verse.sureId;
      final targetAyah = meta.isBesmele ? 1 : verse.ayetId;
      final targetPage = meta.isBesmele ? 1 : verse.page;

      await AudioDownloadService.ensureVerseDownloaded(
        targetSurah,
        targetAyah,
        pageId: targetPage,
      ).timeout(const Duration(milliseconds: 1800), onTimeout: () => null);

      if (!mounted || myGen != _queueGeneration) return;

      final source = _createAyahAudioSource(
        soundsDirPath,
        targetSurah,
        targetAyah,
        pageId: targetPage,
        useFallbackCdn: useFallbackCdn,
      );

      await _player.setLoopMode(LoopMode.off);
      await _player.setAudioSource(
        source,
        initialPosition:
            seekMs > 0 ? Duration(milliseconds: seekMs) : Duration.zero,
      );

      if (!mounted || myGen != _queueGeneration) return;

      await _player.setSpeed(_playbackSpeed);
      _lastQueueTransitionTime = DateTime.now();
      _isAdvancingWindowsItem = false;
      _resetVerseClock(seekMs: seekMs, isPlaying: true);
      unawaited(_player.play());

      if (!meta.isBesmele &&
          (prevVerseIndex != _currentVerseIndex || wasPlayingBesmele)) {
        _scrollToActiveVerse();
        _prefetchUpcomingVerses(_currentVerseIndex);
      }
      _syncNowPlaying();
    } catch (e) {
      _isAdvancingWindowsItem = false;
      debugPrint('[KelimeTakipliDinlemeScreen] Windows single item error: $e');
      if (!useFallbackCdn && myGen == _queueGeneration) {
        await _playWindowsSingleQueueItem(
          qIdx,
          seekMs: seekMs,
          useFallbackCdn: true,
        );
      }
    }
  }

  Future<void> _buildAndPlayQueue(
    int startVerseIndex, {
    required bool includeInitialBesmele,
    int seekMs = 0,
    bool useFallbackCdn = false,
  }) async {
    if (_verses.isEmpty || startVerseIndex < 0 || startVerseIndex >= _verses.length) {
      return;
    }

    final myQueueGen = ++_queueGeneration;

    if (mounted) {
      setState(() {
        _isAudioBuffering = true;
        _activeWordOrder = 0;
      });
    }

    // Stop any conflicting background Quran player only if it is currently active
    try {
      if (ref.read(kuranAudioNotifierProvider).isPlaying) {
        await ref.read(kuranAudioNotifierProvider.notifier).stop();
      }
    } catch (_) {}

    await AudioSyncService.configureAudioSession();
    await IosNowPlayingService.beginTransitionTask();

    try {
      final soundsDir = await AudioDownloadService.getSoundsDirectory();
      final soundsDirPath = soundsDir.path;

      final startVerse = _verses[startVerseIndex];
      final startWantsBesmele = includeInitialBesmele &&
          seekMs == 0 &&
          _shouldPlayBesmeleForVerse(startVerse, isSessionStart: true);
      final preloadTasks = <Future<void>>[];
      if (startWantsBesmele) {
        preloadTasks.add(AudioDownloadService.ensureVerseDownloaded(1, 1, pageId: 1));
      }
      for (int offset = 0; offset < 6; offset++) {
        final idx = startVerseIndex + offset;
        if (idx < _verses.length) {
          final pv = _verses[idx];
          preloadTasks.add(AudioDownloadService.ensureVerseDownloaded(
            pv.sureId,
            pv.ayetId,
            pageId: pv.page,
          ));
        }
      }
      await Future.wait(preloadTasks).timeout(
        const Duration(milliseconds: 2200),
        onTimeout: () => const [],
      );

      if (!mounted || myQueueGen != _queueGeneration) return;

      final children = <AudioSource>[];
      final metas = <_PlaylistItemMeta>[];
      int initialQueueIndex = 0;

      final repeatCount = (_repeatMode == 3 || _repeatMode == 5) ? _repeatMode : 1;

      for (int i = 0; i < _verses.length; i++) {
        final v = _verses[i];
        final isStartVerse = (i == startVerseIndex);
        final wantBesmele = isStartVerse
            ? (includeInitialBesmele &&
                seekMs == 0 &&
                _shouldPlayBesmeleForVerse(v, isSessionStart: true))
            : _shouldPlayBesmeleForVerse(v, isSessionStart: false);

        int firstIdxForThisVerse = children.length;

        if (wantBesmele) {
          children.add(_createAyahAudioSource(
            soundsDirPath,
            1,
            1,
            pageId: 1,
            useFallbackCdn: useFallbackCdn,
          ));
          metas.add(_PlaylistItemMeta(
            verseIndex: i,
            isBesmele: true,
            repeatIteration: 0,
          ));
          unawaited(AudioDownloadService.ensureVerseDownloaded(1, 1, pageId: 1));
        }

        final firstAyahQueueIdx = children.length;
        for (int r = 0; r < repeatCount; r++) {
          children.add(_createAyahAudioSource(
            soundsDirPath,
            v.sureId,
            v.ayetId,
            pageId: v.page,
            useFallbackCdn: useFallbackCdn,
          ));
          metas.add(_PlaylistItemMeta(
            verseIndex: i,
            isBesmele: false,
            repeatIteration: r,
          ));
        }

        if (isStartVerse) {
          initialQueueIndex = (wantBesmele && seekMs == 0)
              ? firstIdxForThisVerse
              : firstAyahQueueIdx;
        }
      }

      _playlistItems = metas;
      _lastHandledQueueIndex = initialQueueIndex;
      _lastQueueTransitionTime = DateTime.now();
      final initialMeta = metas[initialQueueIndex];
      _isPlayingBesmele = initialMeta.isBesmele;
      _currentVerseIndex = initialMeta.verseIndex;

      if (mounted) {
        setState(() {});
      }

      if (Platform.isWindows) {
        await _playWindowsSingleQueueItem(
          initialQueueIndex,
          seekMs: seekMs,
          useFallbackCdn: useFallbackCdn,
        );
        return;
      }

      if (_repeatMode == 0) {
        await _player.setLoopMode(LoopMode.one);
      } else if (_isScopeLoopEnabled) {
        await _player.setLoopMode(LoopMode.all);
      } else {
        await _player.setLoopMode(LoopMode.off);
      }

      final playlist = ConcatenatingAudioSource(
        useLazyPreparation: true,
        children: children,
      );

      await _player.setAudioSource(
        playlist,
        initialIndex: initialQueueIndex,
        initialPosition:
            seekMs > 0 ? Duration(milliseconds: seekMs) : Duration.zero,
      );

      if (!mounted || myQueueGen != _queueGeneration) return;

      _lastHandledQueueIndex = initialQueueIndex;
      _lastQueueTransitionTime = DateTime.now();
      _isPlayingBesmele = initialMeta.isBesmele;
      _currentVerseIndex = initialMeta.verseIndex;
      _resetVerseClock(seekMs: seekMs, isPlaying: true);

      await _player.setSpeed(_playbackSpeed);
      unawaited(_player.play());
      _resetVerseClock(seekMs: seekMs, isPlaying: true);
      _syncNowPlaying();
      _scrollToActiveVerse();
      _prefetchUpcomingVerses(_currentVerseIndex);
    } catch (e) {
      debugPrint('[KelimeTakipliDinlemeScreen] Playlist playback error: $e');
      if (!useFallbackCdn && myQueueGen == _queueGeneration) {
        await _buildAndPlayQueue(
          startVerseIndex,
          includeInitialBesmele: includeInitialBesmele,
          seekMs: seekMs,
          useFallbackCdn: true,
        );
        return;
      }
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _isAudioBuffering = false;
        });
      }
    }
  }

  Future<void> _prepareAndPlayVerse(int verseIndex, {int seekMs = 0}) async {
    if (verseIndex < 0 || verseIndex >= _verses.length) return;

    // Seek directly within active native queue if already loaded
    if (_playlistItems.isNotEmpty) {
      final targetQIdx = _playlistItems.indexWhere(
        (m) => m.verseIndex == verseIndex && !m.isBesmele && m.repeatIteration == 0,
      );
      if (targetQIdx != -1) {
        if (Platform.isWindows) {
          await _playWindowsSingleQueueItem(targetQIdx, seekMs: seekMs);
          return;
        }
        if (_player.audioSource != null &&
            _player.processingState != ProcessingState.idle &&
            _player.processingState != ProcessingState.completed) {
          _lastHandledQueueIndex = targetQIdx;
          _lastQueueTransitionTime = DateTime.now();
          _isPlayingBesmele = false;
          _currentVerseIndex = verseIndex;
          _resetVerseClock(seekMs: seekMs, isPlaying: true);
          if (mounted) {
            setState(() {
              _activeWordOrder = 0;
            });
          }
          try {
            await _player.seek(
              seekMs > 0 ? Duration(milliseconds: seekMs) : Duration.zero,
              index: targetQIdx,
            );
            if (!_player.playing) {
              unawaited(_player.play());
            }
            _resetVerseClock(seekMs: seekMs, isPlaying: true);
            _syncNowPlaying();
            _scrollToActiveVerse();
            _prefetchUpcomingVerses(verseIndex);
            return;
          } catch (_) {}
        }
      }
    }

    await _buildAndPlayQueue(
      verseIndex,
      includeInitialBesmele: false,
      seekMs: seekMs,
    );
  }

  void _goToVerse(int index) {
    if (_isPlayingBesmele) return;
    if (index < 0 || index >= _verses.length) return;
    _prepareAndPlayVerse(index);
  }

  void _scrollToActiveVerse() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _verseKeys[_currentVerseIndex];
      if (key?.currentContext != null) {
        Scrollable.ensureVisible(
          key!.currentContext!,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutCubic,
          alignment: 0.0,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
        );
      }
    });
  }

  void _scrollToActiveWord() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _activeWordKey.currentContext;
      if (ctx != null) {
        final renderBox = ctx.findRenderObject() as RenderBox?;
        if (renderBox != null && renderBox.hasSize) {
          final wordOffset = renderBox.localToGlobal(Offset.zero);
          final screenHeight = MediaQuery.of(context).size.height;
          // Keep active word in comfortable reading zone (between 70px and screenHeight - 200px)
          if (wordOffset.dy < 70 || wordOffset.dy > screenHeight - 200) {
            Scrollable.ensureVisible(
              ctx,
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              alignment: 0.35,
            );
          }
        }
      }
    });
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      _verseStopwatch.stop();
      _player.pause();
    } else {
      if (_player.processingState == ProcessingState.completed ||
          _player.processingState == ProcessingState.idle) {
        _buildAndPlayQueue(_currentVerseIndex, includeInitialBesmele: false);
      } else {
        AudioSyncService.configureAudioSession();
        _verseStopwatch.start();
        _player.play();
      }
    }
  }

  void _cyclePlaybackSpeed() {
    const speeds = [0.75, 1.0, 1.25, 1.5];
    final nextIndex = (speeds.indexOf(_playbackSpeed) + 1) % speeds.length;
    final newSpeed = speeds[nextIndex];
    _verseSeekAnchorMs = _currentEffectivePositionMs();
    _verseStopwatch.reset();
    if (_isPlaying && !_isAudioBuffering) {
      _verseStopwatch.start();
    }
    setState(() {
      _playbackSpeed = newSpeed;
    });
    _player.setSpeed(newSpeed);
    _syncNowPlaying();
  }

  void _cycleRepeatMode() {
    // 1 -> 3 -> 5 -> 0 (Infinite) -> 1
    int nextRepeat = 1;
    if (_repeatMode == 1) {
      nextRepeat = 3;
    } else if (_repeatMode == 3) {
      nextRepeat = 5;
    } else if (_repeatMode == 5) {
      nextRepeat = 0;
    } else {
      nextRepeat = 1;
    }

    setState(() {
      _repeatMode = nextRepeat;
    });
    final currentPos = _player.position.inMilliseconds;
    _buildAndPlayQueue(
      _currentVerseIndex,
      includeInitialBesmele: false,
      seekMs: currentPos,
    );
  }

  void _onWordTapped(int verseIndex, int wordOrder) {
    if (_isPlayingBesmele) return;
    final verse = _verses[verseIndex];
    final ts = AudioSyncService.getWordTimestamp(verse.sureId, verse.ayetId, wordOrder);

    if (verseIndex == _currentVerseIndex && _player.duration != null) {
      if (ts != null) {
        final seekTarget = (ts.startTime - 25.0).clamp(0.0, 999999.0).toInt();
        _resetVerseClock(seekMs: seekTarget, isPlaying: true);
        setState(() {
          _activeWordOrder = wordOrder;
        });
        _player.seek(Duration(milliseconds: seekTarget));
        if (!_isPlaying) _player.play();
      }
    } else {
      final seekTarget = ts != null ? (ts.startTime - 25.0).clamp(0.0, 999999.0).toInt() : 0;
      _prepareAndPlayVerse(verseIndex, seekMs: seekTarget);
    }
  }

  Future<void> _checkScopeDownloaded() async {
    if (_verses.isEmpty) return;
    try {
      final dir = await AudioDownloadService.getSoundsDirectory();
      final allExist = _verses.every(
        (v) => AudioDownloadService.isAudioFileDownloaded(dir.path, v.sureId, v.ayetId),
      );
      if (mounted) {
        setState(() {
          _isCurrentScopeDownloaded = allExist;
        });
      }
    } catch (_) {}
  }

  Future<void> _handleDownloadCurrentScope() async {
    if (_verses.isEmpty) return;
    setState(() => _isBatchDownloading = true);

    final verseInfos = _verses.map((v) => VerseAudioInfo(
      pageId: v.page,
      surahId: v.sureId,
      ayahId: v.ayetId,
    )).toList();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${_getScreenTitle()} Diyanet sesleri indiriliyor...'),
        duration: const Duration(seconds: 2),
      ),
    );

    final success = await AudioDownloadService().downloadVerses(
      verses: verseInfos,
      title: _getScreenTitle(),
    );

    if (mounted) {
      setState(() {
        _isBatchDownloading = false;
        _isCurrentScopeDownloaded = success;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Tüm Diyanet sesleri başarıyla indirildi.' : 'İndirme tamamlanamadı.'),
          backgroundColor: success ? const Color(0xFF0D9488) : Colors.redAccent,
        ),
      );
    }
  }

  String _getScreenTitle() {
    if (widget.customTitle != null && widget.customTitle!.isNotEmpty) {
      return widget.customTitle!;
    }
    if (widget.targetType == TalimTargetType.page) {
      final juz = SurahDataProvider.getJuzForPage(_currentPageId);
      return 'Sayfa $_currentPageId • $juz. Cüz';
    } else if (widget.targetType == TalimTargetType.surah) {
      final surah = SurahDataProvider.surahs.firstWhere(
        (s) => s.id == widget.targetId,
        orElse: () => SurahDataProvider.surahs.first,
      );
      return '${surah.id}. ${surah.name} Sûresi (${surah.ayetSayisi} Âyet)';
    } else if (widget.targetType == TalimTargetType.juz) {
      return '${widget.targetId}. Cüz Dinleme Talimi';
    } else {
      // ashr
      final surah = SurahDataProvider.surahs.firstWhere(
        (s) => s.id == widget.targetId,
        orElse: () => SurahDataProvider.surahs.first,
      );
      final sAyah = widget.startAyah ?? 1;
      final eAyah = widget.endAyah ?? surah.ayetSayisi;
      return '${surah.name} Sûresi ($sAyah-$eAyah. Âyetler)';
    }
  }

  Widget _buildPageSeparator(int pageNumber, bool isDark, Color borderStroke) {
    final juz = SurahDataProvider.getJuzForPage(pageNumber);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(child: Divider(color: borderStroke, thickness: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E2631) : const Color(0xFFE6F4F1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? const Color(0xFF30363D) : const Color(0xFFB2DFDB),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('📄', style: TextStyle(fontSize: 11)),
                  const SizedBox(width: 6),
                  Text(
                    'Sayfa $pageNumber • $juz. Cüz',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: isDark ? const Color(0xFF5EEAD4) : const Color(0xFF0F766E),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(child: Divider(color: borderStroke, thickness: 1)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    IosNowPlayingService.setRemoteCommandCallback(null);
    IosNowPlayingService.clearNowPlaying();
    _wordSyncTimer?.cancel();
    _verseStopwatch.stop();
    _currentIndexSub?.cancel();
    _posSub?.cancel();
    _playerStateSub?.cancel();
    _player.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = isDark ? const Color(0xFF0D1117) : const Color(0xFFFAF8F2);
    final cardBg = isDark ? const Color(0xFF161B22) : const Color(0xFFFFFFFF);
    final primaryTextColor = isDark ? const Color(0xFFE6EDF3) : const Color(0xFF1F2937);
    final secondaryTextColor = isDark ? const Color(0xFF8B949E) : const Color(0xFF6B7280);
    final borderStroke = isDark ? const Color(0xFF30363D) : const Color(0xFFE5E7EB);
    const accentTeal = Color(0xFF0D9488);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        scrolledUnderElevation: 2,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: primaryTextColor, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _getScreenTitle(),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: primaryTextColor,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              '🎧 Kelime Takipli Dinleme & Talim',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: accentTeal,
              ),
            ),
          ],
        ),
        actions: [
          if (widget.targetType == TalimTargetType.page)
            IconButton(
              icon: Icon(
                _autoAdvancePage ? Icons.auto_stories_rounded : Icons.menu_book_rounded,
                color: _autoAdvancePage ? accentTeal : secondaryTextColor,
                size: 22,
              ),
              tooltip: _autoAdvancePage ? 'Sonraki Sayfaya Kesintisiz Geçiş: Açık' : 'Sonraki Sayfaya Kesintisiz Geçiş: Kapalı',
              onPressed: () {
                setState(() => _autoAdvancePage = !_autoAdvancePage);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(_autoAdvancePage ? 'Sayfa bitince sonraki sayfaya devam edilecek.' : 'Sadece bu sayfa okunacak.'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
          IconButton(
            icon: _isBatchDownloading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0D9488)),
                  )
                : Icon(
                    _isCurrentScopeDownloaded ? Icons.download_done_rounded : Icons.download_for_offline_rounded,
                    color: _isCurrentScopeDownloaded ? accentTeal : secondaryTextColor,
                    size: 22,
                  ),
            tooltip: _isCurrentScopeDownloaded ? 'Diyanet Sesleri İndirildi' : 'Bu Bölümün Seslerini İndir',
            onPressed: _isBatchDownloading ? null : _handleDownloadCurrentScope,
          ),
          IconButton(
            icon: Icon(
              _showMeal ? Icons.auto_stories_rounded : Icons.menu_book_outlined,
              color: _showMeal ? accentTeal : secondaryTextColor,
              size: 22,
            ),
            tooltip: 'Türkçe Meal Aç/Kapat',
            onPressed: () => setState(() => _showMeal = !_showMeal),
          ),
          IconButton(
            icon: Icon(
              _maskingMode ? Icons.visibility_off_rounded : Icons.visibility_rounded,
              color: _maskingMode ? Colors.amber : secondaryTextColor,
              size: 22,
            ),
            tooltip: 'Ezber / Maskeleme Modu',
            onPressed: () => setState(() => _maskingMode = !_maskingMode),
          ),
          IconButton(
            icon: Icon(Icons.text_fields_rounded, color: primaryTextColor, size: 22),
            tooltip: 'Yazı Boyutu',
            onPressed: () => _showFontSizeSlider(context, ref.read(arabicFontFamilyProvider)),
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: accentTeal, strokeWidth: 3),
                  const SizedBox(height: 16),
                  Text(
                    'Kelime senkronize ayetler yükleniyor...',
                    style: TextStyle(color: secondaryTextColor, fontSize: 13),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Top Progress Bar for the entire Surah/Page/Juz
                LinearProgressIndicator(
                  value: _verses.isNotEmpty
                      ? ((_currentVerseIndex + 1) / _verses.length)
                      : 0.0,
                  backgroundColor: borderStroke,
                  valueColor: const AlwaysStoppedAnimation<Color>(accentTeal),
                  minHeight: 3,
                ),

                // BESMELE-I SERIF PLAYBACK BANNER
                if (_isPlayingBesmele)
                  const BesmelePlaybackBanner(),

                // Main Quran Verses List
                Expanded(
                  child: IgnorePointer(
                    ignoring: _isPlayingBesmele,
                    child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                    itemCount: _verses.length,
                    itemBuilder: (context, vIdx) {
                      final verse = _verses[vIdx];
                      final isCurrentVerse = vIdx == _currentVerseIndex;
                      final mealText = _meals['${verse.sureId}_${verse.ayetId}'];
                      final fontFamily = ref.watch(arabicFontFamilyProvider);
                      final showPageDivider = (widget.targetType != TalimTargetType.page) &&
                          (vIdx == 0 || _verses[vIdx - 1].page != verse.page);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (showPageDivider)
                            _buildPageSeparator(verse.page, isDark, borderStroke),
                          Container(
                            key: _verseKeys[vIdx],
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isCurrentVerse
                              ? (isDark ? const Color(0xFF1E2631) : const Color(0xFFF0FDF9))
                              : cardBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isCurrentVerse
                                ? accentTeal.withValues(alpha: 0.8)
                                : borderStroke,
                            width: isCurrentVerse ? 1.8 : 1.0,
                          ),
                          boxShadow: [
                            if (isCurrentVerse)
                              BoxShadow(
                                color: accentTeal.withValues(alpha: 0.15),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Header Row: Surah & Ayah Badge + Play Button
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isCurrentVerse
                                            ? accentTeal
                                            : borderStroke.withValues(alpha: 0.6),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '${verse.sure?.sureNameTurkish ?? '${verse.sureId}. Sure'} · ${verse.ayetId}. Âyet',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.bold,
                                          color: isCurrentVerse ? Colors.white : primaryTextColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        Icons.share_rounded,
                                        color: isCurrentVerse ? accentTeal : secondaryTextColor,
                                        size: 20,
                                      ),
                                      tooltip: 'Ayet ve Mealini Paylaş',
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () {
                                        HapticService.selectionClick();
                                        final surahTitle =
                                            verse.sure?.sureNameTurkish ?? '${verse.sureId}. Sûre';
                                        ZikirSharePreviewModal.show(
                                          context: context,
                                          zikirName: '$surahTitle • ${verse.ayetId}. Âyet',
                                          arabicText: QuranWordHighlighter.cleanArabicText(verse.ayetText),
                                          virtue: (mealText != null && mealText.isNotEmpty)
                                              ? mealText
                                              : verse.ayetText,
                                          customSource: '$surahTitle Sûresi, ${verse.ayetId}. Âyet',
                                          category: 'Kur’an',
                                          currentCount: verse.page,
                                          targetCount: 604,
                                          totalCount: verse.page,
                                          initialTheme: ZikirShareCardTheme.emeraldSufi,
                                          initialShowCounterStats: false,
                                        );
                                      },
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        isCurrentVerse && _isPlaying
                                            ? Icons.pause_circle_filled_rounded
                                            : Icons.play_circle_fill_rounded,
                                        color: isCurrentVerse ? accentTeal : secondaryTextColor,
                                        size: 28,
                                      ),
                                      onPressed: () {
                                        if (isCurrentVerse) {
                                          _togglePlayPause();
                                        } else {
                                          _goToVerse(vIdx);
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Word-by-Word Interactive Arabic Text
                            _buildWordInteractiveVerse(
                              verse: verse,
                              verseIndex: vIdx,
                              isCurrentVerse: isCurrentVerse,
                              isDark: isDark,
                              fontFamily: fontFamily,
                            ),

                            // Turkish Meal
                            if (_showMeal && mealText != null && mealText.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF0F141C)
                                      : const Color(0xFFF9FAFB),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: borderStroke),
                                ),
                                child: Text(
                                  mealText,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? const Color(0xFFBAC5D0) : const Color(0xFF4B5563),
                                    height: 1.45,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  );
                },
                  ),
                  ),
                ),

                // Floating Bottom Player Controller Bar
                _buildBottomAudioControlBar(
                  cardBg: cardBg,
                  primaryTextColor: primaryTextColor,
                  secondaryTextColor: secondaryTextColor,
                  borderStroke: borderStroke,
                  accentTeal: accentTeal,
                  isDark: isDark,
                ),
              ],
            ),
    );
  }

  static const Set<String> _stopSigns = QuranWordHighlighter.stopSigns;

  static String mapStopCharacter(String char, String fontFamily) =>
      QuranWordHighlighter.mapStopCharacter(char, fontFamily);

  List<_CleanWordInfo> _parseAyahWords(String ayetText) {
    final normalized = QuranWordHighlighter.cleanArabicText(ayetText);

    final rawWords = normalized.split(RegExp(r'\s+'));
    final result = <_CleanWordInfo>[];

    for (final w in rawWords) {
      final cleanWord = w.trim();
      if (cleanWord.isEmpty) continue;

      final cleanWordBuf = StringBuffer();
      final stops = <String>[];

      for (int cIdx = 0; cIdx < cleanWord.length; cIdx++) {
        final char = cleanWord[cIdx];
        if (_stopSigns.contains(char)) {
          stops.add(char);
        } else {
          cleanWordBuf.write(char);
        }
      }

      final pureWord = cleanWordBuf.toString();
      result.add(_CleanWordInfo(pureWord: pureWord, stops: stops));
    }
    return result;
  }

  /// Builds the words with individual interactive highlighters
  Widget _buildWordInteractiveVerse({
    required QuranAyatModel verse,
    required int verseIndex,
    required bool isCurrentVerse,
    required bool isDark,
    required String fontFamily,
  }) {
    final cleanWordsData = _parseAyahWords(verse.ayetText);
    final divineColor = QuranWordHighlighter.getDivineWordColor(isDark);
    final waqfColor = isDark ? const Color(0xFFFF5252) : const Color(0xFFD32F2F);
    final isBoldArabic = ref.watch(isBoldArabicProvider);
    final isArrowTracking = ref.watch(
      settingsProvider.select((s) => s.wordTrackingMode == 'arrow'),
    );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Wrap(
        spacing: 6,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (int wIdx = 0; wIdx < cleanWordsData.length; wIdx++) ...[
            Builder(
              builder: (context) {
                final wordOrder = wIdx + 1;
                final isWordActive = isCurrentVerse &&
                    _activeWordOrder == wordOrder;
                final isMasked = _maskingMode &&
                    isCurrentVerse &&
                    _isPlaying &&
                    wordOrder > _activeWordOrder;

                final wordData = cleanWordsData[wIdx];
                final pureWord = wordData.pureWord;
                final stops = wordData.stops;
                final isDivine = pureWord.isNotEmpty && QuranWordHighlighter.isDivineWord(pureWord);

                final activeArrowTextColor = isDivine
                    ? divineColor
                    : (isDark
                        ? const Color(0xFFFBBF24)
                        : const Color(0xFF047857));

                return Row(
                  key: isWordActive ? _activeWordKey : null,
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (pureWord.isNotEmpty)
                      InkWell(
                        onTap: () => _onWordTapped(verseIndex, wordOrder),
                        borderRadius: BorderRadius.circular(10),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 45),
                          padding: isArrowTracking
                              ? const EdgeInsets.fromLTRB(6, 2, 6, 13)
                              : const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: (!isArrowTracking && isWordActive)
                                ? (isDark ? const Color(0xFF059669) : const Color(0xFF10B981))
                                : (isArrowTracking && isWordActive
                                    ? (isDark
                                        ? const Color(0xFFFBBF24).withValues(alpha: 0.08)
                                        : const Color(0xFF10B981).withValues(alpha: 0.08))
                                    : Colors.transparent),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              if (!isArrowTracking && isWordActive)
                                BoxShadow(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.6),
                                  blurRadius: 12,
                                  spreadRadius: 1,
                                  offset: const Offset(0, 2),
                                ),
                            ],
                          ),
                          child: Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.bottomCenter,
                            children: [
                              Text(
                                isMasked ? '••••' : pureWord,
                                style: TextStyle(
                                  fontFamily: fontFamily,
                                  fontSize: _fontSize,
                                  fontWeight: (isBoldArabic ||
                                          (isArrowTracking && isWordActive))
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isWordActive
                                      ? (isArrowTracking
                                          ? activeArrowTextColor
                                          : Colors.white)
                                      : (isDivine
                                          ? divineColor
                                          : (isDark
                                              ? Colors.white
                                              : const Color(0xFF1E2B27))),
                                  height: 1.6,
                                  letterSpacing: -0.1,
                                ),
                              ),
                              if (isArrowTracking && isWordActive)
                                Positioned(
                                  bottom: -11,
                                  left: 0,
                                  right: 0,
                                  child: QuranWordTrackingPointer(
                                    isDark: isDark,
                                    height: 11.0,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    if (stops.isNotEmpty) ...[
                      for (final stop in stops) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 1.5),
                          child: Text(
                            mapStopCharacter(stop, fontFamily),
                            style: TextStyle(
                              fontFamily: fontFamily,
                              fontSize: _fontSize * 0.85,
                              fontWeight: FontWeight.normal,
                              color: waqfColor,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ],
                );
              },
            ),
          ],
          // Ayah Stop Rosette Marker
          Padding(
            padding: const EdgeInsets.only(top: 4, right: 4),
            child: GestureDetector(
              onTap: () => _prepareAndPlayVerse(verseIndex),
              child: ZikirceAyahStopMarker(
                number: verse.ayetNumber,
                size: 28,
                isDark: isDark,
                isHighlight: isCurrentVerse,
                fontFamily: fontFamily,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Floating Glassmorphism Player Control Bar
  Widget _buildBottomAudioControlBar({
    required Color cardBg,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color borderStroke,
    required Color accentTeal,
    required bool isDark,
  }) {
    final currentVerse = _verses.isNotEmpty && _currentVerseIndex < _verses.length
        ? _verses[_currentVerseIndex]
        : null;

    final repeatLabel = _repeatMode == 1
        ? '1x'
        : (_repeatMode == 0 ? '∞' : '${_repeatMode}x');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: borderStroke),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.targetType == TalimTargetType.surah &&
                _verses.isNotEmpty &&
                _currentVerseIndex == _verses.length - 1) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _hasMarkedSurahAsCompleted
                        ? const Color(0xFF0F766E)
                        : accentTeal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                  ),
                  onPressed: _hasMarkedSurahAsCompleted
                      ? null
                      : () => _handleSurahCompleted(),
                  icon: Icon(
                    _hasMarkedSurahAsCompleted
                        ? Icons.check_circle_rounded
                        : Icons.check_circle_outline_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  label: Text(
                    _hasMarkedSurahAsCompleted
                        ? 'Sûre Okundu / Dinlendi'
                        : 'Sûreyi Dinledim & Tamamladım',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ),
            ],
            // Top mini row: Current Ayah title & Word Indicator
            if (currentVerse != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isPlayingBesmele
                        ? 'Besmele-i Şerif'
                        : '${currentVerse.sure?.sureNameTurkish ?? ''} · ${currentVerse.ayetId}. Âyet',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: primaryTextColor,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_activeWordOrder > 0) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: accentTeal.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Kelime: $_activeWordOrder',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: accentTeal,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      InkWell(
                        onTap: _cyclePlaybackSpeed,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: borderStroke.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${_playbackSpeed}x',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: primaryTextColor,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            const SizedBox(height: 10),

            // Controls Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Repeat Mode Button (Ayat Repeat)
                IconButton(
                  icon: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.repeat_rounded,
                          color: _repeatMode != 1 ? accentTeal : secondaryTextColor,
                          size: 20),
                      Text(
                        repeatLabel,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: _repeatMode != 1 ? accentTeal : secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                  tooltip: 'Âyet Tekrar Sayısı',
                  onPressed: _cycleRepeatMode,
                ),

                // Previous Verse
                IconButton(
                  icon: Icon(
                    Icons.skip_previous_rounded,
                    color: _isPlayingBesmele ? primaryTextColor.withValues(alpha: 0.3) : primaryTextColor,
                    size: 28,
                  ),
                  tooltip: 'Önceki Âyet',
                  onPressed: _isPlayingBesmele
                      ? null
                      : (_currentVerseIndex > 0
                          ? () => _goToVerse(_currentVerseIndex - 1)
                          : null),
                ),

                // Big Play / Pause Button
                GestureDetector(
                  onTap: _togglePlayPause,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [accentTeal, const Color(0xFF0F766E)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: accentTeal.withValues(alpha: 0.4),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: _isAudioBuffering
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : Icon(
                              _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 32,
                            ),
                    ),
                  ),
                ),

                // Next Verse
                IconButton(
                  icon: Icon(
                    Icons.skip_next_rounded,
                    color: _isPlayingBesmele ? primaryTextColor.withValues(alpha: 0.3) : primaryTextColor,
                    size: 28,
                  ),
                  tooltip: 'Sonraki Âyet',
                  onPressed: _isPlayingBesmele
                      ? null
                      : (_currentVerseIndex < _verses.length - 1
                          ? () => _goToVerse(_currentVerseIndex + 1)
                          : null),
                ),

                // Scope Loop Button (Bölüm Döngüsü)
                IconButton(
                  icon: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.sync_rounded,
                        color: _isScopeLoopEnabled ? accentTeal : secondaryTextColor,
                        size: 20,
                      ),
                      Text(
                        _isScopeLoopEnabled ? 'Döngü' : 'Bölüm',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: _isScopeLoopEnabled ? accentTeal : secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                  tooltip: _isScopeLoopEnabled
                      ? 'Bölüm Döngüsü: Açık (Bölüm bitince baştan başlar)'
                      : 'Bölüm Döngüsü: Kapalı (Bölüm bitince durur)',
                  onPressed: () {
                    setState(() => _isScopeLoopEnabled = !_isScopeLoopEnabled);
                    if (_repeatMode != 0) {
                      _player.setLoopMode(
                        _isScopeLoopEnabled ? LoopMode.all : LoopMode.off,
                      );
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          _isScopeLoopEnabled
                              ? 'Bölüm Döngüsü Açık: Bölüm bitince baştan tekrar başlayacak.'
                              : 'Bölüm Döngüsü Kapalı: Bölüm bitince tilavet duracak.',
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showFontSizeSlider(BuildContext context, String fontFamily) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return SafeArea(
              top: false,
              bottom: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Arapça Yazı Boyutu',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Slider(
                      value: _fontSize,
                      min: 18.0,
                      max: 42.0,
                      divisions: 12,
                      activeColor: const Color(0xFF0D9488),
                      label: _fontSize.toInt().toString(),
                      onChanged: (val) {
                        setModalState(() => _fontSize = val);
                        setState(() => _fontSize = val);
                      },
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          fontFamily: fontFamily,
                          fontSize: _fontSize,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
