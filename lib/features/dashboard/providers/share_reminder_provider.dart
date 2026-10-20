import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../settings/providers/settings_provider.dart';
import '../../zikir/presentation/widgets/zikir_share_card_widget.dart';

enum ShareReminderType {
  streak,
  quickStats,
  zikir,
  prayers,
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
    this.type = ShareReminderType.streak,
    this.theme = ZikirShareCardTheme.emeraldSufi,
    this.metadata = const {},
    this.createdAt,
  });

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

        final type = (typeIndex >= 0 && typeIndex < ShareReminderType.values.length)
            ? ShareReminderType.values[typeIndex]
            : ShareReminderType.streak;
        final theme = (themeIndex >= 0 && themeIndex < ZikirShareCardTheme.values.length)
            ? ZikirShareCardTheme.values[themeIndex]
            : ZikirShareCardTheme.emeraldSufi;

        state = ShareReminderState(
          hasPendingReminder: true,
          title: title,
          subtitle: subtitle,
          type: type,
          theme: theme,
        );
      }
    } catch (_) {}
  }

  Future<void> setReminder({
    required String title,
    String subtitle = '',
    ShareReminderType type = ShareReminderType.streak,
    ZikirShareCardTheme? theme,
    Map<String, dynamic> metadata = const {},
  }) async {
    // If share cards disabled in settings, do not show reminder
    final settings = ref.read(userSettingsProvider);
    if (!settings.isShareCardsEnabled) return;

    final resolvedTheme = theme ??
        ZikirShareThemeData.themeForGoalOrTask(
          goalType: type.name,
          category: title,
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
    } catch (_) {}
  }
}

final shareReminderProvider = StateNotifierProvider<ShareReminderNotifier, ShareReminderState>((ref) {
  return ShareReminderNotifier(ref);
});
