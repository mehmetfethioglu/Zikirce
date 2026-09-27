import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/session/session_providers.dart';
import '../../../../core/session/user_session.dart';

class TilavetSecdesiDebtNotifier extends StateNotifier<int> {
  final Ref _ref;
  static const String _baseKey = 'TilavetSecdesiDebt';

  TilavetSecdesiDebtNotifier(this._ref) : super(0) {
    _loadDebt();
  }

  String _getKey() {
    final session = _ref.read(activeSessionProvider);
    final isDefault = session.id == UserSession.defaultSessionId;
    return isDefault ? _baseKey : '${_baseKey}_${session.id}';
  }

  Future<void> _loadDebt() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getKey();
    final saved = prefs.getInt(key) ?? 0;
    state = saved.clamp(0, 9999);
  }

  Future<void> reload() async {
    await _loadDebt();
  }

  Future<void> incrementDebt([int count = 1]) async {
    if (count <= 0) return;
    final updated = (state + count).clamp(0, 9999);
    state = updated;
    await _persist(updated);
  }

  Future<void> decrementDebt([int count = 1]) async {
    if (count <= 0) return;
    final updated = (state - count).clamp(0, 9999);
    state = updated;
    await _persist(updated);
  }

  Future<void> setDebt(int count) async {
    final updated = count.clamp(0, 9999);
    state = updated;
    await _persist(updated);
  }

  Future<void> resetDebt() async {
    state = 0;
    await _persist(0);
  }

  Future<void> _persist(int value) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getKey();
    await prefs.setInt(key, value);

    // If default session, also update base key
    final session = _ref.read(activeSessionProvider);
    if (session.id == UserSession.defaultSessionId) {
      await prefs.setInt(_baseKey, value);
    }
  }
}

final tilavetSecdesiDebtProvider =
    StateNotifierProvider<TilavetSecdesiDebtNotifier, int>((ref) {
  // Re-instantiate or reload when active session changes
  ref.watch(activeSessionProvider);
  return TilavetSecdesiDebtNotifier(ref);
});
