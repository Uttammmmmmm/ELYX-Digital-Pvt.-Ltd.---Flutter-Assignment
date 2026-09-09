/// Live view of GitHub's rate-limit budget.
library;

import 'package:flutter/foundation.dart';

/// A snapshot of the `x-ratelimit-*` headers from the most recent response.
@immutable
class RateLimitSnapshot {
  const RateLimitSnapshot({
    required this.remaining,
    required this.limit,
    required this.resetAt,
    required this.observedAt,
  });

  /// Requests left in the current window.
  final int remaining;

  /// Window ceiling: 60 unauthenticated, 5000 with a token.
  final int limit;

  /// When the window reopens.
  final DateTime resetAt;

  /// When these values were read off the wire.
  final DateTime observedAt;

  /// True once the budget is spent.
  bool get isExhausted => remaining <= 0;

  /// True when few enough requests remain to warn the user proactively.
  bool get isNearlyExhausted => remaining > 0 && remaining <= 5;
}

/// Injectable, mutable holder for the latest [RateLimitSnapshot].
///
/// Registered as a lazy singleton in get_it and written by
/// `RateLimitInterceptor` on *every* response -- successful ones included --
/// so the UI can warn before the quota is gone rather than only after.
/// Extends [ChangeNotifier] so a widget can listen without pulling in Bloc.
class RateLimitTracker extends ChangeNotifier {
  RateLimitSnapshot? _snapshot;

  /// Latest observed values, or null before the first response.
  RateLimitSnapshot? get snapshot => _snapshot;

  /// True only when we have observed an exhausted budget.
  bool get isExhausted => _snapshot?.isExhausted ?? false;

  /// Records a new observation and notifies listeners.
  void update(RateLimitSnapshot snapshot) {
    _snapshot = snapshot;
    notifyListeners();
  }

  /// Clears state (used between tests and on sign-out).
  void reset() {
    _snapshot = null;
    notifyListeners();
  }
}
