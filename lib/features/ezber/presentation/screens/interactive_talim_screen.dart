import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import '../../../../core/database/app_database.dart';
import '../../../../core/constants/surah_data_provider.dart';
import '../../../../core/providers/database_provider.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../../core/services/quran_page_repository.dart';
import '../../../../core/utils/quran_word_highlighter.dart';
import '../../../kuran/providers/kuran_providers.dart';
import '../../domain/smart_distractors_service.dart';
import '../../domain/talim_audio_controller.dart';
import '../../domain/verse_chunker_service.dart';

class InteractiveTalimScreen extends ConsumerStatefulWidget {
  final String modeKey; // 'Yazarak' | 'Bulmaca' | 'Bosluk' | 'Baglama' | 'Talim'
  final int pageNumber;
  final int initialVerseIndex;

  const InteractiveTalimScreen({
    super.key,
    required this.modeKey,
    required this.pageNumber,
    this.initialVerseIndex = 0,
  });

  @override
  ConsumerState<InteractiveTalimScreen> createState() =>
      _InteractiveTalimScreenState();
}

class _InteractiveTalimScreenState extends ConsumerState<InteractiveTalimScreen>
    with SingleTickerProviderStateMixin {
  late final TalimAudioController _audioController;
  final VerseChunkerService _chunkerService = VerseChunkerService();

  bool _isLoading = true;
  List<QuranAyatModel> _verses = [];
  int _currentVerseIndex = 0;

  // Chunks for the current verse
  List<VerseChunk> _chunks = [];
  int _currentChunkIndex = 0; // 0-indexed internally

  // Practice Metrics
  int _totalQuestions = 0;
  int _correctAnswers = 0;

  // Flash animations
  Color? _flashColor;
  double _flashOpacity = 0.0;

  // Mode 1: Bulmaca / Yazarak State
  List<String> _constructedWords = [];
  List<String> _wordPool = [];

  // Mode 2: Bosluk State
  String _targetBlankWord = '';
  String _maskedVerseText = '';
  List<_BlankOption> _blankOptions = [];

  // Mode 3: Baglama / Sonraki Ayet State
  QuranAyatModel? _targetNextVerse;
  List<_VerseOption> _nextVerseOptions = [];
  bool _lastBaglamaWasCorrect = false;

  // Sayfa Sonu Resitali State
  bool _isResitalActive = false;
  int _resitalScore = 0;
  bool _isPromotionAchieved = false;

  // Normalized Mode Key
  String get _normalizedMode {
    if (widget.modeKey == 'Bulmaca' || widget.modeKey == 'Yazarak') {
      return 'Yazarak';
    }
    if (widget.modeKey == 'Bosluk') return 'Bosluk';
    if (widget.modeKey == 'Baglama' || widget.modeKey == 'Sonraki Ayet') {
      return 'Baglama';
    }
    return 'Talim';
  }

  String get _modeTitle {
    switch (_normalizedMode) {
      case 'Yazarak':
        return 'Kelime Bulmaca';
      case 'Bosluk':
        return 'Boşluk Doldurma';
      case 'Baglama':
        return 'Sonraki Ayet & Ulama';
      case 'Talim':
      default:
        return 'Seslendirme & Tilavet';
    }
  }

  String get _modeEmoji {
    switch (_normalizedMode) {
      case 'Yazarak':
        return '🧩';
      case 'Bosluk':
        return '✍️';
      case 'Baglama':
        return '🔗';
      case 'Talim':
      default:
        return '🎙️';
    }
  }

  Color get _modeColor {
    switch (_normalizedMode) {
      case 'Yazarak':
        return const Color(0xFF10B981);
      case 'Bosluk':
        return const Color(0xFFF59E0B);
      case 'Baglama':
        return const Color(0xFF0284C7);
      case 'Talim':
      default:
        return const Color(0xFFA855F7);
    }
  }

  @override
  void initState() {
    super.initState();
    _audioController = TalimAudioController();
    _currentVerseIndex = widget.initialVerseIndex;
    _loadPageData();
  }

  @override
  void dispose() {
    _audioController.dispose();
    super.dispose();
  }

  Future<void> _loadPageData() async {
    setState(() => _isLoading = true);
    try {
      final pageData = await QuranPageRepository.getPage(widget.pageNumber);
      if (mounted) {
        setState(() {
          _verses = pageData.quranAyats;
          if (_currentVerseIndex >= _verses.length) {
            _currentVerseIndex = 0;
          }
          _isLoading = false;
        });
        _setupCurrentVerseAndChunk();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ayet verileri yüklenemedi: $e')),
        );
      }
    }
  }

  void _setupCurrentVerseAndChunk() {
    if (!mounted) return;
    if (_verses.isEmpty || _currentVerseIndex >= _verses.length) {
      _showResitalSummary();
      return;
    }

    final currentVerse = _verses[_currentVerseIndex];
    _chunks = _chunkerService.chunkVerse(
      currentVerse.ayetText,
      maxWordThreshold: 15,
      targetFallbackChunkSize: 10,
    );

    if (_currentChunkIndex >= _chunks.length) {
      _currentChunkIndex = 0;
    }

    final currentChunk = _chunks[_currentChunkIndex];

    setState(() {
      _constructedWords = [];
      _wordPool = [];
      _blankOptions = [];
      _nextVerseOptions = [];
    });

    switch (_normalizedMode) {
      case 'Yazarak':
        // Shuffled pool of words from current chunk
        final shuffled = List<String>.from(currentChunk.words)..shuffle();
        setState(() {
          _wordPool = shuffled;
          _constructedWords = [];
        });
        break;

      case 'Bosluk':
        if (currentChunk.words.isNotEmpty) {
          final blankIdx = currentChunk.words.length ~/ 2;
          _targetBlankWord = currentChunk.words[blankIdx];
          _maskedVerseText =
              currentChunk.text.replaceAll(_targetBlankWord, '_____');

          final choices = <String>{_targetBlankWord};
          // Find other distinct words from the page
          for (final v in _verses) {
            final wList = v.ayetText.split(RegExp(r'\s+'));
            for (final w in wList) {
              if (w.isNotEmpty && w != _targetBlankWord && choices.length < 3) {
                choices.add(w);
              }
            }
            if (choices.length >= 3) break;
          }

          final optionList = choices
              .map((c) => _BlankOption(text: c, isCorrectTarget: c == _targetBlankWord))
              .toList()
            ..shuffle();

          setState(() {
            _blankOptions = optionList;
          });
        }
        break;

      case 'Baglama':
        final nextIdx = _currentVerseIndex + 1;
        if (nextIdx < _verses.length) {
          _targetNextVerse = _verses[nextIdx];
          final distractors = SmartDistractorsService.generateDistractors(
            targetVerse: _targetNextVerse!,
            allAvailableVerses: _verses,
            distractorCount: 3,
          );

          final allOptions = <QuranAyatModel>[_targetNextVerse!, ...distractors]..shuffle();

          setState(() {
            _nextVerseOptions = allOptions
                .map((v) => _VerseOption(
                      verse: v,
                      isTarget: v.id == _targetNextVerse!.id ||
                          (v.sureId == _targetNextVerse!.sureId &&
                              v.ayetId == _targetNextVerse!.ayetId),
                    ))
                .toList();
          });

          // Play current verse if initial or previous answer was wrong
          if (!_lastBaglamaWasCorrect || _currentVerseIndex == 0) {
            _audioController.playVerseAudio(
              currentVerse.sureId,
              currentVerse.ayetId,
              pageNumber: widget.pageNumber,
            );
          }
        } else {
          // Reached end of page in Baglama mode
          _advanceToNext();
        }
        break;

      case 'Talim':
      default:
        // Voice training: ready with audio and mic controls
        break;
    }
  }

  void _triggerFlash(Color color) {
    if (!mounted) return;
    setState(() {
      _flashColor = color;
      _flashOpacity = 0.35;
    });
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _flashOpacity = 0.0;
        });
      }
    });
  }

  // --- Handlers for Mode 1: Bulmaca (Word Puzzle) ---
  void _onWordPoolTapped(String word) async {
    if (!mounted) return;
    final currentChunk = _chunks[_currentChunkIndex];
    final nextExpectedIdx = _constructedWords.length;

    if (nextExpectedIdx < currentChunk.words.length &&
        currentChunk.words[nextExpectedIdx] == word) {
      // Correct word tapped!
      HapticService.countTap();
      setState(() {
        _wordPool.remove(word);
        _constructedWords.add(word);
        _totalQuestions++;
        _correctAnswers++;
      });

      // Play word audio slice if available
      final currentVerse = _verses[_currentVerseIndex];
      _audioController.playWordSlice(
        currentVerse.sureId,
        currentVerse.ayetId,
        nextExpectedIdx + 1,
      );

      // Check if chunk is complete
      if (_constructedWords.length == currentChunk.words.length) {
        _triggerFlash(const Color(0xFF10B981));
        HapticService.roundCompleted();

        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;
        await _audioController.playVerseAudioAndWait(
          currentVerse.sureId,
          currentVerse.ayetId,
          pageNumber: widget.pageNumber,
        );
        if (!mounted) return;
        _advanceToNext();
      }
    } else {
      // Wrong word tapped
      HapticService.selectionClick();
      _triggerFlash(const Color(0xFFEF4444));
      setState(() {
        _totalQuestions++;
      });
    }
  }

  void _onConstructedWordTapped(String word) {
    setState(() {
      _constructedWords.remove(word);
      _wordPool.add(word);
    });
  }

  // --- Handlers for Mode 2: Bosluk (Blank Fill) ---
  void _onBlankOptionSelected(_BlankOption option) async {
    if (option.isSelected || !mounted) return;

    setState(() {
      option.isSelected = true;
      _totalQuestions++;
    });

    if (option.isCorrectTarget) {
      // Correct choice
      HapticService.roundCompleted();
      _triggerFlash(const Color(0xFF10B981));
      setState(() {
        _correctAnswers++;
      });

      final currentVerse = _verses[_currentVerseIndex];
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      await _audioController.playVerseAudioAndWait(
        currentVerse.sureId,
        currentVerse.ayetId,
        pageNumber: widget.pageNumber,
      );
      if (!mounted) return;
      _advanceToNext();
    } else {
      // Wrong choice
      HapticService.selectionClick();
      _triggerFlash(const Color(0xFFEF4444));
      // Reveal the correct one
      for (final opt in _blankOptions) {
        if (opt.isCorrectTarget) {
          opt.isRevealed = true;
        }
      }
      setState(() {});

      await Future.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;
      _advanceToNext();
    }
  }

  // --- Handlers for Mode 3: Baglama (Next Verse) ---
  void _onNextVerseOptionSelected(_VerseOption option) async {
    if (option.isSelected || !mounted) return;

    setState(() {
      option.isSelected = true;
      _totalQuestions++;
    });

    if (option.isTarget) {
      // Correct
      _lastBaglamaWasCorrect = true;
      HapticService.roundCompleted();
      _triggerFlash(const Color(0xFF10B981));
      setState(() {
        _correctAnswers++;
      });

      // Play selected correct verse audio to completion
      await _audioController.playVerseAudioAndWait(
        option.verse.sureId,
        option.verse.ayetId,
        pageNumber: widget.pageNumber,
      );
      if (!mounted) return;
      _advanceToNext();
    } else {
      // Wrong
      _lastBaglamaWasCorrect = false;
      HapticService.selectionClick();
      _triggerFlash(const Color(0xFFEF4444));
      for (final opt in _nextVerseOptions) {
        if (opt.isTarget) {
          opt.isRevealed = true;
        }
      }
      setState(() {});

      await Future.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;
      _advanceToNext();
    }
  }

  // --- Advance Logic ---
  void _advanceToNext() {
    if (!mounted) return;
    if (_currentChunkIndex < _chunks.length - 1 && _normalizedMode != 'Baglama') {
      setState(() {
        _currentChunkIndex++;
      });
      _setupCurrentVerseAndChunk();
    } else {
      if (_currentVerseIndex < _verses.length - 1) {
        setState(() {
          _currentVerseIndex++;
          _currentChunkIndex = 0;
        });
        _setupCurrentVerseAndChunk();
      } else {
        _showResitalSummary();
      }
    }
  }

  // --- Sayfa Sonu Resitali ---
  void _showResitalSummary() async {
    if (!mounted) return;
    final score = _totalQuestions > 0
        ? ((_correctAnswers / _totalQuestions) * 100).round()
        : 100;

    final isPromotion = score >= 70;

    setState(() {
      _isResitalActive = true;
      _resitalScore = score;
      _isPromotionAchieved = isPromotion;
    });

    // Save progress to database
    try {
      final db = ref.read(databaseProvider);
      final currentVerse = _verses.isNotEmpty ? _verses[0] : null;

      if (isPromotion) {
        // Promote page in database to Has (state = 3)
        final existingPlan = await (db.select(db.memorizationPlans)
              ..where((t) => t.pageId.equals(widget.pageNumber)))
            .getSingleOrNull();

        if (existingPlan != null) {
          await (db.update(db.memorizationPlans)
                ..where((t) => t.pageId.equals(widget.pageNumber)))
              .write(
            MemorizationPlansCompanion(
              state: const Value(3), // Has
              timesReviewed: Value(existingPlan.timesReviewed + 1),
              lastReviewedDate: Value(DateTime.now()),
            ),
          );
        } else {
          await db.into(db.memorizationPlans).insert(
                MemorizationPlansCompanion(
                  pageId: Value(widget.pageNumber),
                  surahId: Value(currentVerse?.sureId ?? 1),
                  state: const Value(3),
                  timesReviewed: const Value(1),
                  scheduledReviewDate: Value(DateTime.now().add(const Duration(days: 7))),
                  lastReviewedDate: Value(DateTime.now()),
                ),
              );
        }
      }
    } catch (e) {
      debugPrint('[InteractiveTalimScreen] DB update error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final arabicFont = ref.watch(arabicFontFamilyProvider);

    final bg = isDark ? const Color(0xFF0F1714) : const Color(0xFFF7FAF8);
    final cardBg = isDark ? const Color(0xFF1A2621) : Colors.white;
    final borderStroke = isDark ? const Color(0xFF2C3E37) : const Color(0xFFDCE8E3);
    final primaryTextColor = isDark ? const Color(0xFFE8F0EC) : const Color(0xFF1E2B27);
    final secondaryTextColor = isDark ? const Color(0xFFA2B5AD) : const Color(0xFF5E756C);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: bg,
        body: Center(
          child: CircularProgressIndicator(color: _modeColor),
        ),
      );
    }

    final currentVerse = _verses.isNotEmpty && _currentVerseIndex < _verses.length
        ? _verses[_currentVerseIndex]
        : null;
    final surahName = currentVerse?.sure?.sureNameTurkish ??
        SurahDataProvider.getSurahNameForPage(widget.pageNumber);
    final juzNo = currentVerse?.sure?.cuz ??
        SurahDataProvider.getJuzForPage(widget.pageNumber);

    final totalChunks = _chunks.isNotEmpty ? _chunks.length : 1;
    final currentChunkNo = (_currentChunkIndex + 1).clamp(1, totalChunks);

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          // Main Body
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Top Header Bar
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      // Back Button
                      IconButton(
                        icon: Icon(Icons.arrow_back_ios_new_rounded,
                            color: primaryTextColor, size: 20),
                        onPressed: () => Navigator.of(context).pop(),
                      ),

                      // Title & Badge
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              '$surahName Sûresi',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: primaryTextColor,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _modeColor,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '[Parça $currentChunkNo/$totalChunks]',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '$juzNo. Cüz · Sayfa ${widget.pageNumber}',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: secondaryTextColor,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Mode Emoji Badge
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: _modeColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(_modeEmoji, style: const TextStyle(fontSize: 18)),
                      ),
                    ],
                  ),
                ),

                // 2. Mode Title Indicator Pill
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: _modeColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _modeColor.withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_modeEmoji, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 8),
                      Text(
                        _modeTitle,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _modeColor,
                        ),
                      ),
                    ],
                  ),
                ),

                // 3. Dynamic Practice Mode Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                    child: _buildModeContent(
                      cardBg: cardBg,
                      borderStroke: borderStroke,
                      primaryTextColor: primaryTextColor,
                      secondaryTextColor: secondaryTextColor,
                      arabicFont: arabicFont,
                    ),
                  ),
                ),

                // 4. Bottom Skip/Advance Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _modeColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                      shadowColor: _modeColor.withOpacity(0.3),
                    ),
                    onPressed: _advanceToNext,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'İlerle',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(width: 6),
                        Icon(Icons.arrow_forward_rounded, size: 18),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Green/Red Flash Overlay
          IgnorePointer(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              color: (_flashColor ?? Colors.transparent)
                  .withOpacity(_flashOpacity),
            ),
          ),

          // Sayfa Sonu Resitali Overlay
          if (_isResitalActive)
            _buildResitalOverlay(
              cardBg: cardBg,
              borderStroke: borderStroke,
              primaryTextColor: primaryTextColor,
              secondaryTextColor: secondaryTextColor,
            ),
        ],
      ),
    );
  }

  Widget _buildModeContent({
    required Color cardBg,
    required Color borderStroke,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required String arabicFont,
  }) {
    switch (_normalizedMode) {
      case 'Yazarak':
        return _buildBulmacaMode(
          cardBg: cardBg,
          borderStroke: borderStroke,
          primaryTextColor: primaryTextColor,
          secondaryTextColor: secondaryTextColor,
          arabicFont: arabicFont,
        );
      case 'Bosluk':
        return _buildBoslukMode(
          cardBg: cardBg,
          borderStroke: borderStroke,
          primaryTextColor: primaryTextColor,
          secondaryTextColor: secondaryTextColor,
          arabicFont: arabicFont,
        );
      case 'Baglama':
        return _buildBaglamaMode(
          cardBg: cardBg,
          borderStroke: borderStroke,
          primaryTextColor: primaryTextColor,
          secondaryTextColor: secondaryTextColor,
          arabicFont: arabicFont,
        );
      case 'Talim':
      default:
        return _buildTalimSesliMode(
          cardBg: cardBg,
          borderStroke: borderStroke,
          primaryTextColor: primaryTextColor,
          secondaryTextColor: secondaryTextColor,
          arabicFont: arabicFont,
        );
    }
  }

  // ----------------------------------------------------
  // MODE 1: KELİME BULMACA (WORD PUZZLE & SCRAMBLE)
  // ----------------------------------------------------
  Widget _buildBulmacaMode({
    required Color cardBg,
    required Color borderStroke,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required String arabicFont,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Instruction Pill
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.format_list_numbered_rtl_rounded,
                    color: Color(0xFF10B981), size: 16),
                SizedBox(width: 6),
                Text(
                  'Kelimeleri Orijinal Sırasıyla Diziniz',
                  style: TextStyle(
                    color: Color(0xFF10B981),
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Constructed Words Area (Glassmorphic Emerald Frame)
        Container(
          constraints: const BoxConstraints(minHeight: 120),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF10B981), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF10B981).withOpacity(0.1),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                _constructedWords.isEmpty
                    ? 'Dizilen Kelimeler Burada Belirecektir'
                    : 'Oluşturulan Metin (Geri almak için kelimeye dokunun):',
                style: TextStyle(
                  fontSize: 11,
                  color: secondaryTextColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Directionality(
                textDirection: TextDirection.rtl,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: _constructedWords.map((word) {
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _onConstructedWordTapped(word),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.12),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            word,
                            style: TextStyle(
                              fontFamily: arabicFont,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Hint
        Center(
          child: Text(
            '👇 Sıradaki Kelimeye Dokunun:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: secondaryTextColor,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Shuffled Word Pool Container
        Container(
          constraints: const BoxConstraints(minHeight: 120),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderStroke),
          ),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: _wordPool.map((word) {
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _onWordPoolTapped(word),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF10B981).withOpacity(0.6),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        word,
                        style: TextStyle(
                          fontFamily: arabicFont,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: primaryTextColor,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  // ----------------------------------------------------
  // MODE 2: BOŞLUK DOLDURMA (BLANK FILL)
  // ----------------------------------------------------
  Widget _buildBoslukMode({
    required Color cardBg,
    required Color borderStroke,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required String arabicFont,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Instruction Pill
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.edit_note_rounded,
                    color: Color(0xFFF59E0B), size: 16),
                SizedBox(width: 6),
                Text(
                  'Eksik Kalan Kelimeyi Bulup Tamamlayınız',
                  style: TextStyle(
                    color: Color(0xFFF59E0B),
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Masked Verse Card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF59E0B).withOpacity(0.1),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            _maskedVerseText,
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: arabicFont,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: primaryTextColor,
              height: 1.6,
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Hint
        Center(
          child: Text(
            '👇 Doğru Kelimeyi Seçiniz:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: secondaryTextColor,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Choice Buttons (RTL Wrap)
        Directionality(
          textDirection: TextDirection.rtl,
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: _blankOptions.map((option) {
              Color optBg = const Color(0xFFF59E0B);
              Color optBorder = const Color(0xFFD97706);
              Widget? iconWidget;

              if (option.isSelected) {
                if (option.isCorrectTarget) {
                  optBg = const Color(0xFF10B981);
                  optBorder = const Color(0xFF059669);
                  iconWidget = const Icon(Icons.check_circle_rounded,
                      color: Colors.white, size: 18);
                } else {
                  optBg = const Color(0xFFEF4444);
                  optBorder = const Color(0xFFDC2626);
                  iconWidget = const Icon(Icons.cancel_rounded,
                      color: Colors.white, size: 18);
                }
              } else if (option.isRevealed) {
                optBg = const Color(0xFF059669);
                optBorder = const Color(0xFF34D399);
                iconWidget = const Icon(Icons.check_circle_rounded,
                    color: Colors.white, size: 18);
              }

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _onBlankOptionSelected(option),
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: optBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: optBorder, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: optBg.withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          option.text,
                          style: TextStyle(
                            fontFamily: arabicFont,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        if (iconWidget != null) ...[
                          const SizedBox(width: 8),
                          iconWidget,
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ----------------------------------------------------
  // MODE 3: AYET BAĞLAMA (NEXT VERSE MATCHING)
  // ----------------------------------------------------
  Widget _buildBaglamaMode({
    required Color cardBg,
    required Color borderStroke,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required String arabicFont,
  }) {
    final currentVerse = _verses.isNotEmpty && _currentVerseIndex < _verses.length
        ? _verses[_currentVerseIndex]
        : null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Instruction Pill
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFF0284C7).withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF0284C7).withOpacity(0.3)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.link_rounded, color: Color(0xFF0284C7), size: 16),
                SizedBox(width: 6),
                Text(
                  'Sonraki Ayeti Bulup Bağlayınız',
                  style: TextStyle(
                    color: Color(0xFF0284C7),
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Current Verse Card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF0284C7), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0284C7).withOpacity(0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                'Mevcut Ayet (${currentVerse?.ayetId ?? 1}. Ayet)',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0284C7),
                ),
              ),
              const SizedBox(height: 8),
              Text.rich(
                TextSpan(
                  children: QuranWordHighlighter.buildHighlightedSpans(
                    rawText: currentVerse?.ayetText ?? '',
                    baseStyle: TextStyle(
                      fontFamily: arabicFont,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: primaryTextColor,
                      height: 1.6,
                      letterSpacing: -0.1,
                    ),
                    isDark: isDark,
                    fontFamily: arabicFont,
                    ayahNumber: currentVerse?.ayetNumber,
                    showAyahStopMarker: currentVerse != null,
                  ),
                ),
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Hint
        Center(
          child: Text(
            '👇 Bu Ayetten Sonra Gelen Ayeti Seçin:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: secondaryTextColor,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Next Verse 4 Choices
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _nextVerseOptions.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, idx) {
            final option = _nextVerseOptions[idx];
            Color optBg = cardBg;
            Color optBorder = borderStroke;
            Color textColor = primaryTextColor;
            Widget? iconWidget;

            if (option.isSelected) {
              if (option.isTarget) {
                optBg = const Color(0xFF10B981);
                optBorder = const Color(0xFF059669);
                textColor = Colors.white;
                iconWidget = const Icon(Icons.check_circle_rounded,
                    color: Colors.white, size: 20);
              } else {
                optBg = const Color(0xFFEF4444);
                optBorder = const Color(0xFFDC2626);
                textColor = Colors.white;
                iconWidget = const Icon(Icons.cancel_rounded,
                    color: Colors.white, size: 20);
              }
            } else if (option.isRevealed) {
              optBg = const Color(0xFF059669);
              optBorder = const Color(0xFF34D399);
              textColor = Colors.white;
              iconWidget = const Icon(Icons.check_circle_rounded,
                  color: Colors.white, size: 20);
            }

            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _onNextVerseOptionSelected(option),
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: optBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: optBorder, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.link_rounded,
                            color: Color(0xFF0284C7), size: 16),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          option.verse.ayetText,
                          textAlign: TextAlign.right,
                          textDirection: TextDirection.rtl,
                          style: TextStyle(
                            fontFamily: arabicFont,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                            height: 1.4,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ),
                      if (iconWidget != null) ...[
                        const SizedBox(width: 10),
                        iconWidget,
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // ----------------------------------------------------
  // MODE 4: SESLENDİRME & TİLAVET (VOICE TALIM)
  // ----------------------------------------------------
  Widget _buildTalimSesliMode({
    required Color cardBg,
    required Color borderStroke,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required String arabicFont,
  }) {
    final currentChunk = _chunks.isNotEmpty && _currentChunkIndex < _chunks.length
        ? _chunks[_currentChunkIndex]
        : null;
    final currentVerse = _verses.isNotEmpty && _currentVerseIndex < _verses.length
        ? _verses[_currentVerseIndex]
        : null;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isRecording = _audioController.isRecording;
    final hasUserRecording = _audioController.hasUserRecording;
    final isPlayingUserRec = _audioController.isPlayingUserRecording;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Instruction Pill
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFA855F7).withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFA855F7).withOpacity(0.3)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.record_voice_over_rounded,
                    color: Color(0xFFA855F7), size: 16),
                SizedBox(width: 6),
                Text(
                  'Tilaveti Dinleyin ve Mikrofona Basarak Okuyun',
                  style: TextStyle(
                    color: Color(0xFFA855F7),
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Text Card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFA855F7), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFA855F7).withOpacity(0.1),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            currentChunk?.text ?? currentVerse?.ayetText ?? '',
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: arabicFont,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: primaryTextColor,
              height: 1.6,
              letterSpacing: -0.1,
            ),
          ),
        ),
        const SizedBox(height: 20),

        // User Recording Status Banner
        if (hasUserRecording)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.mic_rounded,
                    color: Color(0xFF10B981), size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Ses Kaydınız Alındı',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: Icon(
                    isPlayingUserRec
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    size: 16,
                  ),
                  label: Text(
                    isPlayingUserRec ? 'Durdur' : 'Kaydımı Dinle',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () async {
                    await _audioController.togglePlayUserRecording();
                    if (mounted) setState(() {});
                  },
                ),
              ],
            ),
          ),
        const SizedBox(height: 20),

        // Core Action Buttons (🎧 Kurra Hafız & 🎙️ Kaydet)
        Row(
          children: [
            // 1. Play Hafiz Audio
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark
                      ? const Color(0xFF004D40)
                      : const Color(0xFFE0F2F1),
                  foregroundColor: const Color(0xFF00897B),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.headphones_rounded, size: 20),
                label: const Text(
                  'Kurra Hafız',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  if (currentVerse != null) {
                    _audioController.playVerseAudio(
                      currentVerse.sureId,
                      currentVerse.ayetId,
                      pageNumber: widget.pageNumber,
                    );
                  }
                },
              ),
            ),
            const SizedBox(width: 14),

            // 2. Mic Record Button
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isRecording
                      ? const Color(0xFFEF4444)
                      : const Color(0xFFA855F7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: isRecording ? 6 : 2,
                  shadowColor: isRecording
                      ? Colors.red.withOpacity(0.5)
                      : const Color(0xFFA855F7).withOpacity(0.3),
                ),
                icon: Icon(
                  isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                  size: 20,
                ),
                label: Text(
                  isRecording ? 'Kaydı Durdur' : 'Kaydet',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                onPressed: () async {
                  if (isRecording) {
                    await _audioController.stopVoiceRecording();
                  } else {
                    await _audioController.startVoiceRecording();
                  }
                  if (mounted) setState(() {});
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ----------------------------------------------------
  // SAYFA SONU RESİTALİ OVERLAY
  // ----------------------------------------------------
  Widget _buildResitalOverlay({
    required Color cardBg,
    required Color borderStroke,
    required Color primaryTextColor,
    required Color secondaryTextColor,
  }) {
    return Container(
      color: Colors.black.withOpacity(0.75),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: _isPromotionAchieved
                ? const Color(0xFF10B981)
                : const Color(0xFFF59E0B),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Trophy / Status Badge
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: _isPromotionAchieved
                    ? const Color(0xFF10B981).withOpacity(0.15)
                    : const Color(0xFFF59E0B).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                _isPromotionAchieved ? '🟢' : '🟡',
                style: const TextStyle(fontSize: 32),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              'Sayfa Sonu Resitali',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: primaryTextColor,
              ),
            ),
            const SizedBox(height: 8),

            // Status message
            Text(
              _isPromotionAchieved
                  ? 'Tebrikler! %$_resitalScore doğruluk oranı ile bu sayfa Has (🟢) seviyesine terfi ettirildi.'
                  : 'Tebrikler! Oturumu tamamladınız (Başarı: %$_resitalScore). Statü yükselmesi için %70 üzeri baraj önerilir.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: secondaryTextColor,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),

            // Score Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _isPromotionAchieved
                    ? const Color(0xFF10B981).withOpacity(0.12)
                    : const Color(0xFFF59E0B).withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Başarı Skoru: %$_resitalScore',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _isPromotionAchieved
                      ? const Color(0xFF10B981)
                      : const Color(0xFFF59E0B),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Save and Close CTA
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isPromotionAchieved
                    ? const Color(0xFF10B981)
                    : const Color(0xFFF59E0B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                minimumSize: const Size(double.infinity, 48),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                'Oturumu Tamamla & Kaydet',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BlankOption {
  final String text;
  final bool isCorrectTarget;
  bool isSelected = false;
  bool isRevealed = false;

  _BlankOption({
    required this.text,
    required this.isCorrectTarget,
  });
}

class _VerseOption {
  final QuranAyatModel verse;
  final bool isTarget;
  bool isSelected = false;
  bool isRevealed = false;

  _VerseOption({
    required this.verse,
    required this.isTarget,
  });
}
