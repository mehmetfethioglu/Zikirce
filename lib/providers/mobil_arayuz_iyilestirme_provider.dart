import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/pdks/domain/pdks_models.dart';

/// Mobil arayüz kart yoğunluğu seçeneği
enum MobileDensityMode {
  comfortable('Ferah Görünüm'),
  compact('Kompakt Liste');

  final String label;
  const MobileDensityMode(this.label);
}

/// Mobil arayüz için özel durum modeli
@immutable
class MobileUiState {
  final MobileDensityMode densityMode;
  final bool showKpiBanner;
  final bool showQuickActions;
  final int mobileTabIndex;
  final DailyAttendanceState? activeQuickFilter;
  final String quickSearchQuery;
  final bool isRefreshing;
  final int refreshCount;

  const MobileUiState({
    this.densityMode = MobileDensityMode.comfortable,
    this.showKpiBanner = true,
    this.showQuickActions = true,
    this.mobileTabIndex = 0,
    this.activeQuickFilter,
    this.quickSearchQuery = '',
    this.isRefreshing = false,
    this.refreshCount = 0,
  });

  bool get isCompact => densityMode == MobileDensityMode.compact;

  MobileUiState copyWith({
    MobileDensityMode? densityMode,
    bool? showKpiBanner,
    bool? showQuickActions,
    int? mobileTabIndex,
    DailyAttendanceState? activeQuickFilter,
    bool clearQuickFilter = false,
    String? quickSearchQuery,
    bool? isRefreshing,
    int? refreshCount,
  }) {
    return MobileUiState(
      densityMode: densityMode ?? this.densityMode,
      showKpiBanner: showKpiBanner ?? this.showKpiBanner,
      showQuickActions: showQuickActions ?? this.showQuickActions,
      mobileTabIndex: mobileTabIndex ?? this.mobileTabIndex,
      activeQuickFilter:
          clearQuickFilter ? null : (activeQuickFilter ?? this.activeQuickFilter),
      quickSearchQuery: quickSearchQuery ?? this.quickSearchQuery,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      refreshCount: refreshCount ?? this.refreshCount,
    );
  }
}

/// Mobil arayüz durum yöneticisi
class MobileUiNotifier extends StateNotifier<MobileUiState> {
  MobileUiNotifier() : super(const MobileUiState());

  void setDensityMode(MobileDensityMode mode) {
    state = state.copyWith(densityMode: mode);
  }

  void toggleDensityMode() {
    final nextMode = state.densityMode == MobileDensityMode.comfortable
        ? MobileDensityMode.compact
        : MobileDensityMode.comfortable;
    state = state.copyWith(densityMode: nextMode);
  }

  void toggleKpiBanner() {
    state = state.copyWith(showKpiBanner: !state.showKpiBanner);
  }

  void setMobileTab(int index) {
    state = state.copyWith(mobileTabIndex: index);
  }

  void setQuickFilter(DailyAttendanceState? filter) {
    if (state.activeQuickFilter == filter) {
      state = state.copyWith(clearQuickFilter: true);
    } else {
      state = state.copyWith(activeQuickFilter: filter);
    }
  }

  void setQuickSearchQuery(String query) {
    state = state.copyWith(quickSearchQuery: query);
  }

  void clearSearch() {
    state = state.copyWith(quickSearchQuery: '');
  }

  Future<void> triggerMobileRefresh({
    Future<void> Function()? onRefreshCallback,
  }) async {
    state = state.copyWith(isRefreshing: true);
    try {
      if (onRefreshCallback != null) {
        await onRefreshCallback();
      }
      state = state.copyWith(
        isRefreshing: false,
        refreshCount: state.refreshCount + 1,
      );
    } catch (_) {
      state = state.copyWith(isRefreshing: false);
    }
  }
}

final mobileUiProvider =
    StateNotifierProvider<MobileUiNotifier, MobileUiState>((ref) {
  return MobileUiNotifier();
});
