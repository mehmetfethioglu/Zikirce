import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/kiler/domain/expiry_reminder_service.dart';
import '../../features/kiler/domain/kiler_models.dart';
import '../../features/kiler/domain/kiler_service.dart';
import '../../features/recipes/data/sqlite_meal_module_repository.dart';
import '../../features/recipes/domain/recipe_recommendation_engine.dart';

class MenuMissingNotificationPayload {
  final String title;
  final String body;
  final int missingCount;
  final List<String> missingNames;
  final List<String> recipeTitles;

  const MenuMissingNotificationPayload({
    required this.title,
    required this.body,
    required this.missingCount,
    required this.missingNames,
    required this.recipeTitles,
  });
}

class MorningTriggerWindow {
  final DateTime triggerAt;
  final String targetDateIso;
  final bool isToday;

  const MorningTriggerWindow({
    required this.triggerAt,
    required this.targetDateIso,
    required this.isToday,
  });
}

class KilerceNotificationSettings {
  final bool morningMenuEnabled;
  final int morningHour;
  final int morningMinute;
  final bool sktEnabled;

  const KilerceNotificationSettings({
    required this.morningMenuEnabled,
    required this.morningHour,
    required this.morningMinute,
    required this.sktEnabled,
  });
}

/// Manages local morning meal-plan missing-ingredient alerts, SKT reminders,
/// Android notification permissions, and native email client handoff.
class KilerceNotificationService {
  static final KilerceNotificationService instance =
      KilerceNotificationService._internal();

  static const String channelName = 'com.akarworks.kilerce/notifications';
  static const String menuChannelId = 'kilerce_menu_alerts';
  static const String sktChannelId = 'kilerce_skt_alerts';
  static const int menuMissingNotificationId = 32220;
  static const int expiryNotificationId = 32216;
  static const int testNotificationId = 32299;

  static const String _prefMorningMenuEnabled =
      'kilerce_morning_menu_notifications_enabled_v1';
  static const String _prefMorningHour = 'kilerce_morning_notify_hour_v1';
  static const String _prefMorningMinute = 'kilerce_morning_notify_minute_v1';
  static const String _prefPermissionAskedOnce =
      'kilerce_notify_permission_asked_v1';
  static const String _prefMenuLastNotifiedDay =
      'kilerce_menu_last_notified_day_v1';

  static const int defaultMorningHour = 8;
  static const int defaultMorningMinute = 30;

  final MethodChannel _channel;
  final DateTime Function() _nowProvider;

  KilerceNotificationService._internal({
    MethodChannel? channel,
    DateTime Function()? nowProvider,
  })  : _channel = channel ?? const MethodChannel(channelName),
        _nowProvider = nowProvider ?? DateTime.now;

  @visibleForTesting
  factory KilerceNotificationService.forTesting({
    MethodChannel? channel,
    DateTime Function()? nowProvider,
  }) {
    return KilerceNotificationService._internal(
      channel: channel,
      nowProvider: nowProvider,
    );
  }

