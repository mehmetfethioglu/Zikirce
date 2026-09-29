import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/providers/database_provider.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../../core/services/sound_pool_service.dart';
import '../../../../core/services/widget_sync_service.dart';
import '../../../../core/constants/asset_constants.dart';
import '../../../../core/utils/pref_utils.dart';
import '../../../../core/session/session_providers.dart';
import '../../../../core/session/user_session.dart';
import '../../../../core/services/celebration_service.dart';
import 'package:flutter/foundation.dart';
import '../../gamification/providers/gamification_providers.dart';
import '../../gamification/services/daily_streak_service.dart';
import '../../../../core/services/cloud_sync_engine.dart';

// Stream of all dhikrs from DB
final zikirListStreamProvider = StreamProvider<List<Zikir>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.zikirs)
        ..orderBy([
          (t) => OrderingTerm(expression: t.isFavorite, mode: OrderingMode.desc),
          (t) => OrderingTerm(expression: t.id, mode: OrderingMode.asc),
        ]))
      .watch();
});

// Currently selected Zikir in the counter with persistent storage
class SelectedZikirIdNotifier extends StateNotifier<int?> {
  final Ref? ref;
  SelectedZikirIdNotifier([this.ref]) : super(null) {
    _load();
  }

  String _getPrefKey([String? customSessionId]) {
    final sid = customSessionId ?? (ref != null ? ref!.read(activeSessionProvider).id : UserSession.defaultSessionId);
    if (sid != UserSession.defaultSessionId) {
      return 'LastSelectedZikirId_$sid';
    }
    return 'LastSelectedZikirId';
  }

  String get _prefKey => _getPrefKey();

  Future<void> reloadForSession([String? targetSessionId]) async {
    await _load(targetSessionId);
  }

  Future<void> _load([String? targetSessionId]) async {
    try {
      final sid = targetSessionId ?? (ref != null ? ref!.read(activeSessionProvider).id : UserSession.defaultSessionId);
      final prefs = await SharedPreferences.getInstance();
      final id = PrefUtils.getIntOrNull(prefs, _getPrefKey(sid)) ??
          (sid == UserSession.defaultSessionId ? PrefUtils.getIntOrNull(prefs, 'LastSelectedZikirId') : null);
      state = id;
    } catch (_) {}
  }

  Future<void> select(int id) async {
    state = id;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefKey, id);
      final isDefault = ref != null ? ref!.read(activeSessionProvider).id == UserSession.defaultSessionId : true;
      if (isDefault) {
        await prefs.setInt('LastSelectedZikirId', id);
      }
    } catch (_) {}
  }

  @override
  set state(int? value) {
    super.state = value;
    if (value != null) {
      SharedPreferences.getInstance().then((prefs) {
        prefs.setInt(_prefKey, value);
        final isDefault = ref != null ? ref!.read(activeSessionProvider).id == UserSession.defaultSessionId : true;
        if (isDefault) {
          prefs.setInt('LastSelectedZikirId', value);
        }
      }).catchError((_) {});
    }
  }
}

final selectedZikirIdProvider =
    StateNotifierProvider<SelectedZikirIdNotifier, int?>((ref) {
  return SelectedZikirIdNotifier(ref);
});

final currentZikirProvider = Provider<Zikir?>((ref) {
  final zikirsAsync = ref.watch(zikirListStreamProvider);
  final selectedId = ref.watch(selectedZikirIdProvider);

  return zikirsAsync.when(
    data: (list) {
      if (list.isEmpty) return null;
      if (selectedId != null) {
        final match = list.where((z) => z.id == selectedId).firstOrNull;
        if (match != null) return match;
      }
      // If no ID matched or not set yet, pick the most recently practiced zikir
      final practiced = list.where((z) => z.lastPracticed != null).toList();
      if (practiced.isNotEmpty) {
        practiced.sort((a, b) => b.lastPracticed!.compareTo(a.lastPracticed!));
        return practiced.first;
      }
      return list.first;
    },
    loading: () => null,
    error: (_, __) => null,
  );
});

// Quick settings persistent state (Sound, Vibration, Infinite Mode)
class ZikirQuickSettingsState {
  final bool isSoundEnabled;
  final bool isVibrationEnabled;
  final bool isInfiniteMode;

  const ZikirQuickSettingsState({
    this.isSoundEnabled = true,
    this.isVibrationEnabled = true,
    this.isInfiniteMode = false,
  });

