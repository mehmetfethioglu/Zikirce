import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/services/reading_notification_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../domain/entities/book_entity.dart';
import '../../../bookshelf/presentation/providers/bookshelf_provider.dart';
import '../../../reader/presentation/screens/reader_screen.dart';
import '../../../subscription/presentation/providers/subscription_provider.dart';
import '../../../subscription/presentation/widgets/tahrir_pro_sheet.dart';
import '../../domain/speed_reading_models.dart';
import '../providers/speed_reading_provider.dart';
import '../widgets/eye_workshop_sheet.dart';
import '../widgets/lexical_warmup_sheet.dart';

/// Kitap-merkezli Akıcı Mütalaa Akademisi ve Odak Dayanıklılığı Merkezi.
class SpeedReadingAcademyScreen extends ConsumerStatefulWidget {
  const SpeedReadingAcademyScreen({super.key});

  @override
  ConsumerState<SpeedReadingAcademyScreen> createState() =>
      _SpeedReadingAcademyScreenState();
}

class _SpeedReadingAcademyScreenState
    extends ConsumerState<SpeedReadingAcademyScreen> {
  FasilDurationPreset _selectedPreset = FasilDurationPreset.spark5;

  void _onSelectPreset(FasilDurationPreset preset, bool isPro) {
    if (preset.requiresPro && !isPro) {
      TahrirProSheet.show(context);
      return;
    }
    setState(() => _selectedPreset = preset);
  }

  Future<void> _launchGuidedFasil({
    required BookEntity book,
    required bool withWarmup,
    required bool isPro,
    required bool canStartFreeToday,
  }) async {
    if ((_selectedPreset.requiresPro && !isPro) || !canStartFreeToday) {
      TahrirProSheet.show(context);
      return;
    }

    final bookshelfNotifier = ref.read(bookshelfProvider.notifier);
    if (!withWarmup) {
      await Navigator.of(context)
          .push(
            MaterialPageRoute(
              builder: (_) => ReaderScreen(
                book: book,
                initialGuidedFasilMinutes: _selectedPreset.minutes,
              ),
            ),
          )
          .then((_) => bookshelfNotifier.loadBooks());
      return;
    }

    final speedNotifier = ref.read(speedReadingProvider.notifier);
    await LexicalWarmupSheet.show(
      context,
      loadPack: () => speedNotifier.prepareBookWarmupPack(book: book),
      preset: _selectedPreset,
      onLaunchFasil: () {
        if (!mounted) return;
        Navigator.of(context)
            .push(
              MaterialPageRoute(
                builder: (_) => ReaderScreen(
                  book: book,
                  initialGuidedFasilMinutes: _selectedPreset.minutes,
                ),
              ),
            )
            .then((_) => bookshelfNotifier.loadBooks());
      },
    );
  }

  Future<void> _importAndOpenBook() async {
    final notifier = ref.read(bookshelfProvider.notifier);
    final imported = await notifier.importBook();
    if (imported == null || !mounted) return;
    await Navigator.of(context)
        .push(
          MaterialPageRoute(builder: (_) => ReaderScreen(book: imported)),
        )
        .then((_) => notifier.loadBooks());
  }

  Future<void> _startWithShowcaseBook({
    required bool isPro,
    required bool canStartFreeToday,
  }) async {
    final notifier = ref.read(bookshelfProvider.notifier);
    final showcase = await notifier.openOrCreateShowcaseBook(
      filePath: 'sample://kutadgu_bilig',
      title: 'Kutadgu Bilig',
      author: 'Yusuf Has Hacib',
      totalPages: 5,
    );
    if (showcase == null || !mounted) return;

    if (canStartFreeToday || isPro) {
      await _launchGuidedFasil(
        book: showcase,
        withWarmup: true,
        isPro: isPro,
        canStartFreeToday: canStartFreeToday,
      );
    } else {
      await Navigator.of(context)
          .push(
            MaterialPageRoute(builder: (_) => ReaderScreen(book: showcase)),
          )
          .then((_) => notifier.loadBooks());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPro = ref.watch(subscriptionProvider.select((s) => s.isPro));

    final (
      rankInfo,
      welcomeBackMessage,
      lastDetectedDensityId,
      baselineWpm,
      lastBookReadingWpm,
      currentWpm,
      longestFasilMinutes,
      totalFasilsCompleted,
      todayFasilsCount,
    ) = ref.watch(
      speedReadingProvider.select(
        (s) => (
          s.rankInfo,
          s.welcomeBackMessage,
          s.lastDetectedDensityId,
          s.baselineWpm,
          s.lastBookReadingWpm,
          s.currentWpm,
          s.longestFasilMinutes,
          s.totalFasilsCompleted,
          s.todayFasilsCount,
        ),
      ),
    );

    final densityTier = TextDensityTier.fromId(lastDetectedDensityId);
    final targetWpm = ref.watch(
      speedReadingProvider.select((s) => s.targetWpmForDensity(densityTier)),
    );
    final canStartFreeToday = ref.watch(
      speedReadingProvider.select(
        (s) => s.canStartFreeFasilToday(isPro: isPro),
      ),
    );

    final (
      books,
      streakDays,
      dailyGoalMinutes,
      todayMinutesRead,
    ) = ref.watch(
      bookshelfProvider.select(
        (s) => (
          s.books,
          s.habitProfile?.currentStreak ?? 0,
          s.habitProfile?.dailyGoalMinutes ?? 20,
          s.todayMinutesRead,
        ),
      ),
    );

    final (streakShieldCount, isShieldArmedForToday) = ref.watch(
      readingNotificationProvider.select(
        (s) => (s.streakShieldCount, s.isShieldArmedForToday),
      ),
    );

    final BookEntity? activeBook = books.isEmpty
        ? null
        : (books.where((b) => !b.isCompleted).firstOrNull ?? books.first);

    final effectivePreset =
        (_selectedPreset.requiresPro && !isPro)
            ? FasilDurationPreset.spark5
            : _selectedPreset;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Akıcı Mütalaa Akademisi',
              style: GoogleFonts.literata(
                fontSize: 18.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              'Kitap Merkezli Odak & Akış Kalibrasyonu',
              style: GoogleFonts.inter(
                fontSize: 11.5,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
              ),
            ),
          ],
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // a) Birleşik Süreklilik Üst Çubuğu
                _ContinuityTopBar(
                  streakDays: streakDays,
                  todayMinutesRead: todayMinutesRead,
                  dailyGoalMinutes: dailyGoalMinutes,
                  streakShieldCount: streakShieldCount,
                  isShieldArmedForToday: isShieldArmedForToday,
                  rankInfo: rankInfo,
                ),

                // b) Sıcak Karşılama Kartı
                if (welcomeBackMessage != null &&
                    welcomeBackMessage.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _WelcomeBackCard(
                    message: welcomeBackMessage.trim(),
                    onDismiss: () => ref
                        .read(speedReadingProvider.notifier)
                        .dismissWelcomeBackMessage(),
                  ),
                ],

                const SizedBox(height: 14),

                // c) Hero "Bugünkü Akıcı Fasıl" Kartı
                _HeroFasilCard(
                  activeBook: activeBook,
                  densityTier: densityTier,
                  targetWpm: targetWpm,
                  selectedPreset: effectivePreset,
                  isPro: isPro,
                  canStartFreeToday: canStartFreeToday,
                  onSelectPreset: (preset) => _onSelectPreset(preset, isPro),
                  onStartWarmupAndFasil: activeBook == null
                      ? null
                      : () => _launchGuidedFasil(
                            book: activeBook,
                            withWarmup: true,
                            isPro: isPro,
                            canStartFreeToday: canStartFreeToday,
                          ),
                  onStartDirectFasil: activeBook == null
                      ? null
                      : () => _launchGuidedFasil(
                            book: activeBook,
                            withWarmup: false,
                            isPro: isPro,
                            canStartFreeToday: canStartFreeToday,
                          ),
                  onImportBook: _importAndOpenBook,
                  onStartShowcaseBook: () => _startWithShowcaseBook(
                    isPro: isPro,
                    canStartFreeToday: canStartFreeToday,
                  ),
                ),

                const SizedBox(height: 14),

                // d) Gelişim & Odak Dayanıklılığı Kartı
                _GrowthStaminaCard(
                  baselineWpm: baselineWpm,
                  lastBookReadingWpm: lastBookReadingWpm,
                  currentWpm: currentWpm,
                  longestFasilMinutes: longestFasilMinutes,
                  totalFasilsCompleted: totalFasilsCompleted,
                  todayFasilsCount: todayFasilsCount,
                  isPro: isPro,
                  canStartFreeToday: canStartFreeToday,
                  onUpgradeTap: () => TahrirProSheet.show(context),
                ),

                const SizedBox(height: 18),

                // e) İkincil Araç Kartları
                Text(
                  'İkincil Odak & Ölçüm Araçları',
                  style: GoogleFonts.literata(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                _SecondaryToolTile(
                  emoji: '👁️',
                  title: 'Göz Atölyesi',
                  subtitle:
                      'Çevresel görüş piramidi, takistoskop ve Schulte dikkat matrisi',
                  accentColor: AppColors.amberGold,
                  trailingBadge: isPro ? null : 'PRO',
                  onTap: () {
                    if (!isPro) {
                      TahrirProSheet.show(context);
                    } else {
                      EyeWorkshopSheet.show(context);
                    }
                  },
                ),
                const SizedBox(height: 10),
                _SecondaryToolTile(
                  emoji: '🎯',
                  title: 'E-WPM Kalibrasyon Ölçümü',
                  subtitle:
                      'Seçkin pasaj ve anlama sorularıyla gerçek okuma hızını kalibre et',
                  accentColor: AppColors.terracotta,
                  onTap: () => EyeWorkshopSheet.show(
                    context,
                    initialExercise: SpeedReadingExerciseType.wpmComprehensionTest,
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContinuityTopBar extends StatelessWidget {
  final int streakDays;
  final int todayMinutesRead;
  final int dailyGoalMinutes;
  final int streakShieldCount;
  final bool isShieldArmedForToday;
  final SpeedReadingRankInfo rankInfo;

  const _ContinuityTopBar({
    required this.streakDays,
    required this.todayMinutesRead,
    required this.dailyGoalMinutes,
    required this.streakShieldCount,
    required this.isShieldArmedForToday,
    required this.rankInfo,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final goalProgress = dailyGoalMinutes > 0
        ? (todayMinutesRead / dailyGoalMinutes).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                rankInfo.badgeEmoji,
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${rankInfo.title} • Seviye ${rankInfo.level}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.literata(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      rankInfo.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.62),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.amberGold.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: AppColors.amberGold.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  '🔥 $streakDays Gün',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: goalProgress,
              minHeight: 6,
              backgroundColor:
                  theme.colorScheme.onSurface.withValues(alpha: 0.08),
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.terracotta,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Günlük Hedef: $todayMinutesRead / $dailyGoalMinutes dk',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.78),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isShieldArmedForToday
                      ? const Color(0xFF10B981).withValues(alpha: 0.14)
                      : theme.colorScheme.onSurface.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isShieldArmedForToday
                      ? '🛡️ Kalkan Aktif ($streakShieldCount)'
                      : '🛡️ $streakShieldCount Kalkan',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isShieldArmedForToday
                        ? const Color(0xFF047857)
                        : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WelcomeBackCard extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;

  const _WelcomeBackCard({
    required this.message,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: AppColors.amberGold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.amberGold.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.wb_sunny_rounded,
              color: AppColors.terracotta,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                height: 1.45,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Kapat',
            visualDensity: VisualDensity.compact,
            onPressed: onDismiss,
            icon: const Icon(Icons.close_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}

class _HeroFasilCard extends StatelessWidget {
  final BookEntity? activeBook;
  final TextDensityTier densityTier;
  final int targetWpm;
  final FasilDurationPreset selectedPreset;
  final bool isPro;
  final bool canStartFreeToday;
  final ValueChanged<FasilDurationPreset> onSelectPreset;
  final VoidCallback? onStartWarmupAndFasil;
  final VoidCallback? onStartDirectFasil;
  final VoidCallback onImportBook;
  final VoidCallback onStartShowcaseBook;

  const _HeroFasilCard({
    required this.activeBook,
    required this.densityTier,
    required this.targetWpm,
    required this.selectedPreset,
    required this.isPro,
    required this.canStartFreeToday,
    required this.onSelectPreset,
    required this.onStartWarmupAndFasil,
    required this.onStartDirectFasil,
    required this.onImportBook,
    required this.onStartShowcaseBook,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final book = activeBook;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.terracotta.withValues(alpha: 0.14),
            AppColors.amberGold.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.terracotta.withValues(alpha: 0.35),
        ),
      ),
      child: book == null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BUGÜNKÜ AKICI FASIL',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    color: AppColors.terracotta,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Kitabınla Ritme Gir',
                  style: GoogleFonts.literata(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Kendi PDF/EPUB eserini ekle ya da Klasik Risale ile ilk akıcı fasıl deneyimini hemen başlat.',
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    height: 1.45,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onStartShowcaseBook,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.terracotta,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      '📜 Klasik Risale ile Başla',
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: onImportBook,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      '📚 Kitap Ekle',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.terracotta.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'BUGÜNKÜ AKICI FASIL',
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: AppColors.terracotta,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                      child: Text(
                        densityTier.label,
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  book.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.literata(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${book.author} • S. ${book.currentPage}/${book.totalPages > 0 ? book.totalPages : 1} • Hedef $targetWpm WPM',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: FasilDurationPreset.values.map((preset) {
                    final isSelected = preset == selectedPreset;
                    final locked = preset.requiresPro && !isPro;
                    return ChoiceChip(
                      selected: isSelected,
                      onSelected: (_) => onSelectPreset(preset),
                      visualDensity: VisualDensity.compact,
                      selectedColor: AppColors.terracotta.withValues(alpha: 0.2),
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${preset.minutes} Dk',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                            ),
                          ),
                          if (locked) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.lock_outline_rounded,
                              size: 13,
                              color: AppColors.amberGold,
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 6),
                Text(
                  selectedPreset.subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onStartWarmupAndFasil,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.terracotta,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      !canStartFreeToday && !isPro
                          ? '✨ Günlük Ücretsiz Hak Doldu • Pro ile Devam Et'
                          : '⚡ 60 Sn Isın ve Kitabına Dal',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: TextButton(
                    onPressed: onStartDirectFasil,
                    child: Text(
                      'Isınmadan Doğrudan Başla',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.terracotta,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _GrowthStaminaCard extends StatelessWidget {
  final int baselineWpm;
  final int lastBookReadingWpm;
  final int currentWpm;
  final int longestFasilMinutes;
  final int totalFasilsCompleted;
  final int todayFasilsCount;
  final bool isPro;
  final bool canStartFreeToday;
  final VoidCallback onUpgradeTap;

  const _GrowthStaminaCard({
    required this.baselineWpm,
    required this.lastBookReadingWpm,
    required this.currentWpm,
    required this.longestFasilMinutes,
    required this.totalFasilsCompleted,
    required this.todayFasilsCount,
    required this.isPro,
    required this.canStartFreeToday,
    required this.onUpgradeTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final staminaProgress = (longestFasilMinutes / 30.0).clamp(0.0, 1.0);
    final activePaceWpm =
        lastBookReadingWpm > 0 ? lastBookReadingWpm : currentWpm;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Gelişim & Odak Dayanıklılığı',
                style: GoogleFonts.literata(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '$totalFasilsCompleted Fasıl',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.terracotta,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: 'Temel ➔ Güncel Tempo',
                  value: '$baselineWpm ➔ $activePaceWpm WPM',
                  subvalue: 'Akademi Ort: $currentWpm WPM',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricTile(
                  label: 'En Uzun Odak Faslı',
                  value: '$longestFasilMinutes / 30 dk',
                  subvalue: 'Bugün: $todayFasilsCount fasıl',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: staminaProgress,
              minHeight: 6,
              backgroundColor:
                  theme.colorScheme.onSurface.withValues(alpha: 0.08),
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.amberGold,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  isPro
                      ? '👑 Tahrir Pro • Sınırsız Fasıl & Tüm Süreler Açık'
                      : (canStartFreeToday
                          ? '✨ Günlük 1 ücretsiz 5 Dk fasıl hakkınız hazır'
                          : '🔒 Günlük ücretsiz fasıl kullanıldı'),
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                  ),
                ),
              ),
              if (!isPro && !canStartFreeToday)
                TextButton(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: onUpgradeTap,
                  child: Text(
                    'Pro Aç',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.terracotta,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final String subvalue;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.subvalue,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subvalue,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 10.5,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.58),
            ),
          ),
        ],
      ),
    );
  }
}

class _SecondaryToolTile extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final Color accentColor;
  final String? trailingBadge;
  final VoidCallback onTap;

  const _SecondaryToolTile({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.onTap,
    this.trailingBadge,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: accentColor.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(emoji, style: const TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.literata(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (trailingBadge != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.amberGold.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            trailingBadge!,
                            style: GoogleFonts.inter(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.terracotta,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.66),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right_rounded,
              color: accentColor,
            ),
          ],
        ),
      ),
    );
  }
}
