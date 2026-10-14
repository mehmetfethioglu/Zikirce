import '../../core/errors/app_error.dart';
import '../../domain/entities/habit_profile_entity.dart';
import '../../domain/repositories/habit_repository.dart';
import '../datasources/database_helper.dart';
import '../models/habit_profile_model.dart';

class HabitRepositoryImpl implements HabitRepository {
  final DatabaseHelper _dbHelper;

  HabitRepositoryImpl({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  @override
  Future<Result<HabitProfileEntity>> getHabitProfile() async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query('habit_profiles', limit: 1);
      if (maps.isEmpty) {
        final initial = HabitProfileEntity(lastActiveDate: DateTime.now());
        await db.insert('habit_profiles', HabitProfileModel.toMap(initial));
        return Result.success(initial);
      }
      return Result.success(HabitProfileModel.fromMap(maps.first));
    } catch (e, st) {
      return Result.failure(StorageError('Alışkanlık profili getirilemedi: $e', cause: e, stackTrace: st));
    }
  }

  @override
  Future<Result<void>> updateStreak(int durationMinutes) async {
    try {
      final profileResult = await getHabitProfile();
      if (profileResult.isFailure) return Result.failure(profileResult.errorOrNull!);
      final profile = profileResult.dataOrNull!;

      final now = DateTime.now();
      final lastDate = profile.lastActiveDate;
      final isSameDay = now.year == lastDate.year && now.month == lastDate.month && now.day == lastDate.day;
      final isConsecutive = now.difference(lastDate).inDays == 1 || (now.day - lastDate.day == 1 && now.month == lastDate.month);

      int nextStreak = profile.currentStreak;
      if (!isSameDay) {
        if (isConsecutive) {
          nextStreak += 1;
        } else if (now.difference(lastDate).inDays > 1) {
          nextStreak = 1;
        }
      } else if (nextStreak == 0) {
        nextStreak = 1;
      }

      final longestStreak = nextStreak > profile.longestStreak ? nextStreak : profile.longestStreak;

      final db = await _dbHelper.database;
      await db.update(
        'habit_profiles',
        {
          'last_active_date': now.toIso8601String(),
          'current_streak': nextStreak,
          'longest_streak': longestStreak,
        },
        where: 'id = ?',
        whereArgs: [profile.id ?? 1],
      );

      return const Result.success(null);
    } catch (e, st) {
      return Result.failure(StorageError('Streak güncellenemedi: $e', cause: e, stackTrace: st));
    }
  }

  @override
  Future<Result<void>> addEarnedSeal(String sealId) async {
    try {
      final profileResult = await getHabitProfile();
      if (profileResult.isFailure) return Result.failure(profileResult.errorOrNull!);
      final profile = profileResult.dataOrNull!;

      if (!profile.earnedSeals.contains(sealId)) {
        final updatedSeals = [...profile.earnedSeals, sealId];
        final db = await _dbHelper.database;
        await db.update(
          'habit_profiles',
          {'earned_seals': updatedSeals.join(',')},
          where: 'id = ?',
          whereArgs: [profile.id ?? 1],
        );
      }
      return const Result.success(null);
    } catch (e, st) {
      return Result.failure(StorageError('Mühür eklenemedi: $e', cause: e, stackTrace: st));
    }
  }

  @override
  Future<Result<void>> setDailyGoal(int minutes) async {
    try {
      final db = await _dbHelper.database;
      await db.update('habit_profiles', {'daily_goal_minutes': minutes});
      return const Result.success(null);
    } catch (e, st) {
      return Result.failure(StorageError('Hedef kaydedilemedi: $e', cause: e, stackTrace: st));
    }
  }
}
