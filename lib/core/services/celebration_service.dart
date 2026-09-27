import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/asset_constants.dart';

enum CelebrationType {
  zikirTarget,
  dailyGoal,
  goldenDay,
  taskMilestone,
}

class CelebrationEvent {
  final CelebrationType type;
  final String title;
  final String subtitle;
  final String? birdName;
  final String? birdAsset;
  final String? hadithOrVirtue;
  final int xpGained;
  final DateTime timestamp;

  CelebrationEvent({
    required this.type,
    required this.title,
    required this.subtitle,
    this.birdName,
    this.birdAsset,
    this.hadithOrVirtue,
    this.xpGained = 50,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  static const List<Map<String, String>> birdPool = [
    {
      'name': 'İhlas Kuşu',
      'asset': AppAssets.animIhlasBird,
      'title': 'Samimiyet ve İhlas',
      'desc': '“Amelini ihlaslı kıl, az amel de sana yeter.” (Hadis-i Şerif)',
    },
    {
      'name': 'Azimet Kuşu',
      'asset': AppAssets.animAzimetBird,
      'title': 'Azim ve Gayret',
      'desc': 'Bir hedefe daha ulaştınız. Gayretiniz daim olsun.',
    },
    {
      'name': 'İstikamet Kuşu',
      'asset': AppAssets.animIstikametBird,
      'title': 'Doğruluk ve Sebat',
      'desc': '“Emrolunduğun gibi dosdoğru ol.” (Hûd, 112)',
    },
    {
      'name': 'Şükür Kuşu',
      'asset': AppAssets.animSukurBird,
      'title': 'Şükür ve Nimet',
      'desc': '“Eğer şükrederseniz, elbette size (nimetimi) artırırım.” (İbrâhim, 7)',
    },
    {
      'name': 'Müdavemet Kuşu',
      'asset': AppAssets.animMudavemetBird,
      'title': 'Devamlılık ve İstikrar',
      'desc': '“Allah katında amellerin en sevimlisi, az da olsa devamlı olanıdır.”',
    },
  ];

  factory CelebrationEvent.randomZikirMilestone({
    String? zikirName,
    int? count,
  }) {
    final randomVirtue = birdPool[Random().nextInt(birdPool.length)];
    return CelebrationEvent(
      type: CelebrationType.zikirTarget,
      title: 'Elhamdülillah 🌟',
      subtitle: zikirName != null ? '$zikirName hedefi tamamlandı' : 'Zikir turu tamamlandı',
      hadithOrVirtue: randomVirtue['desc'],
      xpGained: 50,
    );
  }

  factory CelebrationEvent.dailyGoalCompleted({
    required String goalTitle,
    int xp = 30,
  }) {
    return CelebrationEvent(
      type: CelebrationType.dailyGoal,
      title: 'Günlük Hedef Tamamlandı! ✨',
      subtitle: goalTitle,
      birdAsset: AppAssets.animZikirTamamlandi,
      hadithOrVirtue: '“Eğer şükrederseniz, elbette size (nimetimi) artırırım.” (İbrâhim, 7)',
      xpGained: xp,
    );
  }

  factory CelebrationEvent.goldenDayAchieved() {
    return CelebrationEvent(
      type: CelebrationType.goldenDay,
      title: '🌟 Altın Gün Tamamlandı! 🌟',
      subtitle: 'Bugünün tüm manevi hedeflerine ulaştınız. Maşâallah!',
      birdAsset: AppAssets.animZikirTamamlandi,
      hadithOrVirtue: '“Allah katında amellerin en sevimlisi, az da olsa devamlı olanıdır.”',
      xpGained: 150,
    );
  }
}

/// Global Celebration State Notifier
class CelebrationNotifier extends StateNotifier<CelebrationEvent?> {
  CelebrationNotifier() : super(null);

  void trigger(CelebrationEvent event) {
    // Setting state triggers reactive listeners in UI overlays
    state = event;
  }

  void clear() {
    state = null;
  }
}

final celebrationProvider =
    StateNotifierProvider<CelebrationNotifier, CelebrationEvent?>((ref) {
  return CelebrationNotifier();
});
