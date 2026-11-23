import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/pdks/domain/pdks_models.dart';

@immutable
class SavedLoginPreferences {
  final bool rememberUsername;
  final String username;
  final UserRole role;

  const SavedLoginPreferences({
    this.rememberUsername = true,
    this.username = '',
    this.role = UserRole.admin,
  });
}

/// Cihaz bazlı giriş ekranı tercihlerini (`Kullanıcı adını hatırla` ve son kullanıcı adı/rol)
/// `SharedPreferences` içinde güvenle saklar; parola asla saklanmaz.
class LoginPreferencesService {
  static const String _kRememberUsername = 'hasibu_login_remember_username_v1';
  static const String _kSavedUsername = 'hasibu_login_saved_username_v1';
  static const String _kSavedRole = 'hasibu_login_saved_role_v1';

  const LoginPreferencesService();

  Future<SavedLoginPreferences> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final remember = prefs.getBool(_kRememberUsername) ?? true;
      final username = (prefs.getString(_kSavedUsername) ?? '').trim();
      final roleRaw = (prefs.getString(_kSavedRole) ?? '').trim();
      final role = roleRaw == UserRole.employee.name
          ? UserRole.employee
          : UserRole.admin;
      return SavedLoginPreferences(
        rememberUsername: remember,
        username: remember ? username : '',
        role: role,
      );
    } catch (e) {
      debugPrint('LoginPreferencesService: load uyarısı: $e');
      return const SavedLoginPreferences();
    }
  }

  Future<void> save({
    required bool rememberUsername,
    required String username,
    required UserRole role,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kRememberUsername, rememberUsername);
      final cleanUsername = username.trim();
      if (rememberUsername && cleanUsername.isNotEmpty) {
        await prefs.setString(_kSavedUsername, cleanUsername);
        await prefs.setString(_kSavedRole, role.name);
      } else {
        await prefs.remove(_kSavedUsername);
        await prefs.remove(_kSavedRole);
      }
    } catch (e) {
      debugPrint('LoginPreferencesService: save uyarısı: $e');
    }
  }
}
