import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../../../../core/constants/surah_data_provider.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/services/audio_download_service.dart';
import '../../../../core/services/audio_sync_service.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../../core/services/ios_now_playing_service.dart';
import '../../../../core/services/quran_page_repository.dart';
import '../../../../core/services/screen_awake_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/quran_word_highlighter.dart';
import '../../../kuran/presentation/widgets/besmele_playback_banner.dart';
import '../../../kuran/presentation/widgets/mushaf_page_widget.dart';
import '../../../kuran/presentation/widgets/desktop_mushaf_nav_button.dart';
import '../../../kuran/presentation/widgets/zikirce_ayah_stop_marker.dart';
import '../../../kuran/providers/kuran_providers.dart';
import '../../../kuran/data/tilavet_secdesi_data.dart';
import '../../../kuran/providers/tilavet_secdesi_provider.dart';
import '../../../kuran/presentation/widgets/tilavet_secdesi_floating_banner.dart';
import '../../../kuran/presentation/widgets/tilavet_secdesi_exit_dialog.dart';
import '../../../kuran/presentation/widgets/tilavet_secdesi_guide_sheet.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../../zikir/presentation/widgets/zikir_share_card_widget.dart';
import '../../../zikir/presentation/widgets/zikir_share_preview_modal.dart';
import '../../providers/hatim_providers.dart';
import '../widgets/hatim_duasi_modal.dart';
import '../../../../core/services/cloud_sync_engine.dart';

class _MukabeleQueueItemMeta {
  final int verseIndex;
  final bool isBesmele;

  const _MukabeleQueueItemMeta({
    required this.verseIndex,
    required this.isBesmele,
  });
}

class MukabeleHatimScreen extends ConsumerStatefulWidget {
  final Hatim? activeHatim;
  final int initialPage;
  final int? initialJuz;

  const MukabeleHatimScreen({
    super.key,
    this.activeHatim,
    this.initialPage = 1,
    this.initialJuz,
  });

  @override
  ConsumerState<MukabeleHatimScreen> createState() =>
      _MukabeleHatimScreenState();
}

class _MukabeleHatimScreenState extends ConsumerState<MukabeleHatimScreen> {
  final AudioPlayer _player = AudioPlayer();
  late PageController _pageController;
  late final FocusNode _focusNode;
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _verseKeys = {};
  final GlobalKey _activeWordKey = GlobalKey();

  int _currentPage = 1;
  bool _isMushafView =
      false; // default = Ayah List View, user can switch to Mushaf mode
  bool _isMealOnlyView = false; // Sadece Meal Okuma modu
  double _playbackSpeed = 1.0;
  final Set<int> _encounteredSecdePages = <int>{};
  bool _dismissedBannerForCurrentPage = false;
  int? _lastBannerPage;

  bool _isLoading = true;
  bool _isPlaying = false;
  bool _isBuffering = false;
  bool _isPlayingBesmele = false;
  bool _isPageTransitioning = false;
  String? _transitionBannerText;
  Timer? _pageTransitionTimer;

  List<QuranAyatModel> _pageVerses = [];
  Map<String, String> _pageMeals = {};
  List<_MukabeleQueueItemMeta> _playlistItems = [];
  int _currentVerseIndex = 0;
  int _activeWordOrder = 0;
  int _activeWordDurationMs = 500;
  int _lastHandledQueueIndex = -1;
  int _queueGeneration = 0;
  bool _isAdvancingWindowsItem = false;
  final Stopwatch _verseStopwatch = Stopwatch();
  final Stopwatch _microInterpStopwatch = Stopwatch();
  double _verseSeekAnchorMs = 0.0;
  double _lastSampledPlayerMs = -1.0;
  double _maxObservedVerseMs = 0.0;
  Timer? _wordSyncTimer;

  StreamSubscription? _posSub;
  StreamSubscription? _stateSub;
  StreamSubscription<int?>? _currentIndexSub;

