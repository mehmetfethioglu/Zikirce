import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../gamification/services/golden_day_service.dart';
import '../../settings/providers/settings_provider.dart';
import '../../zikir/presentation/widgets/zikir_share_card_widget.dart';

enum ShareReminderType {
  streak,
  quickStats,
  zikir,
  prayers,
  kuran,
  ezber,
  kaza,
  goldenDay,
  general,
}

class ShareReminderState {
  final bool hasPendingReminder;
  final String title;
  final String subtitle;
  final ShareReminderType type;
  final ZikirShareCardTheme theme;
  final Map<String, dynamic> metadata;
  final DateTime? createdAt;

  const ShareReminderState({
    this.hasPendingReminder = false,
    this.title = '',
    this.subtitle = '',
    this.type = ShareReminderType.zikir,
    this.theme = ZikirShareCardTheme.emeraldSufi,
    this.metadata = const {},
    this.createdAt,
  });

  String get badgeEmoji {
    switch (type) {
      case ShareReminderType.prayers:
        return '🕌';
      case ShareReminderType.zikir:
        return '📿';
      case ShareReminderType.kuran:
        return '📖';
      case ShareReminderType.ezber:
        return '🧠';
      case ShareReminderType.kaza:
        return '⚖️';
      case ShareReminderType.goldenDay:
        return '🌟';
      case ShareReminderType.streak:
        return '🔥';
      case ShareReminderType.quickStats:
        return '📊';
      case ShareReminderType.general:
        return '✨';
    }
  }

