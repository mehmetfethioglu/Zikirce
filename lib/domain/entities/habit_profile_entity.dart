class HabitProfileEntity {
  final int? id;
  final DateTime lastActiveDate;
  final int currentStreak;
  final int longestStreak;
  final int dailyGoalMinutes;
  final List<String> earnedSeals;

  const HabitProfileEntity({
    this.id,
    required this.lastActiveDate,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.dailyGoalMinutes = 20,
    this.earnedSeals = const [],
  });

  HabitProfileEntity copyWith({
    int? id,
    DateTime? lastActiveDate,
    int? currentStreak,
    int? longestStreak,
    int? dailyGoalMinutes,
    List<String>? earnedSeals,
  }) {
    return HabitProfileEntity(
      id: id ?? this.id,
      lastActiveDate: lastActiveDate ?? this.lastActiveDate,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      dailyGoalMinutes: dailyGoalMinutes ?? this.dailyGoalMinutes,
      earnedSeals: earnedSeals ?? this.earnedSeals,
    );
  }
}
