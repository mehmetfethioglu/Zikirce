import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'badge_definitions.dart';

class PresetAvatar {
  final String id;
  final String label;
  final String emoji;

  const PresetAvatar({
    required this.id,
    required this.label,
    required this.emoji,
  });
}

class UserLevelInfo {
  final int level;
  final String title;
  final int currentXp;
  final int nextLevelXp;
  final double progress;

  const UserLevelInfo({
    required this.level,
    required this.title,
    required this.currentXp,
    required this.nextLevelXp,
    required this.progress,
  });
}

class UserProfile {
  final String displayName;
  final String? avatarPath;
  final String presetAvatarId;
  final int totalScans;
  final int totalContributions;
  final int totalBoycottReports;
  final int healthyChoices;
  final int xp;
  final Set<String> unlockedBadgeIds;
  final int? lastBackupTimestamp;
  final String? googleEmail;
  final String? googleDisplayName;
  final String? googlePhotoUrl;

  bool get isGoogleConnected => googleEmail != null && googleEmail!.isNotEmpty;

  const UserProfile({
    required this.displayName,
    this.avatarPath,
    required this.presetAvatarId,
    required this.totalScans,
    required this.totalContributions,
    required this.totalBoycottReports,
    required this.healthyChoices,
    required this.xp,
    required this.unlockedBadgeIds,
    this.lastBackupTimestamp,
    this.googleEmail,
    this.googleDisplayName,
    this.googlePhotoUrl,
  });

  UserProfile copyWith({
    String? displayName,
    String? avatarPath,
    String? presetAvatarId,
    int? totalScans,
    int? totalContributions,
    int? totalBoycottReports,
    int? healthyChoices,
    int? xp,
    Set<String>? unlockedBadgeIds,
    int? lastBackupTimestamp,
    String? googleEmail,
    String? googleDisplayName,
    String? googlePhotoUrl,
    bool clearGoogleAccount = false,
  }) {
    return UserProfile(
      displayName: displayName ?? this.displayName,
      avatarPath: avatarPath ?? this.avatarPath,
      presetAvatarId: presetAvatarId ?? this.presetAvatarId,
      totalScans: totalScans ?? this.totalScans,
      totalContributions: totalContributions ?? this.totalContributions,
      totalBoycottReports: totalBoycottReports ?? this.totalBoycottReports,
      healthyChoices: healthyChoices ?? this.healthyChoices,
      xp: xp ?? this.xp,
      unlockedBadgeIds: unlockedBadgeIds ?? this.unlockedBadgeIds,
      lastBackupTimestamp: lastBackupTimestamp ?? this.lastBackupTimestamp,
      googleEmail: clearGoogleAccount ? null : (googleEmail ?? this.googleEmail),
      googleDisplayName: clearGoogleAccount ? null : (googleDisplayName ?? this.googleDisplayName),
      googlePhotoUrl: clearGoogleAccount ? null : (googlePhotoUrl ?? this.googlePhotoUrl),
    );
  }

  Map<String, dynamic> toJson() => {
        'displayName': displayName,
        'avatarPath': avatarPath,
        'presetAvatarId': presetAvatarId,
        'totalScans': totalScans,
        'totalContributions': totalContributions,
        'totalBoycottReports': totalBoycottReports,
        'healthyChoices': healthyChoices,
        'xp': xp,
        'unlockedBadgeIds': unlockedBadgeIds.toList(),
        'lastBackupTimestamp': lastBackupTimestamp ?? DateTime.now().millisecondsSinceEpoch,
        'googleEmail': googleEmail,
        'googleDisplayName': googleDisplayName,
        'googlePhotoUrl': googlePhotoUrl,
        'schema_version': 2,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      displayName: json['displayName'] as String? ?? 'Bilinçli Tüketici',
      avatarPath: json['avatarPath'] as String?,
      presetAvatarId: json['presetAvatarId'] as String? ?? 'leaf',
      totalScans: (json['totalScans'] as int?) ?? 0,
      totalContributions: (json['totalContributions'] as int?) ?? 0,
      totalBoycottReports: (json['totalBoycottReports'] as int?) ?? 0,
      healthyChoices: (json['healthyChoices'] as int?) ?? 0,
      xp: (json['xp'] as int?) ?? 0,
      unlockedBadgeIds: (json['unlockedBadgeIds'] as List<dynamic>?)?.map((e) => e.toString()).toSet() ?? {},
      lastBackupTimestamp: json['lastBackupTimestamp'] as int?,
      googleEmail: json['googleEmail'] as String?,
      googleDisplayName: json['googleDisplayName'] as String?,
      googlePhotoUrl: json['googlePhotoUrl'] as String?,
    );
  }
}

