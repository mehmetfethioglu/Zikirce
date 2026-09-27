import 'dart:convert';

void main() {
  print('=== TESTING .NET MAUI JSON RESTORE (String-as-Number resilience) ===');

  // Simulated .NET MAUI backup JSON where all numbers are serialized as strings
  const sampleMauiJson = '''
  {
    "AppVersion": "2.0",
    "BackupDate": "2026-08-23T14:30:00",
    "DeviceName": "Xiaomi 24116RACCG",
    "AppSettings": {
      "AppThemeOption": "1",
      "LightSubThemeOption": "0",
      "QuranArabicFontSize": "38.0",
      "QuranTurkishFontSize": "16.5",
      "QuranIsBold": "true",
      "QuranReadingMode": "0",
      "UserDisplayName": "mehmetfethioglu",
      "SelectedCity": "Şanlıurfa",
      "SelectedBird": "bulbul",
      "ZikirSoundEnabled": "true",
      "ZikirVibrationEnabled": "true",
      "ZikirDailyGoal": "150",
      "KuranDailyGoal": "20",
      "KazaDailyGoal": "5",
      "EzberDailyGoal": "1",
      "TotalReadPages": "125",
      "TodayReadPages": "10",
      "ReadingStreak": "7",
      "BestReadingStreak": "14",
      "TotalReadingDays": "25",
      "UnlockedBadgeIds": ["badge_1", "badge_2", "badge_3"]
    },
    "UserStreak": {
      "CurrentStreak": "12",
      "LongestStreak": "25",
      "TotalActiveDays": "45",
      "ShieldCount": "3",
      "LastActiveDateUnix": "1724420000",
      "UnlockedBirds": "bulbul,guvercin"
    },
    "Zikirler": [
      {
        "ZikirId": "1",
        "ZikirAdi": "Sübhanallah",
        "ArapceMetin": "سبحان الله",
        "ZikirMiktar": "33",
        "Sayac": "15",
        "ZikirToplam": "330",
        "MaxSeyir": "10",
        "IsFavorite": "true",
        "Kategori": "Tesbihat",
        "ZikirAciklama": "bulbul",
        "TarihUnix": "1724420000"
      },
      {
        "ZikirId": "2",
        "ZikirAdi": "Elhamdülillah",
        "ArapceMetin": "الحمد لله",
        "ZikirMiktar": "33",
        "Sayac": "0",
        "ZikirToplam": "660",
        "MaxSeyir": "20",
        "IsFavorite": "false",
        "Kategori": "Tesbihat",
        "ZikirAciklama": "ney",
        "TarihUnix": "1724420000"
      }
    ],
    "ZikirLogs": [
      {
        "LogId": "101",
        "ZikirId": "1",
        "CekilenMiktar": "33",
        "TarihUnix": "1724420000"
      }
    ],
    "Hatimler": [
      {
        "HatimId": "hatim_1",
        "HatimAdi": "Ramazan Hatmi",
        "CurrentPage": "120",
        "CompletedPages": "120",
        "IsCompleted": "false",
        "Type": "1"
      }
    ],
    "HatimCuzProgressList": [
      {
        "Id": "1",
        "HatimId": "hatim_1",
        "CuzNumber": "1",
        "Status": "2",
        "OwnerName": "Mehmet"
      }
    ],
    "KazaPrayers": [
      {
        "PrayerType": "Sabah",
        "CompletedCount": "58",
        "TargetCount": "1000"
      }
    ],
    "PrayerAnswerLogs": [
      {
        "Date": "2026-08-23",
        "PrayerName": "Öğle",
        "Answer": "Kıldım",
        "isPerformed": "true"
      }
    ],
    "CompletedTasks": [
      {
        "TaskType": "DailyZikir",
        "TaskId": "1",
        "CompletedCount": "1"
      }
    ]
  }
  ''';

  final data = jsonDecode(sampleMauiJson) as Map<String, dynamic>;

  int parseInt(dynamic value, [int defaultValue = 0]) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value.trim());
      if (parsed != null) return parsed;
      final doubleParsed = double.tryParse(value.trim());
      if (doubleParsed != null) return doubleParsed.toInt();
    }
    return defaultValue;
  }

  double parseDouble(dynamic value, [double defaultValue = 0.0]) {
    if (value == null) return defaultValue;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.trim()) ?? defaultValue;
    }
    return defaultValue;
  }

  bool parseBool(dynamic value, [bool defaultValue = false]) {
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final lower = value.toLowerCase().trim();
      if (lower == 'true' || lower == '1' || lower == 'yes') return true;
      if (lower == 'false' || lower == '0' || lower == 'no') return false;
    }
    return defaultValue;
  }

  // 1. Verify AppSettings
  final appSettings = data['AppSettings'] as Map<String, dynamic>;
  assert(parseInt(appSettings['AppThemeOption']) == 1);
  assert(parseDouble(appSettings['QuranArabicFontSize']) == 38.0);
  assert(parseBool(appSettings['QuranIsBold']) == true);
  assert(parseInt(appSettings['ZikirDailyGoal']) == 150);
  print('✅ AppSettings parsed successfully');

  // 2. Verify UserStreak
  final userStreak = data['UserStreak'] as Map<String, dynamic>;
  assert(parseInt(userStreak['CurrentStreak']) == 12);
  assert(parseInt(userStreak['ShieldCount']) == 3);
  print('✅ UserStreak parsed successfully');

  // 3. Verify Zikirler
  final zikirler = data['Zikirler'] as List;
  for (final z in zikirler) {
    final target = parseInt(z['ZikirMiktar']);
    final isFav = parseBool(z['IsFavorite']);
    assert(target == 33);
    print('  - Zikir ${z['ZikirAdi']}: target=$target, fav=$isFav');
  }
  print('✅ Zikirler parsed successfully');

  // 4. Verify Hatimler & Kaza
  final kaza = (data['KazaPrayers'] as List).first;
  assert(parseInt(kaza['CompletedCount']) == 58);
  assert(parseInt(kaza['TargetCount']) == 1000);
  print('✅ KazaPrayers parsed successfully');

  print('=== ALL MAUI JSON RESTORE TESTS PASSED SUCCESSFULLY! ===');
}
