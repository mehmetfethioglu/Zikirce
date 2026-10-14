import '../../domain/entities/habit_profile_entity.dart';

class HabitProfileModel {
  static HabitProfileEntity fromMap(Map<String, dynamic> map) {
    final sealsStr = map['earned_seals'] as String? ?? '';
    final seals = sealsStr.isEmpty
        ? <String>[]
        : sealsStr.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

    return HabitProfileEntity(
      id: map['id'] as int?,
      lastActiveDate: DateTime.parse(map['last_active_date'] as String),
      currentStreak: map['current_streak'] as int? ?? 0,
      longestStreak: map['longest_streak'] as int? ?? 0,
      dailyGoalMinutes: map['daily_goal_minutes'] as int? ?? 20,
      earnedSeals: seals,
    );
  }

  static Map<String, dynamic> toMap(HabitProfileEntity entity) {
    return {
      if (entity.id != null) 'id': entity.id,
      'last_active_date': entity.lastActiveDate.toIso8601String(),
      'current_streak': entity.currentStreak,
      'longest_streak': entity.longestStreak,
      'daily_goal_minutes': entity.dailyGoalMinutes,
      'earned_seals': entity.earnedSeals.join(','),
    };
  }
}