class UserProfileService extends ChangeNotifier {
  static final UserProfileService instance = UserProfileService._internal();
  UserProfileService._internal();

  static const List<PresetAvatar> presetAvatars = [
    PresetAvatar(id: 'leaf', label: 'Doğa Dostu', emoji: '🌿'),
    PresetAvatar(id: 'avocado', label: 'Sağlık Gurmesi', emoji: '🥑'),
    PresetAvatar(id: 'shield', label: 'Etik Muhafız', emoji: '🛡️'),
    PresetAvatar(id: 'detective', label: 'Gıda Dedektifi', emoji: '🔍'),
    PresetAvatar(id: 'chef', label: 'Organik Şef', emoji: '👨‍🍳'),
    PresetAvatar(id: 'star', label: 'Bilinçli Tüketici', emoji: '⭐'),
    PresetAvatar(id: 'apple', label: 'Temiz Gıda', emoji: '🍎'),
    PresetAvatar(id: 'seedling', label: 'Çevre Öncüsü', emoji: '🌱'),
  ];

  static const String _keyName = 'org_user_display_name';
  static const String _keyAvatarPath = 'org_user_avatar_path';
  static const String _keyPresetId = 'org_user_preset_id';
  static const String _keyScans = 'org_user_total_scans';
  static const String _keyContribs = 'org_user_total_contribs';
  static const String _keyBoycotts = 'org_user_total_boycotts';
  static const String _keyHealthy = 'org_user_healthy_choices';
  static const String _keyXp = 'org_user_xp';
  static const String _keyBadges = 'org_user_badges';
  static const String _keyLastBackup = 'org_user_last_backup';
  static const String _keyGoogleEmail = 'org_user_google_email';
  static const String _keyGoogleDisplayName = 'org_user_google_display_name';
  static const String _keyGooglePhotoUrl = 'org_user_google_photo_url';

  UserProfile _profile = const UserProfile(
    displayName: 'Bilinçli Tüketici',
    presetAvatarId: 'leaf',
    totalScans: 0,
    totalContributions: 0,
    totalBoycottReports: 0,
    healthyChoices: 0,
    xp: 0,
    unlockedBadgeIds: {},
  );

  UserProfile get profile => _profile;

  /// Returns user's level, level title and progress to next level
  UserLevelInfo get levelInfo {
    final xp = _profile.xp;
    if (xp < 100) {
      return UserLevelInfo(
        level: 1,
        title: 'Çaylak Tüketici',
        currentXp: xp,
        nextLevelXp: 100,
        progress: (xp / 100).clamp(0.0, 1.0),
      );
    } else if (xp < 250) {
      return UserLevelInfo(
        level: 2,
        title: 'Bilinçli Kaşif',
        currentXp: xp - 100,
        nextLevelXp: 150,
        progress: ((xp - 100) / 150).clamp(0.0, 1.0),
      );
    } else if (xp < 500) {
      return UserLevelInfo(
        level: 3,
        title: 'Gıda Dedektifi',
        currentXp: xp - 250,
        nextLevelXp: 250,
        progress: ((xp - 250) / 250).clamp(0.0, 1.0),
      );
    } else if (xp < 1000) {
      return UserLevelInfo(
        level: 4,
        title: 'Etik Muhafız',
        currentXp: xp - 500,
        nextLevelXp: 500,
        progress: ((xp - 500) / 500).clamp(0.0, 1.0),
      );
    } else {
      return UserLevelInfo(
        level: 5,
        title: 'Organik Lideri',
        currentXp: xp - 1000,
        nextLevelXp: 1000,
        progress: 1.0,
      );
    }
  }

  /// Initial load from local SharedPreferences
  Future<void> loadProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString(_keyName) ?? 'Bilinçli Tüketici';
      final avatarPath = prefs.getString(_keyAvatarPath);
      final presetId = prefs.getString(_keyPresetId) ?? 'leaf';
      final scans = prefs.getInt(_keyScans) ?? 0;
      final contribs = prefs.getInt(_keyContribs) ?? 0;
      final boycotts = prefs.getInt(_keyBoycotts) ?? 0;
      final healthy = prefs.getInt(_keyHealthy) ?? 0;
      final xp = prefs.getInt(_keyXp) ?? 0;
      final lastBackup = prefs.getInt(_keyLastBackup);
      final googleEmail = prefs.getString(_keyGoogleEmail);
      final googleDisplayName = prefs.getString(_keyGoogleDisplayName);
      final googlePhotoUrl = prefs.getString(_keyGooglePhotoUrl);

      final badgesJson = prefs.getString(_keyBadges);
      final Set<String> badges = {};
      if (badgesJson != null) {
        final List<dynamic> decoded = jsonDecode(badgesJson);
        badges.addAll(decoded.map((e) => e.toString()));
      }

