import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../core/services/reading_notification_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/bookshelf_provider.dart';

class StreakHeaderBadge extends ConsumerWidget {
  final int streakDays;
  final int dailyMinutesGoal;
  final int todayMinutesRead;
  final VoidCallback? onQuickStartReading;

  const StreakHeaderBadge({
    super.key,
    required this.streakDays,
    required this.dailyMinutesGoal,
    required this.todayMinutesRead,
    this.onQuickStartReading,
  });

  static (String, String, int) _resolveScholarRank(int streak) {
    if (streak >= 30) {
      return ('👑 Allâme', 'Zirve İlmi Mertebe', 30);
    } else if (streak >= 14) {
      return ('🏛️ Müderris', 'Allâme mertebesine ${30 - streak} gün', 30);
    } else if (streak >= 7) {
      return ('🖋️ Kâtip', 'Müderris mertebesine ${14 - streak} gün', 14);
    } else if (streak >= 3) {
      return ('📜 Talebe-i İlim', 'Kâtip mertebesine ${7 - streak} gün', 7);
    } else {
      return ('🌱 Mübtedi', 'Talebe-i İlim mertebesine ${3 - streak} gün', 3);
    }
  }

  void _showStreakAndNotificationCenter(
    BuildContext context,
    WidgetRef ref,
  ) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) => _StreakAndNotificationSheet(
        streakDays: streakDays,
        dailyMinutesGoal: dailyMinutesGoal,
        todayMinutesRead: todayMinutesRead,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final notifState = ref.watch(readingNotificationProvider.select((s) => s));
    final (rankTitle, nextRankSubtitle, _) = _resolveScholarRank(streakDays);

    final effectiveGoal = dailyMinutesGoal > 0 ? dailyMinutesGoal : 20;
    final goalProgress = (todayMinutesRead / effectiveGoal).clamp(0.0, 1.0);
    final isGoalCompleted = todayMinutesRead >= effectiveGoal;
    final remainingMins = (effectiveGoal - todayMinutesRead).clamp(0, 999);
    final remainingFasils = (remainingMins / 3).ceil().clamp(1, 30);

    final now = DateTime.now();
    final todayWeekday = now.weekday; // 1 = Pzt .. 7 = Paz
    const dayLabels = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

    return GestureDetector(
      onTap: () => _showStreakAndNotificationCenter(context, ref),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isGoalCompleted
                ? AppColors.amberGold.withValues(alpha: 0.75)
                : theme.colorScheme.outline,
            width: isGoalCompleted ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Üst Satır: Seri Ateşi + İlmi Rütbe + Kıraat Kalkanı & Bildirim İkonu
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.deepOrange.withValues(alpha: 0.18),
                        AppColors.amberGold.withValues(alpha: 0.18),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.deepOrangeAccent.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🔥', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 6),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$streakDays GÜN SERİ',
                            style: GoogleFonts.inter(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w900,
                              color: Colors.deepOrangeAccent,
                            ),
                          ),
                          Text(
                            rankTitle,
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Günlük Hedef: $todayMinutesRead / $effectiveGoal dk',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            '${(goalProgress * 100).round()}%',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: isGoalCompleted
                                  ? AppColors.amberGold
                                  : theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: goalProgress,
                          minHeight: 7,
                          backgroundColor: theme.colorScheme.outline
                              .withValues(alpha: 0.25),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isGoalCompleted
                                ? AppColors.amberGold
                                : theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        nextRankSubtitle,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Kıraat Kalkanı & Bildirim Ayarları Rozeti
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: notifState.isShieldArmedForToday
                        ? Colors.teal.withValues(alpha: 0.16)
                        : theme.colorScheme.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: notifState.isShieldArmedForToday
                          ? Colors.teal
                          : theme.colorScheme.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        notifState.isShieldArmedForToday ? '🛡️✨' : '🛡️ ${notifState.streakShieldCount}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        notifState.isShieldArmedForToday ? 'Korumada' : 'Kalkan',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Orta Satır: 7-Günlük Canlı Mütalaa Zinciri Halkaları
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (idx) {
                final dayNum = idx + 1;
                final isToday = dayNum == todayWeekday;
                final daysAgo = todayWeekday - dayNum;
                final isCompletedPastDay =
                    daysAgo > 0 && daysAgo <= streakDays;
                final isTodayDone = isToday &&
                    (isGoalCompleted ||
                        todayMinutesRead > 0 ||
                        notifState.isShieldArmedForToday);

                return Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (isCompletedPastDay || isTodayDone)
                            ? Colors.deepOrangeAccent.withValues(alpha: 0.18)
                            : isToday
                                ? theme.colorScheme.primary
                                    .withValues(alpha: 0.10)
                                : theme.colorScheme.surface,
                        border: Border.all(
                          color: (isCompletedPastDay || isTodayDone)
                              ? Colors.deepOrangeAccent
                              : isToday
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.outline
                                      .withValues(alpha: 0.45),
                          width: isToday ? 1.8 : 1.2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          (isCompletedPastDay || isTodayDone)
                              ? '🔥'
                              : isToday
                                  ? '🕯️'
                                  : '•',
                          style: TextStyle(
                            fontSize:
                                (isCompletedPastDay || isTodayDone || isToday)
                                    ? 13
                                    : 12,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.45),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dayLabels[idx],
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight:
                            isToday ? FontWeight.w800 : FontWeight.w500,
                        color: isToday
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                );
              }),
            ),
            const SizedBox(height: 10),

            // Alt Satır: Dinamik Teşvik Çağrısı (Motivational Callout)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Text(
                    isGoalCompleted ? '🏆' : '⚡',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isGoalCompleted
                          ? 'Bugünkü mütalaa zinciri mühürlendi! Yarınki halka için seriniz güvende.'
                          : todayMinutesRead == 0
                              ? 'Bugünkü halkayı yakmak için sadece 1 fasıl (~3 dk) okumanız yeterli!'
                              : 'Günlük mühre sadece $remainingMins dk (~$remainingFasils kısa fasıl) kaldı!',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.tune_rounded,
                    size: 15,
                    color: theme.colorScheme.primary,
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

