import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../domain/entities/habit_profile_entity.dart';
import '../../../../domain/entities/reading_session_entity.dart';
import '../widgets/completion_seal_dialog.dart';
import '../widgets/heatmap_widget.dart';

class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  HabitProfileEntity? _profile;
  List<ReadingSessionEntity> _sessions = [];
  int _highlightCount = 0;
  bool _hasCompletedBook = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }
    final habitRepo = ref.read(habitRepositoryProvider);
    final bookRepo = ref.read(bookRepositoryProvider);
    final highlightRepo = ref.read(highlightRepositoryProvider);

    final profRes = await habitRepo.getHabitProfile();
    final sessRes = await bookRepo.getReadingSessions();
    final highRes = await highlightRepo.getAllHighlights();
    final booksRes = await bookRepo.getAllBooks();

    if (mounted) {
      setState(() {
        _profile = profRes.dataOrNull;
        _sessions = sessRes.dataOrNull ?? [];
        _highlightCount = highRes.dataOrNull?.length ?? 0;
        _hasCompletedBook = (booksRes.dataOrNull ?? []).any((b) => b.isCompleted);
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final totalMinutes = _sessions.fold<int>(
      0,
      (acc, s) => acc + (s.durationSeconds / 60).round(),
    );
    final totalPages = _sessions.fold<int>(0, (acc, s) => acc + s.pagesRead);
    final avgWpm = _sessions.isNotEmpty
        ? (_sessions.fold<double>(
                    0, (acc, s) => acc + (s.calculatedWpm > 0 ? s.calculatedWpm : 220)) /
                _sessions.length)
            .round()
        : 225;

    final sessionMap = <DateTime, int>{};
    for (final s in _sessions) {
      final dayKey = DateTime(s.sessionDate.year, s.sessionDate.month, s.sessionDate.day);
      final mins = (s.durationSeconds / 60).round();
      sessionMap[dayKey] = (sessionMap[dayKey] ?? 0) + mins;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Okuma Analitiği & İstatistik',
          style: GoogleFonts.literata(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'İstatistikleri Yenile',
            icon: const Icon(Icons.refresh),
            onPressed: _loadAnalytics,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Highlights Row
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    title: 'Aktif Seri',
                    value: '${_profile?.currentStreak ?? 0} Gün',
                    subtitle: 'Rekor: ${_profile?.longestStreak ?? 0} Gün',
                    icon: '🔥',
                    color: Colors.deepOrangeAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    title: 'Okuma Hızı',
                    value: '$avgWpm WPM',
                    subtitle: 'Kelime / Dakika',
                    icon: '⚡',
                    color: Colors.amber,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    title: 'Toplam Süre',
                    value: '$totalMinutes Dk',
                    subtitle: 'Aktif seans',
                    icon: '⏱️',
                    color: Colors.blueAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    title: 'Okunan Sayfa',
                    value: '$totalPages Sayfa',
                    subtitle: 'Tahrir külliyatı',
                    icon: '📚',
                    color: Colors.teal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Heatmap
            HeatmapWidget(sessionMinutes: sessionMap),
            const SizedBox(height: 24),

            // Tahrir Seals Collection
            Text(
              'KAZANILAN TAHRİR MÜHÜRLERİ',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            _buildSealsGrid(theme, totalPages: totalPages, totalMinutes: totalMinutes),
          ],
        ),
      ),
    );
  }

  bool _isSealUnlocked(String id, List<String> earned) {
    if (earned.contains(id)) return true;
    switch (id) {
      case 'seal_first_book':
        return _hasCompletedBook || earned.any((e) => e.startsWith('seal_completed_'));
      case 'seal_night_owl':
        return _sessions.any((s) => s.sessionDate.hour >= 0 && s.sessionDate.hour < 5);
      case 'seal_streak_7':
        return (_profile?.longestStreak ?? 0) >= 7 || (_profile?.currentStreak ?? 0) >= 7;
      case 'seal_scholar':
        return _highlightCount >= 10;
      default:
        return false;
    }
  }

  Widget _buildSealsGrid(
    ThemeData theme, {
    required int totalPages,
    required int totalMinutes,
  }) {
    final earned = _profile?.earnedSeals ?? [];
    final allSeals = [
      ('seal_first_book', 'İlk Eser Mührü', 'İlk kitabını bitirdin.', '📜'),
      ('seal_night_owl', 'Gece Tahriratı', 'Gece 00:00 sonrası okuma yaptın.', '🌙'),
      ('seal_streak_7', 'Haftalık Zincir', '7 gün kesintisiz okudun.', '🔥'),
      ('seal_scholar', 'Şerh Üstadı', '10 farklı nota şerh düştün.', '✍️'),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.4,
      ),
      itemCount: allSeals.length,
      itemBuilder: (context, idx) {
        final (id, name, desc, emoji) = allSeals[idx];
        final isUnlocked = _isSealUnlocked(id, earned);

        return InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: isUnlocked
              ? () {
                  CompletionSealDialog.show(
                    context,
                    bookTitle: name,
                    author: desc,
                    totalPages: totalPages > 0 ? totalPages : 1,
                    readingMinutes: totalMinutes > 0 ? totalMinutes : 1,
                  );
                }
              : null,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isUnlocked
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline.withOpacity(0.4),
                width: isUnlocked ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(emoji, style: TextStyle(fontSize: isUnlocked ? 24 : 20)),
                    Icon(
                      isUnlocked ? Icons.verified : Icons.lock_outline,
                      size: 16,
                      color: isUnlocked ? theme.colorScheme.primary : Colors.grey,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  name,
                  style: GoogleFonts.literata(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isUnlocked ? theme.colorScheme.onSurface : Colors.grey,
                  ),
                ),
                Text(
                  desc,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final String icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
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
              Text(title, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface.withOpacity(0.7))),
              Text(icon, style: const TextStyle(fontSize: 18)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: color),
          ),
          const SizedBox(height: 2),
          Text(subtitle, style: GoogleFonts.inter(fontSize: 10, color: theme.colorScheme.onSurface.withOpacity(0.5))),
        ],
      ),
    );
  }
}
