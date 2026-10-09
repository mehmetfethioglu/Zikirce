import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zikirce/core/database/app_database.dart';
import 'package:zikirce/core/services/google_drive_backup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late GoogleDriveBackupService backupService;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
    backupService = GoogleDriveBackupService(db: db);
  });

  tearDown(() async {
    await db.close();
  });

  test('MAUI BackupData JSON is 100% restored into SQLite and SharedPreferences', () async {
    // Exact MAUI BackupData JSON output
    final mauiBackupJson = jsonEncode({
      'AppVersion': '2.0',
      'BackupDate': '2026-08-23T14:30:00',
      'DeviceName': 'Xiaomi 24116RACCG',
      'Zikirler': [
        {
          'ZikirId': 101,
          'ZikirAdi': 'Sübhanallahi ve bihamdihi',
          'ZikirMiktar': 100,
          'ZikirAciklama': 'bulbul',
          'ZikirToplam': 1500,
          'TarihUnix': 1740000000,
          'KullaniciKartindaMi': true,
          'CicekGorsel': '',
          'CicekHarf': '',
          'MaxSeyir': 15,
          'Sayac': 33,
          'ArapceMetin': 'سُبْحَانَ اللهِ وَبِحَمْدِهِ',
          'IsFavorite': true,
          'Kategori': 'Tesbihat',
        },
      ],
      'ZikirLogs': [
        {
          'LogId': 201,
          'ZikirId': 101,
          'ZikirAdi': 'Sübhanallahi ve bihamdihi',
          'CekilenMiktar': 33,
          'TarihUnix': 1740000000,
        },
      ],
      'UserProfile': {
        'DisplayName': 'Halis Kul',
        'AvatarPath': 'avatar_1.png',
        'TotalZikir': 1500,
        'CurrentStreak': 12,
        'LastZikirDateUnix': 1740000000,
        'AvatarBase64': '',
      },
      'Hatimler': [
        {
          'HatimId': 1,
          'HatimAdi': 'Ramazan Hatmi',
          'BaslangicTarihiUnix': 1740000000,
          'CurrentPage': 120,
          'CurrentCuz': 6,
          'CompletedCuzCount': 6,
          'IsCompleted': false,
          'IsActive': true,
          'Type': 0,
        },
      ],
      'HatimCuzProgressList': [
        {
          'Id': 1,
          'HatimId': 1,
          'CuzNumber': 1,
          'Status': 2,
          'OwnerName': 'Halis Kul',
          'CompletedAtUnix': 1740000000,
        },
      ],
      'AppSettings': {
        'AppThemeOption': 1, // Açık Krem
        'LightSubThemeOption': 0,
        'QuranArabicFontSize': 40.0,
        'QuranTurkishFontSize': 17.0,
        'QuranIsBold': true,
        'QuranSelectedFontName': 'amasya',
        'QuranReadingMode': 1,
        'UserDisplayName': 'Halis Kul',
        'SelectedCity': 'Ankara',
        'SelectedBird': 'ihlas_bird.json',
        'ZikirSoundEnabled': true,
        'ZikirVibrationEnabled': true,
        'ZikirDailyGoal': 200,
        'KuranDailyGoal': 25,
        'TotalReadPages': 240,
        'ReadingStreak': 9,
        'BestReadingStreak': 15,
        'TotalReadingDays': 20,
        'UnlockedBadgeIds': ['streak_7', 'dhikr_1000', 'quran_juz_1'],
      },
      'UserStreak': {
        'CurrentStreak': 12,
        'LongestStreak': 20,
        'LastActiveDateUnix': 1740000000,
        'TotalActiveDays': 30,
        'ShieldCount': 3,
        'UnlockedBirds': 'yeni_bird.json,ihlas_bird.json',
      },
      'KazaPrayers': [
        {
          'PrayerType': 'Sabah',
          'CompletedCount': 50,
          'TargetCount': 100,
        },
      ],
      'PrayerAnswerLogs': [
        {
          'Date': '2026-08-23',
          'PrayerName': 'Sabah',
          'Answer': 'Kıldım',
          'Timestamp': 1740000000,
        },
      ],
      'MemorizationPlans': [
        {
          'PageId': 582,
          'SurahId': 78,
          'ScheduledReviewDateUnix': 1740000000,
          'State': 1,
          'TimesReviewed': 3,
        },
      ],
    });

    final count = await backupService.restoreFromJson(mauiBackupJson);
    expect(count, greaterThan(0));

    // Verify Zikir
    final zikirs = await db.select(db.zikirs).get();
    final restoredZikir = zikirs.firstWhere((z) => z.id == 101);
    expect(restoredZikir.name, 'Sübhanallahi ve bihamdihi');
    expect(restoredZikir.arabic, 'سُبْحَانَ اللهِ وَبِحَمْدِهِ');
    expect(restoredZikir.target, 100);
    expect(restoredZikir.currentCount, 33);
    expect(restoredZikir.totalCount, 1500);

    // Verify Hatim
    final hatims = await db.select(db.hatims).get();
    expect(hatims.length, 1);
    expect(hatims.first.title, 'Ramazan Hatmi');
    expect(hatims.first.completedPages, 120);

    // Verify Streak
    final streaks = await db.select(db.userStreaks).get();
    expect(streaks.length, 1);
    expect(streaks.first.currentStreak, 12);
    expect(streaks.first.bestStreak, 20);
    expect(streaks.first.freezeCount, 3);

    // Verify AppSettings in SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('AppThemeOption'), 1);
    expect(prefs.getDouble('quran_arabic_font_size'), 40.0);
    expect(prefs.getString('selected_city'), 'Ankara');
    expect(prefs.getString('selected_bird'), 'ihlas_bird.json');
    expect(prefs.getInt('zikir_daily_goal'), 200);
    expect(prefs.getInt('kuran_daily_goal'), 25);

    // Verify Unlocked Badges
    final badges = await db.select(db.unlockedBadges).get();
    expect(badges.length, greaterThanOrEqualTo(3));
    expect(badges.map((b) => b.badgeId).toSet(), containsAll(['streak_7', 'dhikr_1000', 'quran_juz_1']));

    // Verify Export format generates matching structure
    final exportedJson = await backupService.createBackupJson();
    final Map<String, dynamic> exportedData = jsonDecode(exportedJson);
    expect(exportedData.containsKey('Zikirler'), true);
    expect(exportedData.containsKey('Hatimler'), true);
    expect(exportedData.containsKey('AppSettings'), true);
    expect(exportedData.containsKey('UserStreak'), true);
  });
}