  @override
  void initState() {
    super.initState();
    int start = widget.initialPage;
    if (widget.initialJuz != null &&
        widget.initialJuz! >= 1 &&
        widget.initialJuz! <= 30) {
      start = SurahDataProvider.getJuzStartPage(widget.initialJuz!);
    } else if (widget.activeHatim != null &&
        widget.activeHatim!.completedPages > 0) {
      start = (widget.activeHatim!.completedPages + 1).clamp(1, 605);
    }
    _currentPage = start.clamp(1, 605);
    if (TilavetSecdesiData.isSecdePage(_currentPage)) {
      _encounteredSecdePages.add(_currentPage);
    }
    _pageController = PageController(initialPage: _currentPage - 1);
    _focusNode = FocusNode();
    IosNowPlayingService.setRemoteCommandCallback(_handleRemoteCommand);

    _initScreenAndAudio();
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
        _nextAyah();
        break;
      case 'previous':
        _previousAyah();
        break;
    }
  }

  @override
  void dispose() {
    IosNowPlayingService.setRemoteCommandCallback(null);
    IosNowPlayingService.clearNowPlaying();
    _focusNode.dispose();
    _pageTransitionTimer?.cancel();
    _wordSyncTimer?.cancel();
    _verseStopwatch.stop();
    _microInterpStopwatch.stop();
    _currentIndexSub?.cancel();
    _posSub?.cancel();
    _stateSub?.cancel();
    _player.dispose();
    _pageController.dispose();
    _scrollController.dispose();
    ScreenAwakeService.setKeepAwake(false);
    CloudSyncEngine.instance
        .triggerDebouncedSync(null, delay: const Duration(seconds: 1));
    try {
      ref.read(kuranAudioNotifierProvider.notifier).reset();
    } catch (_) {}
    super.dispose();
  }

  Future<void> _initScreenAndAudio() async {
    await AudioSyncService.initialize();
    if (ref.read(settingsProvider).isKeepScreenAwakeEnabled) {
      ScreenAwakeService.setKeepAwake(true);
    }

    _initAudioListeners();
    await _loadPageData(_currentPage);

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      // Start playback automatically for Mukabele
      if (_pageVerses.isNotEmpty) {
        await _buildAndPlayPageQueue(
          _currentVerseIndex,
          includeInitialBesmele: true,
        );
      }
    }
  }

  void _syncNowPlaying() {
    if (_pageVerses.isEmpty || _currentVerseIndex >= _pageVerses.length) return;
    final verse = _pageVerses[_currentVerseIndex];
    final surahName = verse.sure?.sureNameTurkish ?? '${verse.sureId}. Sûre';
    final juzNo = (_currentPage / 20).ceil().clamp(1, 30);
    final title = _isPlayingBesmele
        ? 'Besmele-i Şerif ($surahName)'
        : '$surahName · ${verse.ayetId}. Âyet';
    IosNowPlayingService.updateNowPlaying(
      title: title,
      subtitle: 'Zikirce Mukabele • Cüz $juzNo · Sayfa $_currentPage',
      isPlaying: _isPlaying,
      durationMs: _player.duration?.inMilliseconds ?? 0,
      positionMs: _player.position.inMilliseconds,
      speed: _playbackSpeed,
    );
  }

  void _resetVerseClock({int seekMs = 0, bool isPlaying = true}) {
    _verseSeekAnchorMs = seekMs.toDouble();
    _lastSampledPlayerMs = -1.0;
    _maxObservedVerseMs = seekMs.toDouble();
    _verseStopwatch.reset();
    _microInterpStopwatch.reset();
    final isReady = _player.processingState == ProcessingState.ready;
    if (isPlaying && !_isBuffering && isReady) {
      _verseStopwatch.start();
    }
  }

  double _currentEffectivePositionMs() {
    if (_isAdvancingWindowsItem ||
        _player.processingState == ProcessingState.loading ||
        _player.processingState == ProcessingState.idle) {
      return _verseSeekAnchorMs;
    }

    final playerMs = _player.position.inMilliseconds.toDouble();
    if ((playerMs - _lastSampledPlayerMs).abs() >= 1.0) {
      _lastSampledPlayerMs = playerMs;
      _microInterpStopwatch
        ..reset()
        ..start();
    }

    double effectiveMs = playerMs;
    if (_player.playing &&
        _player.processingState == ProcessingState.ready &&
        playerMs > 0) {
      final interpDelta =
          (_microInterpStopwatch.elapsedMilliseconds * _playbackSpeed)
              .clamp(0.0, 45.0);
      effectiveMs = playerMs + interpDelta;
    }

    if (effectiveMs > _maxObservedVerseMs) {
      _maxObservedVerseMs = effectiveMs;
    }
    return effectiveMs.clamp(0.0, 600000.0);
  }

  void _tickWordSync() {
    if (!mounted) return;
    if (_isAdvancingWindowsItem || _isPlayingBesmele) {
      return;
    }
    if (!_isPlaying && !_player.playing) return;
    if (_pageVerses.isEmpty || _currentVerseIndex >= _pageVerses.length) {
      return;
    }

    final verse = _pageVerses[_currentVerseIndex];
    final ms = _currentEffectivePositionMs();
    final words = _parseAyahWords(verse.ayetText);
    final pureWords = words.map((w) => w.pureWord).toList();
    final activeWord = AudioSyncService.getActiveWordOrder(
      verse.sureId,
      verse.ayetId,
      ms,
      renderedWordCount: words.length,
      ayahWords: pureWords,
    );

    if (activeWord != _activeWordOrder && mounted) {
      final wordDur = AudioSyncService.getWordDurationMs(
        verse.sureId,
        verse.ayetId,
        activeWord,
        ayahWords: pureWords,
        trackDurationMs: _player.duration?.inMilliseconds,
      );
      setState(() {
        _activeWordOrder = activeWord;
        _activeWordDurationMs = wordDur;
      });

      if (!_isMushafView && !_isMealOnlyView) {
        _scrollToActiveWord();
      }

      ref
          .read(kuranAudioNotifierProvider.notifier)
          .syncExternalState(KuranAudioState(
            isPlaying: _isPlaying || _player.playing,
            isLoading: _isBuffering,
            currentSurahId: verse.sureId,
            currentAyahId: verse.ayetId,
            currentWordOrder: activeWord,
            activeWordDurationMs: wordDur,
            playbackSpeed: _playbackSpeed,
            playbackProgress: (_player.duration?.inMilliseconds ?? 1) > 0
                ? (ms / (_player.duration?.inMilliseconds ?? 1)).clamp(0.0, 1.0)
                : 0.0,
          ));
    }
  }

  void _initAudioListeners() {
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

    _stateSub = _player.playerStateStream.listen((pState) {
      if (!mounted) return;

      final isPlaying = pState.playing;
      final isBuffering = pState.processingState == ProcessingState.loading ||
          pState.processingState == ProcessingState.buffering;
      final isReady = pState.processingState == ProcessingState.ready;

      if (isPlaying && isReady) {
        if (!_verseStopwatch.isRunning) {
          _verseStopwatch.start();
        }
      } else {
        if (_verseStopwatch.isRunning) {
          _verseStopwatch.stop();
        }
      }

      if (_isPlaying != isPlaying || _isBuffering != isBuffering) {
        setState(() {
          _isPlaying = isPlaying;
          _isBuffering = isBuffering;
        });
        _syncNowPlaying();

        if (_isPlayingBesmele) {
          ref
              .read(kuranAudioNotifierProvider.notifier)
              .syncExternalState(KuranAudioState(
                isPlaying: isPlaying,
                isLoading: isBuffering,
                currentSurahId: 1,
                currentAyahId: 1,
                currentWordOrder: 0,
                playbackProgress: (_player.duration?.inMilliseconds ?? 1) > 0
                    ? ((_player.position.inMilliseconds) /
                            (_player.duration?.inMilliseconds ?? 1))
                        .clamp(0.0, 1.0)
                    : 0.0,
              ));
        } else {
          final verse = _currentVerseIndex < _pageVerses.length
              ? _pageVerses[_currentVerseIndex]
              : null;
          if (verse != null) {
            ref
                .read(kuranAudioNotifierProvider.notifier)
                .syncExternalState(KuranAudioState(
                  isPlaying: isPlaying,
                  isLoading: isBuffering,
                  currentSurahId: verse.sureId,
                  currentAyahId: verse.ayetId,
                  currentWordOrder: _activeWordOrder,
                  activeWordDurationMs: _activeWordDurationMs,
                  playbackSpeed: _playbackSpeed,
                  playbackProgress: (_player.duration?.inMilliseconds ?? 1) > 0
                      ? ((_player.position.inMilliseconds) /
                              (_player.duration?.inMilliseconds ?? 1))
                          .clamp(0.0, 1.0)
                      : 0.0,
                ));
          }
        }
      }

      if (pState.processingState == ProcessingState.completed &&
          !_isAdvancingWindowsItem) {
        _isAdvancingWindowsItem = true;
        if (_lastHandledQueueIndex >= 0 &&
            _lastHandledQueueIndex + 1 < _playlistItems.length) {
          unawaited(_playWindowsSingleQueueItem(_lastHandledQueueIndex + 1));
        } else {
          _isAdvancingWindowsItem = false;
          _handlePageCompleted();
        }
      }
    });
  }

  Future<void> _loadPageData(int page) async {
    final pageData = await QuranPageRepository.getPage(page);
    final meals = <String, String>{};
    for (final m in pageData.mealAyats) {
      meals['${m.sureId}_${m.ayetId}'] = m.ayetText;
    }

    if (mounted) {
      _verseKeys.clear();
      setState(() {
        _pageVerses = pageData.quranAyats;
        _pageMeals = meals;
        _currentVerseIndex = 0;
        _activeWordOrder = 0;
      });
      ref.read(currentMushafPageProvider.notifier).state = page;
      if (TilavetSecdesiData.isSecdePage(page)) {
        _encounteredSecdePages.add(page);
        if (_lastBannerPage != page) {
          _lastBannerPage = page;
          _dismissedBannerForCurrentPage = false;
        }
      }
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0.0);
      }
    }
  }

  void _scrollToActiveWord() {
    if (_isMushafView) return;
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

  bool _shouldPlayBesmeleForVerse(QuranAyatModel verse,
      {required bool isSessionStart}) {
    final isBesmeleEnabled =
        ref.read(settingsProvider).isPlayBesmeleOnStartEnabled;
    if (!isBesmeleEnabled) return false;

    // Never play extra Besmele for Al-Fatihah 1:1 (which is already Besmele) or At-Tawbah (Surah 9)
    if (verse.sureId == 1 && verse.ayetId == 1) return false;
    if (verse.sureId == 9) return false;

    // Play Besmele at the start of a Mukabele session or when a new Surah starts at verse 1
    if (isSessionStart || verse.ayetId == 1) {
      return true;
    }

    return false;
  }

  AudioSource _createAyahAudioSource(
    String soundsDirPath,
    int surahId,
    int ayahId, {
    int? pageId,
    required bool useFallbackCdn,
  }) {
    final localPath =
        '$soundsDirPath${Platform.pathSeparator}audio_${surahId}_$ayahId.mp3';
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
    for (int offset = 0; offset <= 4; offset++) {
      final idx = fromVerseIndex + offset;
      if (idx >= 0 && idx < _pageVerses.length) {
        final v = _pageVerses[idx];
        unawaited(AudioDownloadService.ensureVerseDownloaded(
          v.sureId,
          v.ayetId,
          pageId: _currentPage,
        ));
      }
    }
  }

  Future<void> _playWindowsSingleQueueItem(
    int qIdx, {
    int seekMs = 0,
    bool useFallbackCdn = false,
  }) async {
    if (qIdx < 0 || qIdx >= _playlistItems.length || _pageVerses.isEmpty) {
      _isAdvancingWindowsItem = false;
      return;
    }

    final myGen = ++_queueGeneration;
    _isAdvancingWindowsItem = true;
    final meta = _playlistItems[qIdx];
    final prevVerseIndex = _currentVerseIndex;
    final wasPlayingBesmele = _isPlayingBesmele;

    _lastHandledQueueIndex = qIdx;
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
      final verse = _pageVerses[meta.verseIndex];
      final targetSurah = meta.isBesmele ? 1 : verse.sureId;
      final targetAyah = meta.isBesmele ? 1 : verse.ayetId;
      final targetPage = meta.isBesmele ? 1 : _currentPage;

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

      if (_player.playing) {
        await _player.pause();
      }
      await _player.setLoopMode(LoopMode.off);
      await _player.setAudioSource(
        source,
        initialPosition:
            seekMs > 0 ? Duration(milliseconds: seekMs) : Duration.zero,
      );

      if (!mounted || myGen != _queueGeneration) return;

      await _player.setSpeed(_playbackSpeed);
      _resetVerseClock(seekMs: seekMs, isPlaying: true);
      _isAdvancingWindowsItem = false;
      unawaited(_player.play());

      if (meta.isBesmele) {
        ref
            .read(kuranAudioNotifierProvider.notifier)
            .syncExternalState(KuranAudioState(
              isPlaying: true,
              isLoading: false,
              currentSurahId: verse.sureId,
              currentAyahId: verse.ayetId,
              currentWordOrder: 0,
              playbackSpeed: _playbackSpeed,
              playbackProgress: 0.0,
            ));
      } else {
        final pureWords =
            _parseAyahWords(verse.ayetText).map((w) => w.pureWord).toList();
        final initialWord = seekMs > 0
            ? AudioSyncService.getActiveWordOrder(
                verse.sureId,
                verse.ayetId,
                seekMs.toDouble(),
                renderedWordCount: pureWords.length,
                ayahWords: pureWords,
              )
            : 1;
        final firstWordDur = AudioSyncService.getWordDurationMs(
          verse.sureId,
          verse.ayetId,
          initialWord,
          ayahWords: pureWords,
          trackDurationMs: _player.duration?.inMilliseconds,
        );
        if (mounted) {
          setState(() {
            _activeWordOrder = initialWord;
            _activeWordDurationMs = firstWordDur;
          });
        }
        ref
            .read(kuranAudioNotifierProvider.notifier)
            .syncExternalState(KuranAudioState(
              isPlaying: true,
              isLoading: false,
              currentSurahId: verse.sureId,
              currentAyahId: verse.ayetId,
              currentWordOrder: initialWord,
              activeWordDurationMs: firstWordDur,
              playbackSpeed: _playbackSpeed,
              playbackProgress: 0.0,
            ));
      }

      if (!meta.isBesmele &&
          (wasPlayingBesmele || prevVerseIndex != _currentVerseIndex)) {
        if (!_isMushafView) {
          _scrollToActiveVerse();
        }
        _prefetchUpcomingVerses(_currentVerseIndex);
      }
      _syncNowPlaying();
    } catch (e) {
      _isAdvancingWindowsItem = false;
      debugPrint('[MukabeleHatimScreen] Single item playback error: $e');
      if (!useFallbackCdn && myGen == _queueGeneration) {
        await _playWindowsSingleQueueItem(
          qIdx,
          seekMs: seekMs,
          useFallbackCdn: true,
        );
      }
    }
  }

  Future<void> _buildAndPlayPageQueue(
    int startVerseIndex, {
    required bool includeInitialBesmele,
    int seekMs = 0,
    bool useFallbackCdn = false,
  }) async {
    if (_pageVerses.isEmpty ||
        startVerseIndex < 0 ||
        startVerseIndex >= _pageVerses.length) {
      return;
    }

    final myQueueGen = ++_queueGeneration;

    if (mounted) {
      setState(() {
        _isBuffering = true;
        _activeWordOrder = 0;
      });
    }

    try {
      if (ref.read(kuranAudioNotifierProvider).isPlaying) {
        await ref.read(kuranAudioNotifierProvider.notifier).stop();
      }
    } catch (_) {}

    await AudioSyncService.configureAudioSession();
    await IosNowPlayingService.beginTransitionTask();

    final metas = <_MukabeleQueueItemMeta>[];
    int initialQueueIndex = 0;

    for (int i = 0; i < _pageVerses.length; i++) {
      final v = _pageVerses[i];
      final isStartVerse = (i == startVerseIndex);
      final wantBesmele = isStartVerse
          ? (includeInitialBesmele &&
              seekMs == 0 &&
              _shouldPlayBesmeleForVerse(v, isSessionStart: true))
          : _shouldPlayBesmeleForVerse(v, isSessionStart: false);

      final firstIdxForThisVerse = metas.length;

      if (wantBesmele) {
        metas.add(_MukabeleQueueItemMeta(
          verseIndex: i,
          isBesmele: true,
        ));
        unawaited(AudioDownloadService.ensureVerseDownloaded(1, 1, pageId: 1));
      }

      final firstAyahQueueIdx = metas.length;
      metas.add(_MukabeleQueueItemMeta(
        verseIndex: i,
        isBesmele: false,
      ));

      if (isStartVerse) {
        initialQueueIndex = (wantBesmele && seekMs == 0)
            ? firstIdxForThisVerse
            : firstAyahQueueIdx;
      }
    }

    if (!mounted || myQueueGen != _queueGeneration) return;

    _playlistItems = metas;
    _prefetchUpcomingVerses(startVerseIndex);

    await _playWindowsSingleQueueItem(
      initialQueueIndex,
      seekMs: seekMs,
      useFallbackCdn: useFallbackCdn,
    );
  }

  Future<void> _prepareAndPlayVerse(int verseIndex, {int seekMs = 0}) async {
    if (verseIndex < 0 || verseIndex >= _pageVerses.length) return;

    if (_playlistItems.isNotEmpty) {
      final targetQIdx = _playlistItems.indexWhere(
        (m) => m.verseIndex == verseIndex && !m.isBesmele,
      );
      if (targetQIdx != -1) {
        await _playWindowsSingleQueueItem(targetQIdx, seekMs: seekMs);
        return;
      }
    }

    await _buildAndPlayPageQueue(
      verseIndex,
      includeInitialBesmele: false,
      seekMs: seekMs,
    );
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

  Future<void> _handlePageCompleted() async {
    await IosNowPlayingService.beginTransitionTask();
    final completedPage = _currentPage;
    final hatimId = widget.activeHatim?.id;

    // 1. Record Hatim page progress & today's reading goals
    try {
      if (hatimId != null) {
        await ref.read(hatimNotifierProvider).updateHatimPageProgress(
              hatimId: hatimId,
              targetPage: completedPage,
            );
        await ref
            .read(hatimNotifierProvider)
            .saveMukabeleLastPage(hatimId, (completedPage + 1).clamp(1, 605));
      } else {
        // If no active hatim attached, still record page reading for daily goals
        final activeHatim = ref.read(activeMukabeleHatimProvider).valueOrNull;
        if (activeHatim != null) {
          await ref.read(hatimNotifierProvider).updateHatimPageProgress(
                hatimId: activeHatim.id,
                targetPage: completedPage,
              );
          await ref.read(hatimNotifierProvider).saveMukabeleLastPage(
              activeHatim.id, (completedPage + 1).clamp(1, 605));
        }
      }
    } catch (e) {
      debugPrint('[_MukabeleHatimScreenState] _handlePageCompleted error: $e');
    }

    CloudSyncEngine.instance.triggerDebouncedSync(ref);

    HapticService.selectionClick();

    // Check if a full Juz was completed (every 20 pages or page 605)
    final isJuzEnd = completedPage % 20 == 0 || completedPage >= 605;
    final completedJuzNo = (completedPage / 20).ceil().clamp(1, 30);

    final isForeground =
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

    if (isJuzEnd && completedPage < 605 && mounted && isForeground) {
      _showJuzCompletedDialog(completedJuzNo);
    }

    if (completedPage >= 605) {
      // Full Hatim Finished!
      IosNowPlayingService.clearNowPlaying();
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _isPageTransitioning = false;
        });
        if (isForeground) {
          await _showHatimCompletedDialog();
        }
      }
      return;
    }

    if (!isForeground) {
      // In background / Lock Screen: advance immediately without 2-second dead air gap
      if (!mounted) return;
      setState(() {
        _isPageTransitioning = false;
        _transitionBannerText = null;
        _currentPage = completedPage + 1;
      });
      if (_pageController.hasClients) {
        _pageController.jumpToPage(_currentPage - 1);
      }
      await _loadPageData(_currentPage);
      if (mounted && _pageVerses.isNotEmpty) {
        final firstStartsNewSurah = _pageVerses.first.ayetId == 1 &&
            _pageVerses.first.sureId != 1 &&
            _pageVerses.first.sureId != 9;
        await _buildAndPlayPageQueue(0, includeInitialBesmele: firstStartsNewSurah);
      }
      return;
    }

    // 2-second buffer pause before transitioning to next page when in foreground
    if (mounted) {
      setState(() {
        _isPageTransitioning = true;
        _transitionBannerText =
            '✨ Sayfa $completedPage tamamlandı, sıradakine geçiliyor...';
      });
    }

    _pageTransitionTimer?.cancel();
    _pageTransitionTimer = Timer(const Duration(milliseconds: 2000), () async {
      if (!mounted) return;

      setState(() {
        _isPageTransitioning = false;
        _transitionBannerText = null;
        _currentPage = completedPage + 1;
      });

      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage - 1,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOutCubic,
        );
      }

      await _loadPageData(_currentPage);
      if (mounted && _pageVerses.isNotEmpty) {
        final firstStartsNewSurah = _pageVerses.first.ayetId == 1 &&
            _pageVerses.first.sureId != 1 &&
            _pageVerses.first.sureId != 9;
        await _buildAndPlayPageQueue(0, includeInitialBesmele: firstStartsNewSurah);
      }
    });
  }

  void _showJuzCompletedDialog(int juzNo) {
    HapticService.targetReached();
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkCard : Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              const Text('🎉 ', style: TextStyle(fontSize: 24)),
              Expanded(
                child: Text(
                  '$juzNo. Cüz Tamamlandı!',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.emerald800,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'Tebrikler! Mukabele ile $juzNo. cüzü tamamladınız. İlerlemeniz ve okuma hedefleriniz kaydedildi.',
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black87,
              height: 1.4,
            ),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isDark ? AppColors.gold500 : AppColors.emerald700,
                foregroundColor: isDark ? Colors.black : Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Devam Et',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showHatimCompletedDialog() async {
    final completedHatim =
        widget.activeHatim ?? ref.read(activeMukabeleHatimProvider).valueOrNull;
    await HatimDuasiModal.show(
      context,
      completedHatim: completedHatim,
      isCompletionCelebration: true,
    );
  }

  void _togglePlayPause() {
    if (_isPageTransitioning) {
      _pageTransitionTimer?.cancel();
      setState(() {
        _isPageTransitioning = false;
        _isPlaying = false;
      });
      final verse = _currentVerseIndex < _pageVerses.length
          ? _pageVerses[_currentVerseIndex]
          : null;
      if (verse != null) {
        ref
            .read(kuranAudioNotifierProvider.notifier)
            .syncExternalState(KuranAudioState(
              isPlaying: false,
              isLoading: false,
              currentSurahId: verse.sureId,
              currentAyahId: verse.ayetId,
              currentWordOrder: _activeWordOrder,
              playbackProgress: 0.0,
            ));
      }
      return;
    }

    if (_isPlaying) {
      _verseStopwatch.stop();
      _player.pause();
      final verse = _currentVerseIndex < _pageVerses.length
          ? _pageVerses[_currentVerseIndex]
          : null;
      if (verse != null) {
        ref
            .read(kuranAudioNotifierProvider.notifier)
            .syncExternalState(KuranAudioState(
              isPlaying: false,
              isLoading: false,
              currentSurahId: verse.sureId,
              currentAyahId: verse.ayetId,
              currentWordOrder: _activeWordOrder,
              playbackProgress: 0.0,
            ));
      }
    } else {
      if (_player.processingState == ProcessingState.completed ||
          _player.processingState == ProcessingState.idle) {
        _buildAndPlayPageQueue(_currentVerseIndex, includeInitialBesmele: false);
      } else {
        AudioSyncService.configureAudioSession();
        _verseStopwatch.start();
        _player.play();
        final verse = _currentVerseIndex < _pageVerses.length
            ? _pageVerses[_currentVerseIndex]
            : null;
        if (verse != null) {
          ref
              .read(kuranAudioNotifierProvider.notifier)
              .syncExternalState(KuranAudioState(
                isPlaying: true,
                isLoading: false,
                currentSurahId: verse.sureId,
                currentAyahId: verse.ayetId,
                currentWordOrder: _activeWordOrder,
                playbackProgress: 0.0,
              ));
        }
      }
    }
  }

  void _cyclePlaybackSpeed() {
    const speeds = [0.75, 1.0, 1.25, 1.5];
    final nextIndex = (speeds.indexOf(_playbackSpeed) + 1) % speeds.length;
    final newSpeed = speeds[nextIndex];
    _verseSeekAnchorMs = _currentEffectivePositionMs();
    _verseStopwatch.reset();
    if (_isPlaying && !_isBuffering) {
      _verseStopwatch.start();
    }
    setState(() {
      _playbackSpeed = newSpeed;
    });
    _player.setSpeed(newSpeed);
    _syncNowPlaying();
  }

  void _onWordTapped(int verseIndex, int wordOrder) {
    if (verseIndex < 0 || verseIndex >= _pageVerses.length) return;
    final verse = _pageVerses[verseIndex];
    final words = _parseAyahWords(verse.ayetText);
    final pureWords = words.map((w) => w.pureWord).toList();
    final ts = AudioSyncService.getWordTimestamp(
      verse.sureId,
      verse.ayetId,
      wordOrder,
      ayahWords: pureWords,
    );

    if (!_isPlayingBesmele &&
        verseIndex == _currentVerseIndex &&
        _player.duration != null) {
      if (ts != null) {
        final seekTarget = (ts.startTime - 25.0).clamp(0.0, 999999.0).toInt();
        final wordDur = AudioSyncService.getWordDurationMs(
          verse.sureId,
          verse.ayetId,
          wordOrder,
          ayahWords: pureWords,
          trackDurationMs: _player.duration?.inMilliseconds,
        );
        _resetVerseClock(seekMs: seekTarget, isPlaying: true);
        setState(() {
          _activeWordOrder = wordOrder;
          _activeWordDurationMs = wordDur;
        });
        _player.seek(Duration(milliseconds: seekTarget));
        if (!_isPlaying) _player.play();
      }
    } else {
      final seekTarget =
          ts != null ? (ts.startTime - 25.0).clamp(0.0, 999999.0).toInt() : 0;
      _prepareAndPlayVerse(verseIndex, seekMs: seekTarget);
    }
  }

  void _previousAyah() {
    if (_isPlayingBesmele) {
      _prepareAndPlayVerse(_currentVerseIndex);
      return;
    }
    if (_currentVerseIndex > 0) {
      _prepareAndPlayVerse(_currentVerseIndex - 1);
    } else if (_currentPage > 1) {
      _goToPage(_currentPage - 1);
    }
  }

  void _nextAyah() {
    if (_isPlayingBesmele) {
      _prepareAndPlayVerse(_currentVerseIndex);
      return;
    }
    if (_currentVerseIndex < _pageVerses.length - 1) {
      _prepareAndPlayVerse(_currentVerseIndex + 1);
    } else if (_currentPage < 605) {
      _goToPage(_currentPage + 1);
    }
  }

  Future<void> _goToPage(int page) async {
    _pageTransitionTimer?.cancel();
    final target = page.clamp(1, 605);
    setState(() {
      _currentPage = target;
      _isPageTransitioning = false;
      _transitionBannerText = null;
    });
    if (_pageController.hasClients) {
      _pageController.jumpToPage(target - 1);
    }
    await _loadPageData(target);
    if (mounted && _pageVerses.isNotEmpty) {
      await _buildAndPlayPageQueue(0, includeInitialBesmele: false);
    }
  }

  void _showJuzPageSelectorSheet() {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final bg = isDark ? const Color(0xFF1B1E24) : Colors.white;
        final textColor = isDark ? Colors.white : const Color(0xFF1E2B27);
        final gold = isDark ? AppColors.gold400 : const Color(0xFFB57D15);

        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Cüz / Sayfa Seçimi',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: DefaultTabController(
                  length: 2,
                  child: Column(
                    children: [
                      TabBar(
                        indicatorColor: gold,
                        labelColor: gold,
                        unselectedLabelColor:
                            isDark ? Colors.white60 : Colors.black54,
                        tabs: const [
                          Tab(text: '30 Cüz'),
                          Tab(text: 'Sayfalar'),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            // 30 Juz Grid
                            GridView.builder(
                              padding: const EdgeInsets.all(16),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 5,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                                childAspectRatio: 1.0,
                              ),
                              itemCount: 30,
                              itemBuilder: (context, idx) {
                                final juz = idx + 1;
                                final startPage =
                                    SurahDataProvider.getJuzStartPage(juz);
                                final isCurrent = _currentPage >= startPage &&
                                    _currentPage < startPage + 20;

                                return InkWell(
                                  onTap: () {
                                    Navigator.of(ctx).pop();
                                    _goToPage(startPage);
                                  },
                                  borderRadius: BorderRadius.circular(14),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: isCurrent
                                          ? gold.withValues(alpha: 0.25)
                                          : (isDark
                                              ? const Color(0xFF23262F)
                                              : const Color(0xFFF4EFE6)),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: isCurrent
                                            ? gold
                                            : Colors.transparent,
                                        width: 1.5,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '$juz',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: isCurrent ? gold : textColor,
                                          ),
                                        ),
                                        Text(
                                          'Cüz',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: isDark
                                                ? Colors.white54
                                                : Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                            // Page Selector List
                            ListView.builder(
                              itemCount: 605,
                              itemBuilder: (context, idx) {
                                final p = idx + 1;
                                final isCurrent = p == _currentPage;
                                return ListTile(
                                  selected: isCurrent,
                                  selectedTileColor:
                                      gold.withValues(alpha: 0.12),
                                  title: Text('Sayfa $p',
                                      style: TextStyle(
                                          color: textColor,
                                          fontWeight: isCurrent
                                              ? FontWeight.bold
                                              : FontWeight.normal)),
                                  onTap: () {
                                    Navigator.of(ctx).pop();
                                    _goToPage(p);
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleExit() async {
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
    try {
      ref.read(kuranAudioNotifierProvider.notifier).reset();
    } catch (_) {}
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg =
        isDark ? const Color(0xFF101216) : const Color(0xFFFBF8F1);
    final titleColor = isDark ? Colors.white : const Color(0xFF1E2B27);
    final subtitleColor =
        isDark ? const Color(0xFF8A9BAE) : const Color(0xFF6B7280);
    final goldAccent = isDark ? AppColors.gold400 : const Color(0xFFB57D15);
    final bottomBarBg = isDark
        ? const Color(0xFF181B20).withValues(alpha: 0.96)
        : const Color(0xFFFFFDF8).withValues(alpha: 0.97);

    final currentVerse =
        _pageVerses.isNotEmpty && _currentVerseIndex < _pageVerses.length
            ? _pageVerses[_currentVerseIndex]
            : null;
    final surahName = currentVerse?.sure?.sureNameTurkish ?? 'Kuran-ı Kerim';
    final juzNo = (_currentPage / 20).ceil().clamp(1, 30);

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
          iconTheme: IconThemeData(color: titleColor),
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: titleColor),
            tooltip: 'Geri',
            onPressed: _handleExit,
          ),
          title: Column(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🕌 ', style: TextStyle(fontSize: 16)),
                  Text(
                    'Mukabele • $surahName',
                    style: AppTypography.headingSmall(color: titleColor),
                  ),
                ],
              ),
              Text(
                'Cüz $juzNo • Sayfa $_currentPage / 605',
                style: TextStyle(color: subtitleColor, fontSize: 12),
              ),
            ],
          ),
          actions: [
            // Sadece Meal Modu Butonu
            IconButton(
              icon: Icon(
                _isMealOnlyView
                    ? Icons.auto_stories_rounded
                    : Icons.subject_rounded,
                color: _isMealOnlyView ? goldAccent : titleColor,
              ),
              tooltip: _isMealOnlyView
                  ? 'Arapça + Meal Görünümü'
                  : 'Sadece Meal Görünümü',
              onPressed: () {
                HapticService.selectionClick();
                setState(() {
                  _isMealOnlyView = !_isMealOnlyView;
                  if (_isMealOnlyView) {
                    _isMushafView = false;
                  }
                });
              },
            ),
            // View Mode Switcher Button (Mushaf / List)
            IconButton(
              icon: Icon(
                _isMushafView
                    ? Icons.format_list_bulleted_rounded
                    : Icons.menu_book_rounded,
                color: goldAccent,
              ),
              tooltip: _isMushafView
                  ? 'Ayet Listesi Görünümü'
                  : 'Mushaf Sayfası Görünümü',
              onPressed: () {
                HapticService.selectionClick();
                setState(() {
                  _isMushafView = !_isMushafView;
                  if (_isMushafView) {
                    _isMealOnlyView = false;
                  }
                });
              },
            ),
            // Juz / Page Jump Button
            IconButton(
              icon: Icon(Icons.grid_view_rounded, color: titleColor),
              tooltip: 'Cüz ve Sayfa Seç',
              onPressed: _showJuzPageSelectorSheet,
            ),
          ],
        ),
        body: Focus(
          focusNode: _focusNode,
          autofocus: true,
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent) {
              // Arapça Mushaf RTL: Sol Ok -> Sonraki Sayfa, Sağ Ok -> Önceki Sayfa
              if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
                  event.logicalKey == LogicalKeyboardKey.pageDown) {
                if (_currentPage < 605) _goToPage(_currentPage + 1);
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
                  event.logicalKey == LogicalKeyboardKey.pageUp) {
                if (_currentPage > 1) _goToPage(_currentPage - 1);
                return KeyEventResult.handled;
              }
            }
            return KeyEventResult.ignored;
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              // MAIN CONTENT: Besmele Bar (üstte, ayetlerin üstünü kapatmaz) + Mushaf / Ayah List View
              Positioned.fill(
                bottom: 110 + MediaQuery.of(context).padding.bottom, // Space for Bottom Player Bar
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : Column(
                        children: [
                          if (_isPlayingBesmele)
                            const BesmelePlaybackBanner(),
                          Expanded(
                            child: _isMushafView
                                ? _buildMushafPageView()
                                : _buildAyahListView(),
                          ),
                        ],
                      ),
              ),

              // 2-SECOND PAGE COMPLETION NOTIFICATION BANNER
              if (_isPageTransitioning && _transitionBannerText != null)
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 120,
                  child: AnimatedOpacity(
                    opacity: _isPageTransitioning ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 250),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF165241).withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(20),
                        border:
                            Border.all(color: AppColors.gold400, width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle_rounded,
                              color: AppColors.gold400, size: 20),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              _transitionBannerText!,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13.5),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Masaüstü İleri / Geri Sayfa Butonları (Sol: Sonraki, Sağ: Önceki)
              if (isDesktopMushafPlatform && _currentPage < 605)
                Positioned(
                  left: 14,
                  top: 0,
                  bottom: 120,
                  child: Center(
                    child: DesktopMushafNavButton(
                      icon: Icons.chevron_left_rounded,
                      tooltip: 'Sonraki Sayfa (Sol Ok)',
                      onPressed: () => _goToPage(_currentPage + 1),
                      isDark: isDark,
                    ),
                  ),
                ),
              if (isDesktopMushafPlatform && _currentPage > 1)
                Positioned(
                  right: 14,
                  top: 0,
                  bottom: 120,
                  child: Center(
                    child: DesktopMushafNavButton(
                      icon: Icons.chevron_right_rounded,
                      tooltip: 'Önceki Sayfa (Sağ Ok)',
                      onPressed: () => _goToPage(_currentPage - 1),
                      isDark: isDark,
                    ),
                  ),
                ),

              // FLOATING MUKABELE CONTROL BAR
              Positioned(
                left: 16,
                right: 16,
                bottom: 16 + MediaQuery.of(context).padding.bottom,
                child: _buildMukabeleBottomBar(
                    bottomBarBg, titleColor, goldAccent, isDark),
              ),

              // TILAVET SECDESI FLOATING BANNER
              if (TilavetSecdesiData.getSecdeForPage(_currentPage) != null &&
                  !_dismissedBannerForCurrentPage)
                Positioned(
                  top: 8,
                  left: 0,
                  right: 0,
                  child: TilavetSecdesiFloatingBanner(
                    secdeItem:
                        TilavetSecdesiData.getSecdeForPage(_currentPage)!,
                    onDismiss: () {
                      setState(() {
                        _dismissedBannerForCurrentPage = true;
                      });
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMushafPageView() {
    return PageView.builder(
      controller: _pageController,
      reverse: true,
      itemCount: 605,
      onPageChanged: (index) {
        final newPage = index + 1;
        if (newPage != _currentPage) {
          _goToPage(newPage);
        }
      },
      itemBuilder: (context, index) {
        final pageNum = index + 1;
        final pageAsync = ref.watch(quranPageDataProvider(pageNum));
        return pageAsync.when(
          data: (data) => MushafPageWidget(pageData: data),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Sayfa yüklenemedi: $e')),
        );
      },
    );
  }

  Widget _buildAyahListView() {
    final fontFamily = ref.watch(quranFontFamilyProvider);
    final fontSize = ref.watch(quranFontSizeProvider);
    final lineHeight = ref.watch(quranLineHeightProvider);
    final isBoldArabic = ref.watch(isBoldArabicProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView.builder(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _pageVerses.length,
      itemBuilder: (context, index) {
        final verse = _pageVerses[index];
        final isActive = index == _currentVerseIndex;
        final key = _verseKeys.putIfAbsent(index, () => GlobalKey());
        final meal = _pageMeals['${verse.sureId}_${verse.ayetId}'] ?? '';
        final secdeItem = TilavetSecdesiData.getSecdeForVerse(
          verse.sureId,
          verse.ayetId,
        );
        final isSecdeAyah = secdeItem != null;

        return Container(
          key: key,
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isActive
                ? (isDark ? const Color(0xFF1E2824) : const Color(0xFFE8F3EE))
                : (isSecdeAyah
                    ? (isDark ? const Color(0xFF1F1914) : const Color(0xFFFFFBEB))
                    : (isDark ? const Color(0xFF181B20) : Colors.white)),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive
                  ? (isDark ? AppColors.gold400 : const Color(0xFF2D7D76))
                  : (isSecdeAyah
                      ? const Color(0xFFD97706).withValues(alpha: 0.65)
                      : (isDark ? AppColors.darkBorder : const Color(0xFFE5DFC9))),
              width: isActive || isSecdeAyah ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Ayah Header Band
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? (isDark
                                      ? AppColors.gold500
                                      : const Color(0xFF2D7D76))
                                  : (isDark
                                      ? Colors.white12
                                      : Colors.black.withValues(alpha: 0.06)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${verse.sure?.sureNameTurkish ?? ''} • ${verse.ayetId}. Âyet',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isActive
                                    ? (isDark ? Colors.black : Colors.white)
                                    : (isDark ? Colors.white70 : Colors.black87),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        if (isSecdeAyah) ...[
                          const SizedBox(width: 6),
                          ZikirceSecdeInlineBadge(
                            isDark: isDark,
                            compact: true,
                            label: '${secdeItem.no}. Secde Âyeti',
                            onTap: () => TilavetSecdesiGuideSheet.show(
                              context,
                              initialSecdeItem: secdeItem,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isActive) ...[
                        const Icon(Icons.volume_up_rounded,
                            color: AppColors.gold400, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          _isPlayingBesmele ? 'Besmele-i Şerif' : 'Okunuyor',
                          style: TextStyle(
                              color: isDark
                                  ? AppColors.gold400
                                  : const Color(0xFF2D7D76),
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                      ],
                      InkWell(
                        onTap: () {
                          HapticService.selectionClick();
                          final surahTitle =
                              verse.sure?.sureNameTurkish ?? '${verse.sureId}. Sûre';
                          ZikirSharePreviewModal.show(
                            context: context,
                            zikirName: '$surahTitle • ${verse.ayetId}. Âyet',
                            arabicText: _isMealOnlyView
                                ? null
                                : QuranWordHighlighter.cleanArabicText(verse.ayetText),
                            virtue: meal.isNotEmpty ? meal : verse.ayetText,
                            customSource: '$surahTitle Sûresi, ${verse.ayetId}. Âyet',
                            category: 'Kur’an',
                            currentCount: _currentPage,
                            targetCount: 604,
                            totalCount: _currentPage,
                            initialTheme: ZikirShareCardTheme.emeraldSufi,
                            initialShowCounterStats: false,
                          );
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: (isDark
                                    ? AppColors.gold400
                                    : const Color(0xFF2D7D76))
                                .withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: (isDark
                                      ? AppColors.gold400
                                      : const Color(0xFF2D7D76))
                                  .withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.share_rounded,
                                size: 13,
                                color: isDark
                                    ? AppColors.gold400
                                    : const Color(0xFF2D7D76),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Paylaş',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? AppColors.gold400
                                      : const Color(0xFF2D7D76),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Arabic Words Synchronized Text (hidden when Sadece Meal mode is active)
              if (!_isMealOnlyView)
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: _buildSynchronizedArabicAyahText(
                    verse: verse,
                    verseIndex: index,
                    isActiveVerse: isActive,
                    fontFamily: fontFamily,
                    fontSize: fontSize,
                    lineHeight: lineHeight,
                    isDark: isDark,
                    isBoldArabic: isBoldArabic,
                  ),
                ),

              // Turkish Meal Text
              if (meal.isNotEmpty) ...[
                if (!_isMealOnlyView) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Colors.black12),
                  const SizedBox(height: 8),
                ],
                InkWell(
                  onTap: _isMealOnlyView ? () => _prepareAndPlayVerse(index) : null,
                  borderRadius: BorderRadius.circular(8),
                  child: Text(
                    meal,
                    style: TextStyle(
                      fontSize: _isMealOnlyView ? 16.5 : 14.5,
                      height: 1.55,
                      fontWeight: _isMealOnlyView && isActive
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: isDark
                          ? const Color(0xFFE5E7EB)
                          : const Color(0xFF1F2937),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
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

  Widget _buildSynchronizedArabicAyahText({
    required QuranAyatModel verse,
    required int verseIndex,
    required bool isActiveVerse,
    required String fontFamily,
    required double fontSize,
    required double lineHeight,
    required bool isDark,
    required bool isBoldArabic,
  }) {
    final cleanWordsData = _parseAyahWords(verse.ayetText);
    final divineColor = QuranWordHighlighter.getDivineWordColor(isDark);
    final waqfColor =
        isDark ? const Color(0xFFFF5252) : const Color(0xFFD32F2F);
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
                final isWordActive =
                    isActiveVerse && _activeWordOrder == wordOrder;

                final wordData = cleanWordsData[wIdx];
                final pureWord = wordData.pureWord;
                final stops = wordData.stops;
                final isDivine = pureWord.isNotEmpty &&
                    QuranWordHighlighter.isDivineWord(pureWord);

                final activeArrowTextColor =
                    QuranWordHighlighter.getDiyanetTrackingWordColor(isDark);
                final activeArrowShadows =
                    QuranWordHighlighter.getDiyanetTrackingShadows(isDark);

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
                              ? const EdgeInsets.fromLTRB(5, 2, 5, 8)
                              : const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: (!isArrowTracking && isWordActive)
                                ? (isDark
                                    ? const Color(0xFF059669)
                                    : const Color(0xFF10B981))
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              if (!isArrowTracking && isWordActive)
                                BoxShadow(
                                  color: const Color(0xFF10B981)
                                      .withValues(alpha: 0.6),
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
                                pureWord,
                                style: TextStyle(
                                  fontFamily: fontFamily,
                                  fontSize: fontSize,
                                  fontWeight: isBoldArabic
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
                                  shadows: (isWordActive && isArrowTracking)
                                      ? activeArrowShadows
                                      : null,
                                  height: 1.6,
                                  letterSpacing: -0.1,
                                ),
                              ),
                              if (isArrowTracking && isWordActive)
                                Positioned(
                                  bottom: -6,
                                  left: 0,
                                  right: 0,
                                  child: QuranWordTrackingPointer(
                                    isDark: isDark,
                                    height: 7.5,
                                    durationMs: _activeWordDurationMs,
                                    playbackSpeed: _playbackSpeed,
                                    isPlaying: _isPlaying,
                                    wordIdentity:
                                        '${verse.sureId}_${verse.ayetId}_$wordOrder',
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
                              fontSize: fontSize * 0.85,
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
                isHighlight: isActiveVerse,
                isSecde: TilavetSecdesiData.isSecdeVerse(
                  verse.sureId,
                  verse.ayetId,
                ),
                fontFamily: fontFamily,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMukabeleBottomBar(
      Color bg, Color titleColor, Color gold, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: gold.withValues(alpha: 0.4), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Play / Pause / Buffering Button
          IconButton(
            icon: _isBuffering
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        color: gold, strokeWidth: 2.5),
                  )
                : Icon(
                    _isPlaying
                        ? Icons.pause_circle_filled_rounded
                        : Icons.play_circle_fill_rounded,
                    color: gold,
                    size: 38,
                  ),
            onPressed: _togglePlayPause,
          ),

          // Previous & Next Ayah Buttons
          IconButton(
            icon: Icon(
              Icons.skip_previous_rounded,
              color: _isPlayingBesmele
                  ? titleColor.withValues(alpha: 0.3)
                  : titleColor,
              size: 24,
            ),
            tooltip: 'Önceki Âyet',
            onPressed: _isPlayingBesmele ? null : _previousAyah,
          ),
          IconButton(
            icon: Icon(
              Icons.skip_next_rounded,
              color: _isPlayingBesmele
                  ? titleColor.withValues(alpha: 0.3)
                  : titleColor,
              size: 24,
            ),
            tooltip: 'Sonraki Âyet',
            onPressed: _isPlayingBesmele ? null : _nextAyah,
          ),

          // Info Column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _isPlayingBesmele
                      ? 'Besmele-i Şerif'
                      : (_pageVerses.isNotEmpty &&
                              _currentVerseIndex < _pageVerses.length
                          ? '${_pageVerses[_currentVerseIndex].ayetId}. Âyet'
                          : 'Sayfa $_currentPage'),
                  style: TextStyle(
                    color: titleColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  _isPlayingBesmele
                      ? 'Dinleme Başlangıcı'
                      : (_isMushafView ? 'Mushaf Modu' : 'Liste Modu'),
                  style: TextStyle(
                      color: gold, fontSize: 10.5, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),

          // Playback Speed Button (0.75x, 1.0x, 1.25x, 1.5x)
          InkWell(
            onTap: _cyclePlaybackSpeed,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white12
                    : Colors.black.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${_playbackSpeed}x',
                style: TextStyle(
                  color: titleColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CleanWordInfo {
  final String pureWord;
  final List<String> stops;

  const _CleanWordInfo({required this.pureWord, required this.stops});
}
