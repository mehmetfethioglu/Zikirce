import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/session/session_providers.dart';
import '../../../../core/session/user_session.dart';

class QuickAccessCardsState {
  final Set<String> pinnedIds;
  final Set<String> hiddenIds;

  const QuickAccessCardsState({
    this.pinnedIds = const {},
    this.hiddenIds = const {},
  });

  bool isPinned(String id) => pinnedIds.contains(id);
  bool isHidden(String id) => hiddenIds.contains(id);

  QuickAccessCardsState copyWith({
    Set<String>? pinnedIds,
    Set<String>? hiddenIds,
  }) {
    return QuickAccessCardsState(
      pinnedIds: pinnedIds ?? this.pinnedIds,
      hiddenIds: hiddenIds ?? this.hiddenIds,
    );
  }
}

class QuickAccessCardsNotifier extends StateNotifier<QuickAccessCardsState> {
  final Ref _ref;
  static const String _pinnedBaseKey = 'QuickAccessPinnedCards';
  static const String _hiddenBaseKey = 'QuickAccessHiddenCards';

  QuickAccessCardsNotifier(this._ref) : super(const QuickAccessCardsState()) {
    _loadState();
  }

  String _getPinnedKey() {
    final session = _ref.read(activeSessionProvider);
    final isDefault = session.id == UserSession.defaultSessionId;
    return isDefault ? _pinnedBaseKey : '${_pinnedBaseKey}_${session.id}';
  }

  String _getHiddenKey() {
    final session = _ref.read(activeSessionProvider);
    final isDefault = session.id == UserSession.defaultSessionId;
    return isDefault ? _hiddenBaseKey : '${_hiddenBaseKey}_${session.id}';
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final pinnedList = prefs.getStringList(_getPinnedKey()) ?? [];
    final hiddenList = prefs.getStringList(_getHiddenKey()) ?? [];

    state = QuickAccessCardsState(
      pinnedIds: pinnedList.toSet(),
      hiddenIds: hiddenList.toSet(),
    );
  }

  Future<void> togglePin(String cardId) async {
    final current = Set<String>.from(state.pinnedIds);
    if (current.contains(cardId)) {
      current.remove(cardId);
    } else {
      current.add(cardId);
    }

    state = state.copyWith(pinnedIds: current);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_getPinnedKey(), current.toList());
  }

  Future<void> hideCard(String cardId) async {
    final currentHidden = Set<String>.from(state.hiddenIds)..add(cardId);
    final currentPinned = Set<String>.from(state.pinnedIds)..remove(cardId);

    state = state.copyWith(hiddenIds: currentHidden, pinnedIds: currentPinned);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_getHiddenKey(), currentHidden.toList());
    await prefs.setStringList(_getPinnedKey(), currentPinned.toList());
  }

  Future<void> showCard(String cardId) async {
    final currentHidden = Set<String>.from(state.hiddenIds)..remove(cardId);

    state = state.copyWith(hiddenIds: currentHidden);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_getHiddenKey(), currentHidden.toList());
  }

  Future<void> resetToDefault() async {
    state = const QuickAccessCardsState();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_getPinnedKey());
    await prefs.remove(_getHiddenKey());
  }
}

final quickAccessCardsProvider =
    StateNotifierProvider<QuickAccessCardsNotifier, QuickAccessCardsState>((ref) {
  ref.watch(activeSessionProvider);
  return QuickAccessCardsNotifier(ref);
});
