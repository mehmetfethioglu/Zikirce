import '../../core/errors/app_error.dart';
import '../entities/habit_profile_entity.dart';

abstract interface class HabitRepository {
  Future<Result<HabitProfileEntity>> getHabitProfile();
  Future<Result<void>> updateStreak(int durationMinutes);
  Future<Result<void>> addEarnedSeal(String sealId);
  Future<Result<void>> setDailyGoal(int minutes);
}