  /// Computes the next morning trigger window (`today` if before cutoff, else `tomorrow`).
  static MorningTriggerWindow computeNextMorningTrigger({
    required DateTime now,
    required int hour,
    required int minute,
  }) {
    final DateTime todayTarget = DateTime(
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (now.isBefore(todayTarget)) {
      return MorningTriggerWindow(
        triggerAt: todayTarget,
        targetDateIso: MealDateUtils.toIsoDate(todayTarget),
        isToday: true,
      );
    }
    final DateTime tomorrowTarget = DateTime(
      now.year,
      now.month,
      now.day + 1,
      hour,
      minute,
    );
    return MorningTriggerWindow(
      triggerAt: tomorrowTarget,
      targetDateIso: MealDateUtils.toIsoDate(tomorrowTarget),
      isToday: false,
    );
  }

  /// Builds a morning reminder payload for planned uncooked recipes on [dateIso]
  /// that are missing non-staple pantry ingredients. Returns `null` when complete.
  static MenuMissingNotificationPayload? buildMenuMissingNotificationPayload({
    required String dateIso,
    required List<MealPlanEntry> entries,
    required Map<String, KilerRecipe> recipeById,
    required List<PantryItem> pantryItems,
  }) {
    final Set<String> pantryTags = pantryItems
        .map((e) => e.normalizedTag.trim())
        .where((t) => t.isNotEmpty)
        .toSet();

    final List<String> missingTagsOrdered = [];
    final Set<String> seenMissingTags = {};
    final List<String> recipeTitlesOrdered = [];
    final Set<String> seenRecipeTitles = {};

    for (final entry in entries) {
      if (entry.planDate != dateIso || entry.isCooked) continue;
      final KilerRecipe? recipe = recipeById[entry.recipeId];
      if (recipe == null) continue;

      final Set<String> stapleOnlyTags = recipe.ingredients
          .where((ing) => ing.isPantryStaple || ing.isOptional)
          .map((ing) => ing.tag)
          .toSet();
      final Set<String> requiredNonStapleTags = recipe.ingredients
          .where((ing) => !ing.isPantryStaple && !ing.isOptional)
          .map((ing) => ing.tag)
          .toSet();

      bool recipeHasMissing = false;
      for (final tag in recipe.requiredTags) {
        if (!requiredNonStapleTags.contains(tag) &&
            stapleOnlyTags.contains(tag)) {
          continue;
        }
        if (!pantryTags.contains(tag)) {
          recipeHasMissing = true;
          if (seenMissingTags.add(tag)) {
            missingTagsOrdered.add(tag);
          }
        }
      }

      if (recipeHasMissing && seenRecipeTitles.add(recipe.title)) {
        recipeTitlesOrdered.add(recipe.title);
      }
    }

    if (missingTagsOrdered.isEmpty) return null;

    final List<String> missingNames = missingTagsOrdered
        .map(QuickIngredientCatalog.displayNameForTag)
        .toList();

    final String recipePreview = recipeTitlesOrdered.length <= 2
        ? recipeTitlesOrdered.join(' ve ')
        : '${recipeTitlesOrdered.take(2).join(', ')} (+${recipeTitlesOrdered.length - 2} tarif)';

    final String missingPreview = missingNames.length <= 4
        ? missingNames.join(', ')
        : '${missingNames.take(4).join(', ')} (+${missingNames.length - 4})';

    final String title =
        'Bugünkü menünüzde ${missingNames.length} eksik ürün var';
    final String body =
        '$recipePreview için eksik: $missingPreview. Alışveriş listenize göz atın.';

    return MenuMissingNotificationPayload(
      title: title,
      body: body,
      missingCount: missingNames.length,
      missingNames: missingNames,
      recipeTitles: recipeTitlesOrdered,
    );
  }

  Future<KilerceNotificationSettings> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bool morningEnabled =
          prefs.getBool(_prefMorningMenuEnabled) ?? true;
      final int hour =
          (prefs.getInt(_prefMorningHour) ?? defaultMorningHour).clamp(0, 23);
      final int minute =
          (prefs.getInt(_prefMorningMinute) ?? defaultMorningMinute)
              .clamp(0, 59);
      final bool sktEnabled = await ExpiryReminderService.instance.isEnabled();
      return KilerceNotificationSettings(
        morningMenuEnabled: morningEnabled,
        morningHour: hour,
        morningMinute: minute,
        sktEnabled: sktEnabled,
      );
    } catch (e) {
      debugPrint('KilerceNotificationService.loadSettings error: $e');
      return const KilerceNotificationSettings(
        morningMenuEnabled: true,
        morningHour: defaultMorningHour,
        morningMinute: defaultMorningMinute,
        sktEnabled: true,
      );
    }
  }

  Future<void> setMorningMenuEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefMorningMenuEnabled, enabled);
    } catch (e) {
      debugPrint('KilerceNotificationService.setMorningMenuEnabled error: $e');
    }
  }

  Future<void> setMorningTime(int hour, int minute) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefMorningHour, hour.clamp(0, 23));
      await prefs.setInt(_prefMorningMinute, minute.clamp(0, 59));
    } catch (e) {
      debugPrint('KilerceNotificationService.setMorningTime error: $e');
    }
  }

  Future<bool> areNotificationsEnabled() async {
    try {
      final bool? enabled =
          await _channel.invokeMethod<bool>('areNotificationsEnabled');
      return enabled ?? true;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (e) {
      debugPrint(
        'KilerceNotificationService.areNotificationsEnabled error: $e',
      );
      return false;
    } catch (e) {
      debugPrint(
        'KilerceNotificationService.areNotificationsEnabled error: $e',
      );
      return false;
    }
  }

  Future<bool> requestPermission() async {
    try {
      final bool? granted =
          await _channel.invokeMethod<bool>('requestNotificationPermission');
      return granted ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (e) {
      debugPrint('KilerceNotificationService.requestPermission error: $e');
      return false;
    } catch (e) {
      debugPrint('KilerceNotificationService.requestPermission error: $e');
      return false;
    }
  }

  Future<bool> requestPermissionIfNeededOnce() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bool alreadyAsked =
          prefs.getBool(_prefPermissionAskedOnce) ?? false;
      if (alreadyAsked) {
        return await areNotificationsEnabled();
      }
      await prefs.setBool(_prefPermissionAskedOnce, true);
      return await requestPermission();
    } catch (e) {
      debugPrint(
        'KilerceNotificationService.requestPermissionIfNeededOnce error: $e',
      );
      return false;
    }
  }

  Future<bool> sendTestNotification() async {
    return _showNotification(
      id: testNotificationId,
      channelId: menuChannelId,
      title: 'Kilerce Bildirimleri Aktif',
      body:
          'Bugünkü menünüzde eksik malzeme veya SKT yaklaşan ürün olduğunda sabah haber vereceğiz.',
    );
  }

  Future<bool> openEmailClient({
    required String to,
    required String subject,
    required String body,
  }) async {
    try {
      final bool? opened = await _channel.invokeMethod<bool>(
        'openEmailClient',
        {
          'to': to,
          'subject': subject,
          'body': body,
        },
      );
      return opened ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (e) {
      debugPrint('KilerceNotificationService.openEmailClient error: $e');
      return false;
    } catch (e) {
      debugPrint('KilerceNotificationService.openEmailClient error: $e');
      return false;
    }
  }

  Future<bool> syncMorningMenuReminder({
    List<MealPlanEntry>? entries,
    Map<String, KilerRecipe>? recipeById,
    List<PantryItem>? pantryItems,
    bool allowImmediateTodayAlert = false,
  }) async {
    try {
      final settings = await loadSettings();
      if (!settings.morningMenuEnabled) {
        await _cancelReminder(menuMissingNotificationId);
        return false;
      }

      final DateTime now = _nowProvider();
      final DateTime today = DateTime(now.year, now.month, now.day);
      final String todayIso = MealDateUtils.toIsoDate(today);
      final String tomorrowIso =
          MealDateUtils.toIsoDate(today.add(const Duration(days: 1)));

      final List<MealPlanEntry> effectiveEntries;
      final Map<String, KilerRecipe> effectiveRecipeById;

      if (entries != null && recipeById != null) {
        effectiveEntries = entries;
        effectiveRecipeById = recipeById;
      } else {
        final repo = SqliteMealModuleRepository();
        final loaded = await Future.wait<dynamic>([
          repo.getEntriesForDateRange(todayIso, tomorrowIso),
          repo.getCustomRecipes(),
        ]);
        effectiveEntries = loaded[0] as List<MealPlanEntry>;
        effectiveRecipeById = RecipeRecommendationEngine.buildRecipeIndex(
          customRecipes: loaded[1] as List<KilerRecipe>,
        );
      }

      final List<PantryItem> effectivePantry =
          pantryItems ?? KilerService.instance.value.pantryItems;

      final MorningTriggerWindow window = computeNextMorningTrigger(
        now: now,
        hour: settings.morningHour,
        minute: settings.morningMinute,
      );

      final payload = buildMenuMissingNotificationPayload(
        dateIso: window.targetDateIso,
        entries: effectiveEntries,
        recipeById: effectiveRecipeById,
        pantryItems: effectivePantry,
      );

      bool scheduled = false;
      if (payload != null) {
        scheduled = await _scheduleReminder(
          id: menuMissingNotificationId,
          channelId: menuChannelId,
          title: payload.title,
          body: payload.body,
          triggerAtMillis: window.triggerAt.millisecondsSinceEpoch,
        );
      } else {
        await _cancelReminder(menuMissingNotificationId);
      }

      if (allowImmediateTodayAlert &&
          !window.isToday &&
          now.hour >= 7 &&
          now.hour < 13) {
        final todayPayload = buildMenuMissingNotificationPayload(
          dateIso: todayIso,
          entries: effectiveEntries,
          recipeById: effectiveRecipeById,
          pantryItems: effectivePantry,
        );
        if (todayPayload != null) {
          final prefs = await SharedPreferences.getInstance();
          if (prefs.getString(_prefMenuLastNotifiedDay) != todayIso) {
            final shown = await _showNotification(
              id: menuMissingNotificationId,
              channelId: menuChannelId,
              title: todayPayload.title,
              body: todayPayload.body,
            );
            if (shown) {
              await prefs.setString(_prefMenuLastNotifiedDay, todayIso);
            }
          }
        }
      }

      return scheduled;
    } catch (e) {
      debugPrint('KilerceNotificationService.syncMorningMenuReminder error: $e');
      return false;
    }
  }

  Future<bool> syncExpiryReminder() async {
    try {
      final bool enabled = await ExpiryReminderService.instance.isEnabled();
      final List<PantryItem> expiring =
          KilerService.instance.value.expiringSoonItems;
      if (!enabled || expiring.isEmpty) {
        await cancelExpirySchedule();
        return false;
      }

      final settings = await loadSettings();
      final DateTime now = _nowProvider();
      final int offsetMinutes = settings.morningMinute + 5;
      final int sktHour =
          (settings.morningHour + (offsetMinutes ~/ 60)) % 24;
      final int sktMinute = offsetMinutes % 60;
      final MorningTriggerWindow window = computeNextMorningTrigger(
        now: now,
        hour: sktHour,
        minute: sktMinute,
      );

      final String previewNames =
          expiring.take(3).map((e) => e.name).join(', ');
      final String title = '${expiring.length} ürünün SKT\'si yaklaşıyor';
      final String body =
          '$previewNames için Kilerce kurtarma tariflerine göz atın.';

      return await _scheduleReminder(
        id: expiryNotificationId,
        channelId: sktChannelId,
        title: title,
        body: body,
        triggerAtMillis: window.triggerAt.millisecondsSinceEpoch,
      );
    } catch (e) {
      debugPrint('KilerceNotificationService.syncExpiryReminder error: $e');
      return false;
    }
  }

  Future<void> cancelExpirySchedule() async {
    await _cancelReminder(expiryNotificationId);
  }

  Future<void> syncAllReminders({bool allowImmediateTodayAlert = false}) async {
    await Future.wait([
      syncMorningMenuReminder(
        allowImmediateTodayAlert: allowImmediateTodayAlert,
      ),
      syncExpiryReminder(),
    ]);
  }

  Future<bool> _showNotification({
    required int id,
    required String channelId,
    required String title,
    required String body,
  }) async {
    try {
      final bool? shown = await _channel.invokeMethod<bool>(
        'showNotification',
        {
          'id': id,
          'channelId': channelId,
          'title': title,
          'body': body,
        },
      );
      return shown ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (e) {
      debugPrint('KilerceNotificationService._showNotification error: $e');
      return false;
    } catch (e) {
      debugPrint('KilerceNotificationService._showNotification error: $e');
      return false;
    }
  }

  Future<bool> _scheduleReminder({
    required int id,
    required String channelId,
    required String title,
    required String body,
    required int triggerAtMillis,
  }) async {
    try {
      final bool? scheduled = await _channel.invokeMethod<bool>(
        'scheduleReminder',
        {
          'id': id,
          'channelId': channelId,
          'title': title,
          'body': body,
          'triggerAtMillis': triggerAtMillis,
        },
      );
      return scheduled ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (e) {
      debugPrint('KilerceNotificationService._scheduleReminder error: $e');
      return false;
    } catch (e) {
      debugPrint('KilerceNotificationService._scheduleReminder error: $e');
      return false;
    }
  }

  Future<void> _cancelReminder(int id) async {
    try {
      await _channel.invokeMethod<bool>('cancelReminder', {'id': id});
    } on MissingPluginException {
      // No native platform channel in unit tests.
    } on PlatformException catch (e) {
      debugPrint('KilerceNotificationService._cancelReminder error: $e');
    } catch (e) {
      debugPrint('KilerceNotificationService._cancelReminder error: $e');
    }
  }
}
