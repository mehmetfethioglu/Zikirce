import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../../../../core/constants/surah_data_provider.dart';
import '../../../../core/services/audio_download_service.dart';
import '../../../../core/services/audio_sync_service.dart';
import '../../../../core/services/quran_page_repository.dart';
import '../../../../core/utils/quran_word_highlighter.dart';
import '../../../kuran/presentation/widgets/besmele_playback_banner.dart';
import '../../../kuran/presentation/widgets/zikirce_ayah_stop_marker.dart';
import '../../../kuran/providers/kuran_providers.dart';
import '../../../settings/providers/settings_provider.dart';

enum TalimTargetType { page, surah, juz, ashr }

class _CleanWordInfo {
  final String pureWord;
  final List<String> stops;
  const _CleanWordInfo({required this.pureWord, required this.stops});
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

  int _currentVerseIndex = 0;
  int _activeWordOrder = 0;
  bool _isPlaying = false;
  bool _isAudioBuffering = false;
  bool _isPlayingBesmele = false;
  int _targetVerseIndexAfterBesmele = 0;
  double _playbackSpeed = 1.0;
  int _repeatMode = 1; // 1 = Once, 3 = 3x, 5 = 5x, 0 = Infinite for current ayah
  bool _isScopeLoopEnabled = false; // Loop whole Surah/Juz/Ashr/Page when finished
  bool _autoAdvancePage = true; // Auto advance to next page in Page mode
  late int _currentPageId;
  int _currentAyahPlayCount = 0;
  bool _showMeal = true;
  bool _maskingMode = false; // Ezber için henüz okunmayan kelimeleri gizleme
  double _fontSize = 26.0;
  bool _isBatchDownloading = false;
  bool _isCurrentScopeDownloaded = false;

  StreamSubscription? _posSub;
  StreamSubscription? _playerStateSub;

