import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

// --- TABLE DEFINITIONS ---

class Zikirs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get arabic => text().nullable()();
  IntColumn get target => integer().withDefault(const Constant(33))();
  IntColumn get currentCount => integer().withDefault(const Constant(0))();
  IntColumn get totalCount => integer().withDefault(const Constant(0))();
  IntColumn get lap => integer().withDefault(const Constant(0))();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  TextColumn get category => text().withDefault(const Constant('Genel'))();
  TextColumn get soundEffect => text().withDefault(const Constant('bulbul'))();
  BoolColumn get vibrationEnabled => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastPracticed => dateTime().nullable()();
}

class ZikirLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get zikirId => integer()();
  IntColumn get count => integer()();
  TextColumn get dateStr => text()(); // yyyy-MM-dd
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
}

class UserStreaks extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get currentStreak => integer().withDefault(const Constant(0))();
  IntColumn get bestStreak => integer().withDefault(const Constant(0))();
  IntColumn get totalDays => integer().withDefault(const Constant(0))();
  TextColumn get lastDate => text().nullable()();
  IntColumn get freezeCount => integer().withDefault(const Constant(2))();
  TextColumn get lastFreezeDate => text().nullable()();
  RealColumn get multiplier => real().withDefault(const Constant(1.0))();
  IntColumn get xp => integer().withDefault(const Constant(0))();
  TextColumn get rank => text().withDefault(const Constant('Mübtedi'))();
}

class UserStreakHistories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get dateStr => text()();
  TextColumn get actionType => text()();
  IntColumn get xpGained => integer()();
}

class StreakGapDays extends Table {
  TextColumn get dateStr => text()();
  BoolColumn get isRepaired => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {dateStr};
}

class UnlockedBadges extends Table {
  TextColumn get badgeId => text()();
  DateTimeColumn get unlockedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get category => text().withDefault(const Constant('General'))();

  @override
  Set<Column> get primaryKey => {badgeId};
}

class UserProfiles extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get userName => text().withDefault(const Constant('Zâkir'))();
  TextColumn get avatar => text().withDefault(const Constant('avatar_male_1'))();
  IntColumn get dailyGoalMinutes => integer().withDefault(const Constant(15))();
  IntColumn get dailyZikirTarget => integer().withDefault(const Constant(100))();
  TextColumn get themeMode => text().withDefault(const Constant('midnightGold'))();
  RealColumn get soundVolume => real().withDefault(const Constant(1.0))();
  BoolColumn get hapticEnabled => boolean().withDefault(const Constant(true))();
}

class MemorizationPlans extends Table {
  IntColumn get pageId => integer()();
  IntColumn get surahId => integer().nullable()();
  DateTimeColumn get scheduledReviewDate => dateTime()();
  DateTimeColumn get lastReviewedDate => dateTime().nullable()();
  IntColumn get state => integer().withDefault(const Constant(0))(); // 0: New, 1: Learning, 2: Review, 3: Mastered
  IntColumn get timesReviewed => integer().withDefault(const Constant(0))();
  RealColumn get easeFactor => real().withDefault(const Constant(2.5))();
  IntColumn get intervalDays => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {pageId};
}

class HafizlikDailyLogs extends Table {
  TextColumn get dateStr => text()();
  BoolColumn get isHamDone => boolean().withDefault(const Constant(false))();
  BoolColumn get isPismisDone => boolean().withDefault(const Constant(false))();
  BoolColumn get isHasDone => boolean().withDefault(const Constant(false))();
  IntColumn get streakShieldsUsed => integer().withDefault(const Constant(0))();
  BoolColumn get isAsgariVirdDone => boolean().withDefault(const Constant(false))();
  IntColumn get asgariVirdRepeats => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {dateStr};
}

class KazaPrayers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get prayerType => text()(); // Sabah, Öğle, İkindi, Akşam, Yatsı, Vitir, Oruç
  IntColumn get totalCount => integer().withDefault(const Constant(0))();
  IntColumn get completedCount => integer().withDefault(const Constant(0))();
}

class PrayerAnswerLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get prayerType => text()();
  TextColumn get dateStr => text()();
  BoolColumn get isPerformed => boolean()();
}

class KazaMeltLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get prayerType => text()();
  IntColumn get meltAmount => integer()();
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
}

class Hatims extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  DateTimeColumn get targetDate => dateTime().nullable()();
  IntColumn get totalPages => integer().withDefault(const Constant(604))();
  IntColumn get completedPages => integer().withDefault(const Constant(0))();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  BoolColumn get isGroup => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class HatimCuzProgresses extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get hatimId => text()();
  IntColumn get juzNo => integer()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  TextColumn get readerName => text().nullable()();
  TextColumn get readerPhone => text().nullable()();
  DateTimeColumn get completedAt => dateTime().nullable()();
}

class JuzBookmarks extends Table {
  IntColumn get juzNo => integer()();
  IntColumn get lastPage => integer().withDefault(const Constant(1))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {juzNo};
}

class FardReminders extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get prayerName => text()();
  IntColumn get reminderMinutesBefore => integer().withDefault(const Constant(15))();
  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();
  TextColumn get soundTone => text().withDefault(const Constant('bulbul'))();
}

// --- DATABASE CLASS ---

@DriftDatabase(tables: [
  Zikirs,
  ZikirLogs,
  UserStreaks,
  UserStreakHistories,
  StreakGapDays,
  UnlockedBadges,
  UserProfiles,
  MemorizationPlans,
  HafizlikDailyLogs,
  KazaPrayers,
  PrayerAnswerLogs,
  KazaMeltLogs,
  Hatims,
  HatimCuzProgresses,
  JuzBookmarks,
  FardReminders,
])
class AppDatabase extends _$AppDatabase {
  final String? dbFileName;

  AppDatabase([QueryExecutor? e, this.dbFileName])
      : super(e ?? _openConnection(dbFileName ?? 'zikirce_app.sqlite'));

