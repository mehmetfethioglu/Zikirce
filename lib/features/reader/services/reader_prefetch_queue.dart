import 'dart:async';

import 'package:flutter/foundation.dart';

/// Priority page prefetch scheduler for `[P, P+1, P+2, P+3, P-1]`.
/// Rapidly jumping to a new page increments [_generation] so stale queued
/// pages cancel immediately without blocking the UI or wasted I/O.
class ReaderPrefetchQueue {
  final Future<void> Function(int pageNumber) loadPage;
  int _generation = 0;
  bool _disposed = false;
  bool _isRunning = false;

  ReaderPrefetchQueue({
    required this.loadPage,
  });

  /// Current active queue generation (useful for observability & testing).
  int get generation => _generation;

  /// Computes deterministic priority order `[P, P+1, P+2, P+3, P-1]` clamped to `[1, totalPages]`.
  static List<int> buildPriorityOrder({
    required int activePage,
    required int totalPages,
  }) {
    if (totalPages <= 0) return const [];
    final safeActive = activePage.clamp(1, totalPages);
    final candidates = <int>[
      safeActive,
      safeActive + 1,
      safeActive + 2,
      safeActive + 3,
      safeActive - 1,
    ];
    final ordered = <int>[];
    for (final p in candidates) {
      if (p >= 1 && p <= totalPages && !ordered.contains(p)) {
        ordered.add(p);
      }
    }
    return ordered;
  }

  /// Cancels any older prefetch generation and schedules background preparation
  /// for `[activePage + 1, activePage + 2, activePage + 3, activePage - 1]`.
  Future<void> prioritizeNeighbors({
    required int activePage,
    required int totalPages,
    bool includeActivePage = false,
  }) async {
    if (_disposed || totalPages <= 0) return;
    final token = ++_generation;
    final allPages = buildPriorityOrder(
      activePage: activePage,
      totalPages: totalPages,
    );
    final targetPages =
        includeActivePage ? allPages : allPages.skip(1).toList(growable: false);
    if (targetPages.isEmpty) return;

    _isRunning = true;
    try {
      for (final page in targetPages) {
        if (_disposed || token != _generation) {
          return;
        }
        try {
          await loadPage(page);
        } catch (e) {
          debugPrint('ReaderPrefetchQueue page $page warning: $e');
        }
        // Yield a microtask between background pages so active navigation wins cleanly
        await Future<void>.delayed(Duration.zero);
      }
    } finally {
      if (token == _generation) {
        _isRunning = false;
      }
    }
  }

  /// True while a prefetch generation is actively draining.
  bool get isRunning => _isRunning;

  /// Invalidates all pending prefetch work on notifier dispose.
  void dispose() {
    _disposed = true;
    _generation++;
  }
}