  @override
  void initState() {
    super.initState();
    _currentPageId = widget.targetId;
    _fontSize = ref.read(quranFontSizeProvider);
    _initDataAndPlayer();
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
        final startVerse = _verses[_currentVerseIndex];
        if (_shouldPlayBesmeleForVerse(startVerse, isSessionStart: true)) {
          _playBesmeleThenVerse(_currentVerseIndex);
        } else {
          _prepareAndPlayVerse(_currentVerseIndex);
        }
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

  void _initAudioListeners() {
    _posSub = _player.positionStream.listen((pos) {
      if (_isPlayingBesmele) return;
      if (_verses.isEmpty || _currentVerseIndex >= _verses.length) return;
      final currentVerse = _verses[_currentVerseIndex];
      final ms = pos.inMilliseconds.toDouble();

      final activeWord = AudioSyncService.getActiveWordOrder(
        currentVerse.sureId,
        currentVerse.ayetId,
        ms,
      );

      if (activeWord != _activeWordOrder && mounted) {
        setState(() {
          _activeWordOrder = activeWord;
        });
        _scrollToActiveWord();
      }
    });

    _playerStateSub = _player.playerStateStream.listen((state) {
      if (!mounted) return;
      setState(() {
        _isPlaying = state.playing;
        _isAudioBuffering = state.processingState == ProcessingState.buffering ||
            state.processingState == ProcessingState.loading;
      });

      if (state.processingState == ProcessingState.completed) {
        _handleVerseCompleted();
      }
    });
  }

  void _handleVerseCompleted() {
    if (_isPlayingBesmele) {
      _isPlayingBesmele = false;
      if (mounted) {
        setState(() {});
      }
      _prepareAndPlayVerse(_targetVerseIndexAfterBesmele);
      return;
    }

    _currentAyahPlayCount++;
    if (_repeatMode == 0 || (_repeatMode > 1 && _currentAyahPlayCount < _repeatMode)) {
      // Repeat current verse
      _player.seek(Duration.zero);
      _player.play();
    } else {
      // Next verse
      _currentAyahPlayCount = 0;
      if (_currentVerseIndex < _verses.length - 1) {
        final nextVerse = _verses[_currentVerseIndex + 1];
        if (_shouldPlayBesmeleForVerse(nextVerse, isSessionStart: false)) {
          _playBesmeleThenVerse(_currentVerseIndex + 1);
        } else {
          _goToVerse(_currentVerseIndex + 1);
        }
      } else {
        // Finished all verses in scope
        if (_isScopeLoopEnabled) {
          // Loop entire scope
          _goToVerse(0);
        } else if (widget.targetType == TalimTargetType.page && _autoAdvancePage && _currentPageId < 604) {
          _loadAndPlayNextPage();
        } else {
          setState(() {
            _isPlaying = false;
            _activeWordOrder = 0;
          });
        }
      }
    }
  }

  Future<void> _loadAndPlayNextPage() async {
    if (_currentPageId >= 604) {
      setState(() => _isPlaying = false);
      return;
    }
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
      final firstVerse = _verses[0];
      if (_shouldPlayBesmeleForVerse(firstVerse, isSessionStart: false)) {
        _playBesmeleThenVerse(0);
      } else {
        _prepareAndPlayVerse(0);
      }
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

  Future<void> _playBesmeleThenVerse(int targetIndex) async {
    _targetVerseIndexAfterBesmele = targetIndex;
    _isPlayingBesmele = true;
    if (mounted) {
      setState(() {
        _isAudioBuffering = true;
        _activeWordOrder = 0;
      });
    }

    // Stop any conflicting background Quran player
    try {
      ref.read(kuranAudioNotifierProvider.notifier).stop();
    } catch (_) {}

    try {
      final localPath = await AudioDownloadService.getLocalAudioPath(1, 1);
      final localFile = File(localPath);

      bool loadedLocally = false;
      if (localFile.existsSync() && localFile.lengthSync() > 1024) {
        try {
          await _player.setFilePath(localPath);
          loadedLocally = true;
        } catch (_) {
          loadedLocally = false;
        }
      }

      if (!loadedLocally) {
        final diyanetUrl = AudioDownloadService.getDiyanetAudioUrl(1, 1, pageId: 1);
        try {
          await _player.setUrl(diyanetUrl);
        } catch (_) {
          final fallbackUrl = AudioDownloadService.getFallbackAudioUrl(1, 1);
          await _player.setUrl(fallbackUrl);
        }
        unawaited(AudioDownloadService.ensureVerseDownloaded(1, 1, pageId: 1));
      }

      await _player.setSpeed(_playbackSpeed);
      await _player.play();
    } catch (e) {
      debugPrint('[KelimeTakipliDinlemeScreen] Besmele playback fallback: $e');
      _isPlayingBesmele = false;
      if (mounted) {
        setState(() {});
      }
      _prepareAndPlayVerse(targetIndex);
    }
  }

  Future<void> _prepareAndPlayVerse(int verseIndex, {int seekMs = 0}) async {
    if (verseIndex < 0 || verseIndex >= _verses.length) return;

    _isPlayingBesmele = false;
    _currentVerseIndex = verseIndex;
    final verse = _verses[verseIndex];

    if (mounted) {
      setState(() {
        _isAudioBuffering = true;
        _activeWordOrder = 0;
      });
    }

    // Stop any conflicting background Quran player
    try {
      ref.read(kuranAudioNotifierProvider.notifier).stop();
    } catch (_) {}

    try {
      final localPath = await AudioDownloadService.getLocalAudioPath(verse.sureId, verse.ayetId);
      final localFile = File(localPath);

      bool loadedLocally = false;
      if (localFile.existsSync() && localFile.lengthSync() > 1024) {
        try {
          await _player.setFilePath(localPath);
          loadedLocally = true;
        } catch (e) {
          debugPrint('[KelimeTakipliDinlemeScreen] Corrupt local file, falling back to CDN: $e');
          try {
            localFile.deleteSync();
          } catch (_) {}
          loadedLocally = false;
        }
      }

      if (!loadedLocally) {
        // 1. Primary Source: Diyanet CDN (Osman Şahin / Mehmet Çevik) - EXACT MATCH FOR WORD TIMESTAMPS
        final diyanetUrl = AudioDownloadService.getDiyanetAudioUrl(
          verse.sureId,
          verse.ayetId,
          pageId: verse.page,
        );

        bool urlSet = false;
        try {
          await _player.setUrl(diyanetUrl);
          urlSet = true;
        } catch (e) {
          debugPrint('[KelimeTakipliDinlemeScreen] Diyanet CDN failed, trying fallback: $e');
          final fallbackUrl = AudioDownloadService.getFallbackAudioUrl(verse.sureId, verse.ayetId);
          try {
            await _player.setUrl(fallbackUrl);
            urlSet = true;
          } catch (e2) {
            debugPrint('[KelimeTakipliDinlemeScreen] Fallback URL also failed: $e2');
          }
        }

        if (!urlSet) {
          // Retry once after brief delay for initial network socket wake-up
          await Future.delayed(const Duration(milliseconds: 350));
          try {
            await _player.setUrl(diyanetUrl);
            urlSet = true;
          } catch (_) {
            final fallbackUrl = AudioDownloadService.getFallbackAudioUrl(verse.sureId, verse.ayetId);
            await _player.setUrl(fallbackUrl);
            urlSet = true;
          }
        }

        // Cache in background for offline use
        unawaited(AudioDownloadService.ensureVerseDownloaded(
          verse.sureId,
          verse.ayetId,
          pageId: verse.page,
        ));
      }

      await _player.setSpeed(_playbackSpeed);

      if (seekMs > 0) {
        await _player.seek(Duration(milliseconds: seekMs));
      }

      await _player.play();
      _scrollToActiveVerse();

      // Smart Pre-buffering: Prefetch next verse in background
      if (verseIndex + 1 < _verses.length) {
        final nextVerse = _verses[verseIndex + 1];
        unawaited(AudioDownloadService.ensureVerseDownloaded(
          nextVerse.sureId,
          nextVerse.ayetId,
          pageId: nextVerse.page,
        ));
      }
    } catch (e) {
      debugPrint('[KelimeTakipliDinlemeScreen] Playback error: $e');
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _isAudioBuffering = false;
        });
      }
    }
  }

  void _goToVerse(int index) {
    if (_isPlayingBesmele) return;
    if (index < 0 || index >= _verses.length) return;
    _currentAyahPlayCount = 0;
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
      _player.pause();
    } else {
      if (_player.processingState == ProcessingState.completed) {
        _prepareAndPlayVerse(_currentVerseIndex);
      } else {
        _player.play();
      }
    }
  }

  void _cyclePlaybackSpeed() {
    const speeds = [0.75, 1.0, 1.25, 1.5];
    final nextIndex = (speeds.indexOf(_playbackSpeed) + 1) % speeds.length;
    final newSpeed = speeds[nextIndex];
    setState(() {
      _playbackSpeed = newSpeed;
    });
    _player.setSpeed(newSpeed);
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
      _currentAyahPlayCount = 0;
    });
  }

  void _onWordTapped(int verseIndex, int wordOrder) {
    if (_isPlayingBesmele) return;
    final verse = _verses[verseIndex];
    final ts = AudioSyncService.getWordTimestamp(verse.sureId, verse.ayetId, wordOrder);

    if (verseIndex == _currentVerseIndex && _player.duration != null) {
      if (ts != null) {
        final seekTarget = (ts.startTime - 25.0).clamp(0.0, 999999.0).toInt();
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
              _showMeal ? Icons.translate_rounded : Icons.g_translate_rounded,
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

  static const Set<String> _stopSigns = {
    '\u0615', // Small High Tah (Tı - ط)
    '\u0617', // Small High Zain (Zâ - ز)
    '\u06D6', // Small High Ligature Sad With Lam With Alef Maksura (Sâd - ص)
    '\u06D7', // Small High Qaf (Qaf - ق)
    '\u06D8', // Small High Meem (Mîm - م / Lâzım)
    '\u06D9', // Small High Lam Alef (Lâ - لا)
    '\u06DA', // Small High Jeem (Cim - ج)
    '\u06DB', // Small High Three Dots (Mu'anaqa 3 nokta - ۛ)
    '\u06DC', // Small High Seen (Tı / Sin - ۜ)
    '\u06DF', // Small High Rounded Zero (Ayn - ۟)
    '\u06E2', // Small High Meem Isolated (Mîm - ۢ)
    '\u06E3', // Small Low Seen (Sin - ۣ)
    '\u06E7', // Small High Qaf / Kef (Kef - ۧ)
    '\u08D5', // Arabic Small High Sad (Sâd - ࣕ)
    '\u08D6', // Arabic Small High Ain (Ayn / Rükû - ࣖ)
    '\u08D7', // Arabic Small High Qaf (Qaf - ࣗ)
    '\u08DE', // Arabic Small High Word Kaph (Kef - ࣞ)
  };

  static String mapStopCharacter(String char, String fontFamily) {
    if (fontFamily == 'AmasyaAbay' || fontFamily == 'mushaf') {
      switch (char) {
        case '\u0615': return '\u06DC';
        case '\u0617': return '\u0617';
        case '\u06D6':
        case '\u08D5': return '\u06D6';
        case '\u06D7':
        case '\u08D7': return '\u06D7';
        case '\u06D8':
        case '\u06E2': return '\u06E2';
        case '\u06D9': return '\u06D9';
        case '\u06DA': return '\u06DA';
        case '\u06DB': return '\u06DB';
        case '\u06DC': return '\u06DC';
        case '\u06DF':
        case '\u08D6': return '\u06DF';
        case '\u06E3': return '\u06E3';
        case '\u06E7':
        case '\u08DE': return '\u06E7';
        default: return char;
      }
    } else if (fontFamily == 'mushaf_bold') {
      switch (char) {
        case '\u0615':
        case '\u06DC': return '\u0615';
        case '\u0617': return '\u0617';
        case '\u06D6':
        case '\u08D5': return '\u06D6';
        case '\u06D7':
        case '\u08D7': return '\u06D7';
        case '\u06D8':
        case '\u06E2': return '\u06D8';
        case '\u06D9': return '\u06D9';
        case '\u06DA': return '\u06DA';
        case '\u06DB': return '\u06DB';
        case '\u06DF':
        case '\u08D6': return '\u08D6';
        case '\u06E3': return '\u06E3';
        case '\u06E7':
        case '\u08DE': return '\u06E7';
        default: return char;
      }
    }
    return char;
  }

  List<_CleanWordInfo> _parseAyahWords(String ayetText) {
    // 1. Normalize special unicode characters & non-breaking spaces BEFORE splitting!
    final normalized = ayetText
        .replaceAll(String.fromCharCode(0x10EFD), '')
        .replaceAll(String.fromCharCode(0x10EFE), '')
        .replaceAll(String.fromCharCode(0x10EFF), '')
        .replaceAll('\uD803\uDEFD', '')
        .replaceAll('\uD803\uDEFE', '')
        .replaceAll('\uD803\uDEFF', '')
        .replaceAll('\uEE00', '')
        .replaceAll('\uEE01', '')
        .replaceAll('\u08CF', '')
        .replaceAll('\u08D9', '')
        .replaceAll('\u06EA', '')
        .replaceAll('\u06EB', '')
        .replaceAll('\u06EC', '')
        .replaceAll('\u200C', '')
        .replaceAll('\u200D', '')
        .replaceAll('\u200E', '')
        .replaceAll('\u200F', '')
        .replaceAll('\u061C', '')
        .replaceAll('\u00A0', ' ')
        .replaceAll('\u202F', ' ')
        .replaceAll('\u2007', ' ')
        .replaceAll('\u200B', ' ')
        .replaceAll('ی', 'ي')
        .replaceAll('D', 'ْد');

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
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: isWordActive
                                ? (isDark ? const Color(0xFF059669) : const Color(0xFF10B981))
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              if (isWordActive)
                                BoxShadow(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.6),
                                  blurRadius: 12,
                                  spreadRadius: 1,
                                  offset: const Offset(0, 2),
                                ),
                            ],
                          ),
                          child: Text(
                            isMasked ? '••••' : pureWord,
                            style: TextStyle(
                              fontFamily: fontFamily,
                              fontSize: _fontSize,
                              fontWeight: isBoldArabic ? FontWeight.bold : FontWeight.normal,
                              color: isWordActive
                                  ? Colors.white
                                  : (isDivine ? divineColor : (isDark ? Colors.white : const Color(0xFF1E2B27))),
                              height: 1.6,
                            ),
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