class _StreakAndNotificationSheet extends ConsumerWidget {
  final int streakDays;
  final int dailyMinutesGoal;
  final int todayMinutesRead;

  const _StreakAndNotificationSheet({
    required this.streakDays,
    required this.dailyMinutesGoal,
    required this.todayMinutesRead,
  });

  static const List<int> _goalChoices = [10, 15, 20, 30, 45, 60];
  static const List<(int, int, String)> _timePresets = [
    (19, 30, '19:30 (Akşam Erken)'),
    (20, 30, '20:30 (Mütalaa Vakti)'),
    (21, 30, '21:30 (Gece Tefekkürü)'),
    (22, 30, '22:30 (Uyku Öncesi)'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final notifState = ref.watch(readingNotificationProvider.select((s) => s));
    final notifService = ref.read(readingNotificationProvider.notifier);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outline.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '🔥 Seri Koruma Kalkanı & Akıllı Bildirim Merkezi',
                style: GoogleFonts.literata(
                  fontSize: 17.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Okuma alışkanlığınızı strese sokmadan teşvik eden akıllı kurallar ve Kıraat Kalkanı.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
              const SizedBox(height: 16),

              // 1. Kıraat Kalkanı (Streak Freeze) Kartı
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    const Text('🛡️', style: TextStyle(fontSize: 28)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kıraat Kalkanı (Seri Dondurma)',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            notifState.isShieldArmedForToday
                                ? 'Bugün için seri kalkanınız aktif! Okuyamasanız dahi $streakDays günlük seriniz kırılmaz.'
                                : 'Yoğun bir gününüzde serinizin sıfırlanmasını önler. Mevcut: ${notifState.streakShieldCount} Kalkan.',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              height: 1.35,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.72),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonal(
                      onPressed: notifState.isShieldArmedForToday ||
                              notifState.streakShieldCount <= 0
                          ? null
                          : () async {
                              await notifService.armStreakShieldForToday();
                            },
                      child: Text(
                        notifState.isShieldArmedForToday
                            ? 'Aktif ✓'
                            : 'Kalkanı Aç',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 2. Günlük Okuma Hedefi Seçimi
              Text(
                '⏱️ Günlük Mütalaa Hedefi',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _goalChoices.map((mins) {
                  final isSelected = mins == dailyMinutesGoal;
                  return ChoiceChip(
                    label: Text('$mins dk'),
                    selected: isSelected,
                    onSelected: (_) async {
                      await ref
                          .read(habitRepositoryProvider)
                          .setDailyGoal(mins);
                      await ref.read(bookshelfProvider.notifier).loadBooks();
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // 3. Gereklilik Odaklı Akıllı Bildirim Kuralları
              Text(
                '🔔 Gereklilik Odaklı Akıllı Bildirimler',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Akşam Mütalaa & Seri Hatırlatıcısı',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  'Seçtiğiniz saatte okuma ritüelinizi nazikçe hatırlatır (${notifState.formattedReminderTime})',
                  style: GoogleFonts.inter(fontSize: 11.5),
                ),
                value: notifState.isEnabled,
                onChanged: (v) => notifService.setEnabled(v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Yalnızca Hedef Eksikse Bildir (Sıfır Spam)',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  'Günlük hedefinizi tamamladığınız günlerde uygulama sizi asla rahatsız etmez.',
                  style: GoogleFonts.inter(fontSize: 11.5),
                ),
                value: notifState.onlyWhenGoalIncomplete,
                onChanged: (v) => notifService.setOnlyWhenGoalIncomplete(v),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _timePresets.map((preset) {
                  final (h, m, label) = preset;
                  final isSelected = notifState.reminderHour == h &&
                      notifState.reminderMinute == m;
                  return ChoiceChip(
                    visualDensity: VisualDensity.compact,
                    label: Text(label, style: const TextStyle(fontSize: 11)),
                    selected: isSelected,
                    onSelected: (_) => notifService.setReminderTime(h, m),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              // Akıllı Bildirim Testi Butonu
              OutlinedButton.icon(
                icon: const Icon(Icons.notifications_active_outlined, size: 18),
                label: const Text('Akıllı Bildirim Motorunu Şimdi Test Et'),
                onPressed: () async {
                  final decision =
                      await notifService.checkAndDispatchSmartNotification(
                    streakDays: streakDays > 0 ? streakDays : 3,
                    todayMinutesRead: todayMinutesRead,
                    dailyGoalMinutes: dailyMinutesGoal,
                    currentBookTitle: 'Kutadgu Bilig',
                    forceTest: true,
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${decision.title}\n${decision.body}'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