  static Future<void> deleteDatabaseFiles([String dbFileName = 'zikirce_app.sqlite']) async {
    try {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, dbFileName));
      final walFile = File('${file.path}-wal');
      final shmFile = File('${file.path}-shm');
      if (file.existsSync()) file.deleteSync();
      if (walFile.existsSync()) walFile.deleteSync();
      if (shmFile.existsSync()) shmFile.deleteSync();
      debugPrint('[AppDatabase] Successfully purged database files for: $dbFileName');
    } catch (e) {
      debugPrint('[AppDatabase] Error deleting database files: $e');
    }
  }

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
      // Seed default dhikrs and initial state
      await _seedInitialData();
    },
    beforeOpen: (details) async {
      try {
        await customStatement('PRAGMA journal_mode = WAL;');
        await customStatement('PRAGMA synchronous = NORMAL;');
        await customStatement('PRAGMA busy_timeout = 5000;');
      } catch (e) {
        debugPrint('[AppDatabase] beforeOpen pragma error: $e');
        try {
          await customStatement('PRAGMA wal_checkpoint(TRUNCATE);');
        } catch (_) {}
      }
    },
  );

  Future<void> _seedInitialData() async {
    // 1. Initial Profile
    await into(userProfiles).insert(
      UserProfilesCompanion.insert(
        userName: const Value('Zâkir'),
        avatar: const Value('avatar_male_1'),
        dailyGoalMinutes: const Value(15),
        dailyZikirTarget: const Value(100),
      ),
    );

    // 2. Initial Streak
    await into(userStreaks).insert(
      UserStreaksCompanion.insert(
        currentStreak: const Value(0),
        bestStreak: const Value(0),
        totalDays: const Value(0),
        freezeCount: const Value(2),
        multiplier: const Value(1.0),
        xp: const Value(0),
        rank: const Value('Mübtedi'),
      ),
    );

    // 3. Initial Default Adhkar (Asmaul Husna and Sunnah Dhikrs)
    final initialDhikrs = [
      ZikirsCompanion.insert(
        name: 'Sübhanallah',
        arabic: const Value('سُبْحَانَ اللَّهِ'),
        target: const Value(33),
        category: const Value('Tesbihat'),
        isFavorite: const Value(true),
      ),
      ZikirsCompanion.insert(
        name: 'Elhamdülillah',
        arabic: const Value('الْحَمْدُ لِلَّهِ'),
        target: const Value(33),
        category: const Value('Tesbihat'),
        isFavorite: const Value(true),
      ),
      ZikirsCompanion.insert(
        name: 'Allahu Ekber',
        arabic: const Value('اللَّهُ أَكْبَرُ'),
        target: const Value(33),
        category: const Value('Tesbihat'),
        isFavorite: const Value(true),
      ),
      ZikirsCompanion.insert(
        name: 'Lâ ilâhe illallah',
        arabic: const Value('لَا إِلٰهَ إِلَّا اللَّهُ'),
        target: const Value(100),
        category: const Value('Tevhid'),
        isFavorite: const Value(true),
      ),
      ZikirsCompanion.insert(
        name: 'Estağfirullah el-Azim',
        arabic: const Value('أَسْتَغْفِرُ اللَّهَ الْعَظِيمَ'),
        target: const Value(100),
        category: const Value('İstiğfar'),
        isFavorite: const Value(true),
      ),
      ZikirsCompanion.insert(
        name: 'Salavat-ı Şerife',
        arabic: const Value('اللَّهُمَّ صَلِّ عَلَى سَيِّدِنَا مُحَمَّدٍ'),
        target: const Value(100),
        category: const Value('Salavat'),
        isFavorite: const Value(true),
      ),
      ZikirsCompanion.insert(
        name: 'Lâ havle ve lâ kuvvete illâ billâh',
        arabic: const Value('لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ'),
        target: const Value(100),
        category: const Value('Hazine'),
        isFavorite: const Value(false),
      ),
      ZikirsCompanion.insert(
        name: 'Hasbünallahu ve ni\'mel vekil',
        arabic: const Value('حَسْبُنَا اللَّهُ وَنِعْمَ الْوَكِيلُ'),
        target: const Value(100),
        category: const Value('Tevekkül'),
        isFavorite: const Value(false),
      ),
      ZikirsCompanion.insert(
        name: 'Ya Fettah',
        arabic: const Value('يَا فَتَّاحُ'),
        target: const Value(489),
        category: const Value('Esmâ-ül Hüsnâ'),
        isFavorite: const Value(false),
      ),
      ZikirsCompanion.insert(
        name: 'Ya Rezzak',
        arabic: const Value('يَا رَزَّاقُ'),
        target: const Value(308),
        category: const Value('Esmâ-ül Hüsnâ'),
        isFavorite: const Value(false),
      ),
    ];

    for (final d in initialDhikrs) {
      await into(zikirs).insert(d);
    }

    // 4. Default Kaza Prayers
    final kazaTypes = ['Sabah', 'Öğle', 'İkindi', 'Akşam', 'Yatsı', 'Vitir', 'Oruç'];
    for (final type in kazaTypes) {
      await into(kazaPrayers).insert(
        KazaPrayersCompanion.insert(
          prayerType: type,
          totalCount: const Value(0),
          completedCount: const Value(0),
        ),
      );
    }

    // 5. Default Fard Reminders
    final fardNames = ['Sabah', 'Öğle', 'İkindi', 'Akşam', 'Yatsı'];
    for (final fn in fardNames) {
      await into(fardReminders).insert(
        FardRemindersCompanion.insert(
          prayerName: fn,
          reminderMinutesBefore: const Value(15),
          isEnabled: const Value(true),
          soundTone: const Value('bulbul'),
        ),
      );
    }
  }
}

LazyDatabase _openConnection([String dbFileName = 'zikirce_app.sqlite']) {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, dbFileName));
    return NativeDatabase.createInBackground(file);
  });
}