  ZikirQuickSettingsState copyWith({
    bool? isSoundEnabled,
    bool? isVibrationEnabled,
    bool? isInfiniteMode,
  }) {
    return ZikirQuickSettingsState(
      isSoundEnabled: isSoundEnabled ?? this.isSoundEnabled,
      isVibrationEnabled: isVibrationEnabled ?? this.isVibrationEnabled,
      isInfiniteMode: isInfiniteMode ?? this.isInfiniteMode,
    );
  }
}

class ZikirQuickSettingsNotifier extends StateNotifier<ZikirQuickSettingsState> {
  ZikirQuickSettingsNotifier() : super(const ZikirQuickSettingsState()) {
    _load();
  }

  static const String _soundKey = 'zikir_quick_sound_enabled';
  static const String _vibrationKey = 'zikir_quick_vibration_enabled';
  static const String _infiniteKey = 'zikir_quick_infinite_mode';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sound = PrefUtils.getBoolFromKeys(prefs, [_soundKey, 'vibration_sound_enabled', 'sound_enabled'], true);
      final vibration = PrefUtils.getBoolFromKeys(prefs, [_vibrationKey, 'vibration_enabled'], true);
      final infinite = PrefUtils.getBool(prefs, _infiniteKey, false);

      state = state.copyWith(
        isSoundEnabled: sound,
        isVibrationEnabled: vibration,
        isInfiniteMode: infinite,
      );
    } catch (_) {}
  }

  Future<void> toggleSound() async {
    final next = !state.isSoundEnabled;
    state = state.copyWith(isSoundEnabled: next);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_soundKey, next);
    } catch (_) {}
  }

  Future<void> toggleVibration() async {
    final next = !state.isVibrationEnabled;
    state = state.copyWith(isVibrationEnabled: next);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_vibrationKey, next);
    } catch (_) {}
  }

  Future<void> toggleInfiniteMode() async {
    final next = !state.isInfiniteMode;
    state = state.copyWith(isInfiniteMode: next);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_infiniteKey, next);
    } catch (_) {}
  }
}

final zikirQuickSettingsProvider =
    StateNotifierProvider<ZikirQuickSettingsNotifier, ZikirQuickSettingsState>((ref) {
  return ZikirQuickSettingsNotifier();
});

// Bird reward event signal for UI dialog
class BirdRewardEvent {
  final String birdName;
  final String lottieAsset;
  final String title;
  final String description;
  final int xpGained;

  BirdRewardEvent({
    required this.birdName,
    required this.lottieAsset,
    required this.title,
    required this.description,
    required this.xpGained,
  });
}

final birdRewardEventProvider = StateProvider<BirdRewardEvent?>((ref) => null);
final isZikirFocusModeProvider = StateProvider<bool>((ref) => false);

// Zikir Counter State Controller
class ZikirCounterState {
  final int currentCount;
  final int target;
  final int lap;
  final int totalCount;

  ZikirCounterState({
    required this.currentCount,
    required this.target,
    required this.lap,
    required this.totalCount,
  });

  double get progress => target > 0 ? (currentCount / target).clamp(0.0, 1.0) : 0.0;

  ZikirCounterState copyWith({
    int? currentCount,
    int? target,
    int? lap,
    int? totalCount,
  }) {
    return ZikirCounterState(
      currentCount: currentCount ?? this.currentCount,
      target: target ?? this.target,
      lap: lap ?? this.lap,
      totalCount: totalCount ?? this.totalCount,
    );
  }
}

class ZikirCounterNotifier extends StateNotifier<ZikirCounterState> {
  final Ref ref;
  final AppDatabase db;
  final Zikir zikir;

