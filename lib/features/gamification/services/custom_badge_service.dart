import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/badge_models.dart';

class CustomBadgeService {
  static const String customBadgesKey = 'CustomQuranBadgesJson';

  static String _getKey([String? sessionId]) {
    if (sessionId != null && sessionId.isNotEmpty && sessionId != 'default_user') {
      return '${customBadgesKey}_$sessionId';
    }
    return customBadgesKey;
  }

  static Future<List<CustomQuranBadge>> getCustomBadges([String? sessionId]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getKey(sessionId);
      final jsonStr = prefs.getString(key) ?? (sessionId == 'default_user' || sessionId == null ? prefs.getString(customBadgesKey) ?? '[]' : '[]');
      if (jsonStr.trim().isEmpty) return [];

      final List<dynamic> decoded = jsonDecode(jsonStr);
      return decoded.map((item) => CustomQuranBadge.fromJson(item as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('[CustomBadgeService] getCustomBadges Error: $e');
      return [];
    }
  }

  static Future<void> saveCustomBadge(CustomQuranBadge badge, [String? sessionId]) async {
    try {
      final badges = await getCustomBadges(sessionId);
      final idx = badges.indexWhere((b) => b.id == badge.id);
      if (idx >= 0) {
        badges[idx] = badge;
      } else {
        badges.add(badge);
      }

      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(badges.map((b) => b.toJson()).toList());
      await prefs.setString(_getKey(sessionId), jsonStr);
    } catch (e) {
      debugPrint('[CustomBadgeService] saveCustomBadge Error: $e');
    }
  }

  static Future<void> deleteCustomBadge(String badgeId, [String? sessionId]) async {
    try {
      final badges = await getCustomBadges(sessionId);
      badges.removeWhere((b) => b.id == badgeId);

      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(badges.map((b) => b.toJson()).toList());
      await prefs.setString(_getKey(sessionId), jsonStr);
    } catch (e) {
      debugPrint('[CustomBadgeService] deleteCustomBadge Error: $e');
    }
  }

  static Future<void> onSurahRead(int surahNumber, [String? sessionId]) async {
    try {
      final badges = await getCustomBadges(sessionId);
      bool modified = false;
      final now = DateTime.now();
      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final yesterday = now.subtract(const Duration(days: 1));
      final yesterdayStr = '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

      for (final b in badges) {
        if (b.scope == 'Surah' && (b.scopeValue == surahNumber.toString() || b.scopeValue == 'All')) {
          if (b.lastReadDate == todayStr) continue; // Already counted today

          if (b.lastReadDate.isNotEmpty && b.lastReadDate == yesterdayStr) {
            b.currentStreak++;
          } else {
            b.currentStreak = 1;
          }

          b.lastReadDate = todayStr;
          if (b.currentStreak > b.bestStreak) {
            b.bestStreak = b.currentStreak;
          }

          if (b.currentStreak >= b.targetDays && !b.isUnlocked) {
            b.isUnlocked = true;
            b.unlockedDate = DateTime.now();
          }

          modified = true;
        }
      }

      if (modified) {
        final prefs = await SharedPreferences.getInstance();
        final jsonStr = jsonEncode(badges.map((b) => b.toJson()).toList());
        await prefs.setString(_getKey(sessionId), jsonStr);
      }
    } catch (e) {
      debugPrint('[CustomBadgeService] onSurahRead Error: $e');
    }
  }
}