  ShareReminderState copyWith({
    bool? hasPendingReminder,
    String? title,
    String? subtitle,
    ShareReminderType? type,
    ZikirShareCardTheme? theme,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
  }) {
    return ShareReminderState(
      hasPendingReminder: hasPendingReminder ?? this.hasPendingReminder,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      type: type ?? this.type,
      theme: theme ?? this.theme,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class ShareReminderNotifier extends StateNotifier<ShareReminderState> {
  final Ref ref;

  ShareReminderNotifier(this.ref) : super(const ShareReminderState()) {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasPending = prefs.getBool('pending_share_has_reminder') ?? false;
      if (hasPending) {
        final title = prefs.getString('pending_share_title') ?? 'Manevi Başarı';
        final subtitle = prefs.getString('pending_share_subtitle') ?? '';
        final typeIndex = prefs.getInt('pending_share_type') ?? 0;
        final themeIndex = prefs.getInt('pending_share_theme') ?? 0;
        final metaStr = prefs.getString('pending_share_meta');

        Map<String, dynamic> meta = const {};
        if (metaStr != null && metaStr.isNotEmpty) {
          try {
            meta = Map<String, dynamic>.from(jsonDecode(metaStr) as Map);
          } catch (_) {}
        }

        final type = (typeIndex >= 0 && typeIndex < ShareReminderType.values.length)
            ? ShareReminderType.values[typeIndex]
            : ShareReminderType.zikir;
        final theme = (themeIndex >= 0 && themeIndex < ZikirShareCardTheme.values.length)
            ? ZikirShareCardTheme.values[themeIndex]
            : ZikirShareCardTheme.emeraldSufi;

        state = ShareReminderState(
          hasPendingReminder: true,
          title: title,
          subtitle: subtitle,
          type: type,
          theme: theme,
          metadata: meta,
        );
      }
    } catch (_) {}
  }

  Future<void> setReminder({
    required String title,
    String subtitle = '',
    ShareReminderType type = ShareReminderType.zikir,
    ZikirShareCardTheme? theme,
    Map<String, dynamic> metadata = const {},
  }) async {
    final settings = ref.read(userSettingsProvider);
    if (!settings.isShareCardsEnabled) return;

    final resolvedTheme = theme ??
        ZikirShareThemeData.themeForGoalOrTask(
          goalType: type.name,
          category: title,
          isGold: type == ShareReminderType.goldenDay,
        );

    state = ShareReminderState(
      hasPendingReminder: true,
      title: title,
      subtitle: subtitle,
      type: type,
      theme: resolvedTheme,
      metadata: metadata,
      createdAt: DateTime.now(),
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('pending_share_has_reminder', true);
      await prefs.setString('pending_share_title', title);
      await prefs.setString('pending_share_subtitle', subtitle);
      await prefs.setInt('pending_share_type', type.index);
      await prefs.setInt('pending_share_theme', resolvedTheme.index);
      await prefs.setString('pending_share_meta', jsonEncode(metadata));
    } catch (_) {}
  }

  /// Automatically synchronizes with DailyGoalsStatus so ANY completed goal
  /// (Namaz, Zikir, Kur'an, Ezber, Kaza, or Altın Gün) triggers the Share bubble
  Future<void> syncWithDailyGoals(DailyGoalsStatus status) async {
    final settings = ref.read(userSettingsProvider);
    if (!settings.isShareCardsEnabled) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final todayStr = GoldenDayService.getTodayStr();

      // Check each goal in priority order if not yet shown today
      if (status.isGoldCompleted && !(prefs.getBool('ShareRemShown_goldenDay_$todayStr') ?? false)) {
        await prefs.setBool('ShareRemShown_goldenDay_$todayStr', true);
        await setReminder(
          title: 'Altın Gün & İbadette İstikamet',
          subtitle: 'Tüm günlük hedefler tamamlandı 🌟',
          type: ShareReminderType.goldenDay,
          metadata: {
            'name': 'Altın Gün & İbadette İstikamet',
            'category': 'Altın Gün',
            'count': status.completedGoalsCount,
            'target': status.totalActiveGoals,
          },
        );
        return;
      }

      if (status.isPrayersMet && !status.isExcusedMode && status.completedPrayersCount > 0 &&
          !(prefs.getBool('ShareRemShown_prayers_$todayStr') ?? false)) {
        await prefs.setBool('ShareRemShown_prayers_$todayStr', true);
        await setReminder(
          title: '5 Vakit Namaz & Secde Huzuru',
          subtitle: '${status.completedPrayersCount} / 5 vakit kılındı 🕌',
          type: ShareReminderType.prayers,
          metadata: {
            'name': '5 Vakit Namaz & Secde Huzuru',
            'category': 'Namaz',
            'count': status.completedPrayersCount,
            'target': 5,
          },
        );
        return;
      }

      if (status.isKuranGoalEnabled && status.isKuranMet && !status.isExcusedMode && status.todayKuranPages > 0 &&
          !(prefs.getBool('ShareRemShown_kuran_$todayStr') ?? false)) {
        await prefs.setBool('ShareRemShown_kuran_$todayStr', true);
        await setReminder(
          title: 'Kur’an-ı Kerim Tilaveti',
          subtitle: '${status.todayKuranPages} / ${status.kuranGoal} sayfa okundu 📖',
          type: ShareReminderType.kuran,
          metadata: {
            'name': 'Kur’an-ı Kerim Tilaveti',
            'category': 'Kur’an',
            'count': status.todayKuranPages,
            'target': status.kuranGoal,
          },
        );
        return;
      }

      if (status.isZikirGoalEnabled && status.isZikirMet && status.todayZikirCount > 0 &&
          !(prefs.getBool('ShareRemShown_zikir_$todayStr') ?? false)) {
        await prefs.setBool('ShareRemShown_zikir_$todayStr', true);
        await setReminder(
          title: 'Günlük Zikir & Kalbin Huzuru',
          subtitle: '${status.todayZikirCount} / ${status.zikirGoal} zikir 📿',
          type: ShareReminderType.zikir,
          metadata: {
            'name': 'Günlük Zikir & Kalbin Huzuru',
            'category': 'Zikir',
            'count': status.todayZikirCount,
            'target': status.zikirGoal,
          },
        );
        return;
      }

      if (status.isEzberGoalEnabled && status.isEzberMet && status.todayEzberCount > 0 &&
          !(prefs.getBool('ShareRemShown_ezber_$todayStr') ?? false)) {
        await prefs.setBool('ShareRemShown_ezber_$todayStr', true);
        await setReminder(
          title: 'Ezber & Hafızlık Gayreti',
          subtitle: '${status.todayEzberCount} / ${status.ezberGoal} tekrar 🧠',
          type: ShareReminderType.ezber,
          metadata: {
            'name': 'Ezber & Hafızlık Gayreti',
            'category': 'Ezber',
            'count': status.todayEzberCount,
            'target': status.ezberGoal,
          },
        );
        return;
      }

      if (status.isKazaGoalEnabled && status.isKazaMet && status.todayKazaCount > 0 &&
          !(prefs.getBool('ShareRemShown_kaza_$todayStr') ?? false)) {
        await prefs.setBool('ShareRemShown_kaza_$todayStr', true);
        await setReminder(
          title: 'Kaza Telafisi & İstiğfar',
          subtitle: '${status.todayKazaCount} / ${status.kazaGoal} kaza telafisi ⚖️',
          type: ShareReminderType.kaza,
          metadata: {
            'name': 'Kaza Telafisi & İstiğfar',
            'category': 'Kaza & Tövbe',
            'count': status.todayKazaCount,
            'target': status.kazaGoal,
          },
        );
        return;
      }
    } catch (_) {}
  }

  Future<void> clearReminder() async {
    state = const ShareReminderState(hasPendingReminder: false);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('pending_share_has_reminder');
      await prefs.remove('pending_share_title');
      await prefs.remove('pending_share_subtitle');
      await prefs.remove('pending_share_type');
      await prefs.remove('pending_share_theme');
      await prefs.remove('pending_share_meta');
    } catch (_) {}
  }
}

final shareReminderProvider = StateNotifierProvider<ShareReminderNotifier, ShareReminderState>((ref) {
  return ShareReminderNotifier(ref);
});