  static const List<Map<String, String>> birdList = [
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

  Timer? _debounceTimer;
  int _pendingCount = 0;
  bool _hasSelectionSaved = false;

  ZikirCounterNotifier(this.ref, this.db, this.zikir)
      : super(ZikirCounterState(
          currentCount: zikir.currentCount,
          target: zikir.target,
          lap: zikir.lap,
          totalCount: zikir.totalCount,
        ));

  void increment({
    bool isInfinite = false,
    bool isSoundEnabled = true,
    bool isVibrationEnabled = true,
  }) {
    final nextCount = state.currentCount + 1;
    final nextTotal = state.totalCount + 1;
    _pendingCount++;

    // Ensure this zikir is recorded as the active selected zikir once per session/cycle
    if (!_hasSelectionSaved) {
      _hasSelectionSaved = true;
      try {
        ref.read(selectedZikirIdProvider.notifier).select(zikir.id);
      } catch (_) {}
    }

    if (isVibrationEnabled) {
      HapticService.countTap();
    }

    if (!isInfinite && nextCount >= state.target && state.target > 0) {
      // Milestone / Target reached! (Normal mode: resets count to 0 and increments lap)
      if (isVibrationEnabled) {
        HapticService.targetReached();
      }
      if (isSoundEnabled) {
        SoundPoolService.playChirp(type: zikir.soundEffect);
      }

      final nextLap = state.lap + 1;
      state = state.copyWith(
        currentCount: 0,
        lap: nextLap,
        totalCount: nextTotal,
      );

      // Trigger spiritual celebration
      final randomBird = birdList[Random().nextInt(birdList.length)];
      try {
        ref.read(celebrationProvider.notifier).trigger(
          CelebrationEvent(
            type: CelebrationType.zikirTarget,
            title: 'Elhamdülillah 🌟',
            subtitle: '${zikir.name} tamamlandı',
            hadithOrVirtue: randomBird['desc']!,
            xpGained: 50,
          ),
        );
        ref.read(gamificationNotifierProvider).addGold(50);
      } catch (_) {}

      _flushPending(0, nextLap, nextTotal);
      try {
        CloudSyncEngine.instance.triggerDebouncedSync(ref, delay: const Duration(seconds: 1));
      } catch (_) {}
    } else {
      // Infinite mode OR target not reached yet in normal mode
      final nextLap = (isInfinite && state.target > 0)
          ? (nextCount ~/ state.target)
          : state.lap;
      
      final bool isLapCompletedInInfinite = isInfinite && state.target > 0 && nextCount > 0 && (nextCount % state.target == 0);
      if (isLapCompletedInInfinite) {
        if (isVibrationEnabled) HapticService.targetReached();
        if (isSoundEnabled) SoundPoolService.playChirp(type: zikir.soundEffect);
        final randomBird = birdList[Random().nextInt(birdList.length)];
        try {
          ref.read(celebrationProvider.notifier).trigger(
            CelebrationEvent(
              type: CelebrationType.zikirTarget,
              title: 'Elhamdülillah 🌟',
              subtitle: '${zikir.name} (${state.target} zikir) tamamlandı',
              hadithOrVirtue: randomBird['desc']!,
              xpGained: 50,
            ),
          );
          ref.read(gamificationNotifierProvider).addGold(50);
        } catch (_) {}
      }

      state = state.copyWith(
        currentCount: nextCount,
        lap: nextLap,
        totalCount: nextTotal,
      );

      // HİBRİT GÜVENLİK: Her 25 zikirde bir duraklama beklemeden diske yaz
      if (_pendingCount >= 25) {
        _flushPending(nextCount, nextLap, nextTotal);
      } else {
        _scheduleDebouncedCommit(nextCount, nextLap, nextTotal);
      }
    }
  }

  void _scheduleDebouncedCommit(int count, int lap, int total) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 1000), () {
      _flushPending(count, lap, total);
    });
  }

  /// Flushes any pending uncommitted dhikr count to the database immediately
  void flushPending() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    if (_pendingCount > 0) {
      _flushPending(state.currentCount, state.lap, state.totalCount);
    }
  }

  /// Sonsuz mod kapatıldığında o ana kadarki tüm zikirleri diske ve günlüğe işler,
  /// sayacı sıfırlayarak normal moda hazır hale getirir.
  Future<void> onExitInfiniteMode() async {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    final countToLog = _pendingCount;
    _pendingCount = 0;

    final finalTotal = state.totalCount;
    state = state.copyWith(currentCount: 0);

    await _commitToDb(0, state.lap, finalTotal);
    if (countToLog > 0) {
      await _logZikir(countToLog);
    }
    try {
      CloudSyncEngine.instance.triggerDebouncedSync(ref, delay: const Duration(seconds: 1));
    } catch (_) {}
  }

  void _flushPending(int count, int lap, int total) {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    final countToLog = _pendingCount;
    _pendingCount = 0;

    _commitToDb(count, lap, total);
    if (countToLog > 0) {
      _logZikir(countToLog);
    }
    try {
      CloudSyncEngine.instance.triggerDebouncedSync(ref, delay: const Duration(seconds: 3));
    } catch (_) {}
  }

  void reset() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _pendingCount = 0;
    HapticService.selectionClick();
    state = state.copyWith(currentCount: 0, lap: 0);
    _commitToDb(0, 0, state.totalCount);
    try {
      CloudSyncEngine.instance.triggerDebouncedSync(ref, delay: const Duration(seconds: 2));
    } catch (_) {}
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    if (_pendingCount > 0) {
      final countToLog = _pendingCount;
      _pendingCount = 0;
      _commitToDb(state.currentCount, state.lap, state.totalCount);
      _logZikir(countToLog);
      try {
        CloudSyncEngine.instance.triggerDebouncedSync(ref, delay: const Duration(seconds: 1));
      } catch (_) {}
    }
    super.dispose();
  }

  Future<void> _commitToDb(int count, int lap, int total) async {
    try {
      await (db.update(db.zikirs)..where((t) => t.id.equals(zikir.id))).write(
        ZikirsCompanion(
          currentCount: Value(count),
          lap: Value(lap),
          totalCount: Value(total),
          lastPracticed: Value(DateTime.now()),
        ),
      );
    } catch (e) {
      debugPrint('[ZikirCounterNotifier] _commitToDb error: $e');
    }
  }

  Future<void> _logZikir(int count) async {
    try {
      final now = DateTime.now();
      final dateStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      await db.into(db.zikirLogs).insert(
        ZikirLogsCompanion.insert(
          zikirId: zikir.id,
          count: count,
          dateStr: dateStr,
        ),
      );

      // Advance daily streak
      await DailyStreakService.recordDailyActivity(db);

      // Check if Daily Zikir Goal is newly reached today
      try {
        final prefs = await SharedPreferences.getInstance();
        final activeSession = ref.read(activeSessionProvider);
        final isDefault = activeSession.id == UserSession.defaultSessionId;
        final sfx = isDefault ? '' : '_${activeSession.id}';
        final claimedKey = 'DailyZikirRewardClaimed_$dateStr$sfx';
        final alreadyClaimed = prefs.getBool(claimedKey) ?? (isDefault ? prefs.getBool('DailyZikirRewardClaimed_$dateStr') ?? false : false);

        if (!alreadyClaimed) {
          final zikirGoal = PrefUtils.getIntFromKeys(prefs, ['DailyZikirGoal$sfx', 'ZikirDailyGoal$sfx', 'DailyZikirGoal', 'ZikirDailyGoal'], 100);
          final todayLogs = await (db.select(db.zikirLogs)..where((t) => t.dateStr.equals(dateStr))).get();
          final totalToday = todayLogs.fold<int>(0, (sum, item) => sum + item.count);
          if (totalToday >= zikirGoal) {
            await prefs.setBool(claimedKey, true);
            if (isDefault) await prefs.setBool('DailyZikirRewardClaimed_$dateStr', true);
            // Award 1 Diamond + 5 Gold for Daily Goal milestone
            await ref.read(gamificationNotifierProvider).addDiamonds(1);
            await ref.read(gamificationNotifierProvider).addGold(5);
            ref.read(celebrationProvider.notifier).trigger(
              CelebrationEvent.dailyGoalCompleted(
                goalTitle: 'Günlük $zikirGoal Zikir Hedefi Tamamlandı! (+1 💎, +5 🪙)',
              ),
            );
          }
        }
      } catch (_) {}

      // Sync to Android widgets (Kalp Sağlığı, Zikir Counter, etc.) and refresh daily goals
      WidgetSyncService.syncAll(db);
      try {
        ref.read(badgeRefreshTriggerProvider.notifier).state++;
      } catch (_) {}
    } catch (e) {
      debugPrint('[ZikirCounterNotifier] _logZikir error: $e');
    }
  }
}

final zikirCounterNotifierProvider = StateNotifierProvider.autoDispose
    .family<ZikirCounterNotifier, ZikirCounterState, int>((ref, zikirId) {
  final db = ref.watch(databaseProvider);
  final zikirs = ref.read(zikirListStreamProvider).valueOrNull ?? [];
  final zikir = zikirs.where((z) => z.id == zikirId).firstOrNull ??
      Zikir(
        id: zikirId,
        name: 'Zikir',
        target: 33,
        currentCount: 0,
        totalCount: 0,
        lap: 0,
        isFavorite: false,
        category: 'genel',
        soundEffect: 'bulbul',
        vibrationEnabled: true,
        createdAt: DateTime.now(),
      );
  return ZikirCounterNotifier(ref, db, zikir);
});
