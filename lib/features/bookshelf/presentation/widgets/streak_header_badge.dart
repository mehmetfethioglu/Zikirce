import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class StreakHeaderBadge extends StatelessWidget {
  final int streakDays;
  final int dailyMinutesGoal;
  final int todayMinutesRead;

  const StreakHeaderBadge({
    super.key,
    required this.streakDays,
    required this.dailyMinutesGoal,
    required this.todayMinutesRead,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Text('🔥', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$streakDays GÜN',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.deepOrangeAccent,
                    ),
                  ),
                  Text(
                    'Okuma Serisi',
                    style: GoogleFonts.inter(fontSize: 11, color: theme.colorScheme.onSurface.withOpacity(0.6)),
                  ),
                ],
              ),
            ],
          ),
          Container(
            height: 30,
            width: 1,
            color: theme.colorScheme.outline,
          ),
          Row(
            children: [
              const Text('⏱️', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$todayMinutesRead / $dailyMinutesGoal Dk',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  Text(
                    'Günlük Hedef',
                    style: GoogleFonts.inter(fontSize: 11, color: theme.colorScheme.onSurface.withOpacity(0.6)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