      _profile = UserProfile(
        displayName: name,
        avatarPath: avatarPath,
        presetAvatarId: presetId,
        totalScans: scans,
        totalContributions: contribs,
        totalBoycottReports: boycotts,
        healthyChoices: healthy,
        xp: xp,
        unlockedBadgeIds: badges,
        lastBackupTimestamp: lastBackup,
        googleEmail: googleEmail,
        googleDisplayName: googleDisplayName,
        googlePhotoUrl: googlePhotoUrl,
      );

      // Verify and auto-unlock any badges met by previous state
      _checkBadgeUnlocks();
      notifyListeners();
    } catch (e) {
      debugPrint('UserProfileService.loadProfile error: $e');
    }
  }

  /// Sets Google Account details and persists them locally
  Future<void> setGoogleAccountInfo({
    required String email,
    String? displayName,
    String? photoUrl,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyGoogleEmail, email);
    if (displayName != null && displayName.isNotEmpty) {
      await prefs.setString(_keyGoogleDisplayName, displayName);
    } else {
      await prefs.remove(_keyGoogleDisplayName);
    }
    if (photoUrl != null && photoUrl.isNotEmpty) {
      await prefs.setString(_keyGooglePhotoUrl, photoUrl);
    } else {
      await prefs.remove(_keyGooglePhotoUrl);
    }

    // If local name is default, adopt Google display name
    String newDisplayName = _profile.displayName;
    if ((newDisplayName == 'Bilinçli Tüketici' || newDisplayName.isEmpty) &&
        displayName != null &&
        displayName.isNotEmpty) {
      newDisplayName = displayName;
      await prefs.setString(_keyName, newDisplayName);
    }

    _profile = _profile.copyWith(
      displayName: newDisplayName,
      googleEmail: email,
      googleDisplayName: displayName,
      googlePhotoUrl: photoUrl,
    );
    notifyListeners();
  }

  /// Disconnects Google account while strictly preserving all local progress and badges
  Future<void> clearGoogleAccount() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyGoogleEmail);
    await prefs.remove(_keyGoogleDisplayName);
    await prefs.remove(_keyGooglePhotoUrl);

    _profile = _profile.copyWith(clearGoogleAccount: true);
    notifyListeners();
  }

  /// Updates last backup timestamp and persists it
  Future<void> updateLastBackupTimestamp(int timestamp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLastBackup, timestamp);
    _profile = _profile.copyWith(lastBackupTimestamp: timestamp);
    notifyListeners();
  }

  Future<void> updateDisplayName(String name) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return;

    _profile = _profile.copyWith(displayName: cleanName);
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyName, cleanName);
  }

  Future<void> updateAvatar({String? customImagePath, String? presetAvatarId}) async {
    _profile = _profile.copyWith(
      avatarPath: customImagePath,
      presetAvatarId: presetAvatarId ?? _profile.presetAvatarId,
    );
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    if (customImagePath != null) {
      await prefs.setString(_keyAvatarPath, customImagePath);
    } else {
      await prefs.remove(_keyAvatarPath);
    }
    if (presetAvatarId != null) {
      await prefs.setString(_keyPresetId, presetAvatarId);
    }
  }

  static const String _keyRecentScansJson = 'recent_scanned_barcodes_v2';
  static const int _scanCooldownMinutes = 120; // 2 hours cooldown per barcode to prevent badge/XP farming

  /// Triggered after a real barcode or OCR scan.
  /// Protects gamification integrity: duplicate scans of the same barcode within cooldown do not grant XP or increment scan count.
  /// Returns true if XP & scan count were awarded, false if ignored due to cooldown.
  Future<bool> recordScan({String? barcode, bool isHealthy = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;

    if (barcode != null && barcode.isNotEmpty) {
      // Load recent scans map: {barcode: timestamp_ms}
      Map<String, dynamic> recentScans = {};
      final raw = prefs.getString(_keyRecentScansJson);
      if (raw != null) {
        try {
          recentScans = jsonDecode(raw) as Map<String, dynamic>;
        } catch (e) {
          debugPrint('UserProfileService recentScans decode error: $e');
        }
      }

      // Check if this barcode was scanned recently
      final lastScanTime = recentScans[barcode] as int?;
      if (lastScanTime != null) {
        final elapsedMinutes = (now - lastScanTime) / (1000 * 60);
        if (elapsedMinutes < _scanCooldownMinutes) {
          // Already scanned within cooldown; do not award XP or increment count to prevent badge farming
          return false;
        }
      }

      // Update recent scans timestamp (clean up entries older than 24 hours)
      recentScans[barcode] = now;
      recentScans.removeWhere((key, value) {
        if (value is int) {
          return (now - value) > (24 * 60 * 60 * 1000);
        }
        return true;
      });
      await prefs.setString(_keyRecentScansJson, jsonEncode(recentScans));
    }

    final newScans = _profile.totalScans + 1;
    final newHealthy = isHealthy ? _profile.healthyChoices + 1 : _profile.healthyChoices;
    final gainedXp = isHealthy ? 15 : 10;
    final newXp = _profile.xp + gainedXp;

    _profile = _profile.copyWith(
      totalScans: newScans,
      healthyChoices: newHealthy,
      xp: newXp,
    );

    _checkBadgeUnlocks();
    notifyListeners();
    _persistStats();
    return true;
  }

  /// Triggered after a crowdsourced contribution (new barcode/label upload)
  Future<void> recordContribution() async {
    final newContribs = _profile.totalContributions + 1;
    final newXp = _profile.xp + 50;

    _profile = _profile.copyWith(
      totalContributions: newContribs,
      xp: newXp,
    );

    _checkBadgeUnlocks();
    notifyListeners();
    _persistStats();
  }

  /// Triggered after a boycott review, dispute, or report
  Future<void> recordBoycottReport() async {
    final newBoycotts = _profile.totalBoycottReports + 1;
    final newXp = _profile.xp + 35;

    _profile = _profile.copyWith(
      totalBoycottReports: newBoycotts,
      xp: newXp,
    );

    _checkBadgeUnlocks();
    notifyListeners();
    _persistStats();
  }

  /// Evaluates unlock conditions for all badges and grants reward XP
  void _checkBadgeUnlocks() {
    final currentBadges = Set<String>.from(_profile.unlockedBadgeIds);
    int extraXp = 0;

    for (final badge in BadgeDefinitions.allBadges) {
      if (currentBadges.contains(badge.id)) continue;

      bool shouldUnlock = false;
      switch (badge.category) {
        case BadgeCategory.scanner:
          shouldUnlock = _profile.totalScans >= badge.targetCount;
          break;
        case BadgeCategory.crowdsource:
          shouldUnlock = _profile.totalContributions >= badge.targetCount;
          break;
        case BadgeCategory.boycott:
          shouldUnlock = _profile.totalBoycottReports >= badge.targetCount;
          break;
        case BadgeCategory.health:
          shouldUnlock = _profile.healthyChoices >= badge.targetCount;
          break;
      }

      if (shouldUnlock) {
        currentBadges.add(badge.id);
        extraXp += badge.xpReward;
      }
    }

    if (currentBadges.length != _profile.unlockedBadgeIds.length) {
      _profile = _profile.copyWith(
        unlockedBadgeIds: currentBadges,
        xp: _profile.xp + extraXp,
      );
    }
  }

  Future<void> _persistStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyScans, _profile.totalScans);
      await prefs.setInt(_keyContribs, _profile.totalContributions);
      await prefs.setInt(_keyBoycotts, _profile.totalBoycottReports);
      await prefs.setInt(_keyHealthy, _profile.healthyChoices);
      await prefs.setInt(_keyXp, _profile.xp);
      await prefs.setString(_keyBadges, jsonEncode(_profile.unlockedBadgeIds.toList()));
    } catch (e) {
      debugPrint('UserProfileService._persistStats error: $e');
    }
  }

  /// Export profile and stats to clean JSON string for Google Drive backup
  String exportBackupJson() {
    final now = DateTime.now().millisecondsSinceEpoch;
    _profile = _profile.copyWith(lastBackupTimestamp: now);
    SharedPreferences.getInstance().then((prefs) => prefs.setInt(_keyLastBackup, now));
    notifyListeners();

    return jsonEncode({
      'app': 'OrganicScore',
      'version': '1.0.0',
      'created_at': now,
      'profile': _profile.toJson(),
    });
  }

  /// Import profile and stats from a Google Drive JSON backup string
  Future<bool> importBackupJson(String jsonString) async {
    try {
      final Map<String, dynamic> data = jsonDecode(jsonString);
      final profileData = data['profile'] as Map<String, dynamic>? ?? data;

      _profile = UserProfile.fromJson(profileData);
      _checkBadgeUnlocks();
      notifyListeners();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyName, _profile.displayName);
      if (_profile.avatarPath != null) {
        await prefs.setString(_keyAvatarPath, _profile.avatarPath!);
      }
      await prefs.setString(_keyPresetId, _profile.presetAvatarId);
      await _persistStats();
      if (_profile.lastBackupTimestamp != null) {
        await prefs.setInt(_keyLastBackup, _profile.lastBackupTimestamp!);
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('UserProfileService import error: $e');
      }
      return false;
    }
  }
}
