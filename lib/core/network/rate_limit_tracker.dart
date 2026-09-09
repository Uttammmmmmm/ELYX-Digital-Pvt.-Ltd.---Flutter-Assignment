library;

import 'package:flutter/foundation.dart';

@immutable
class RateLimitSnapshot {
  const RateLimitSnapshot({
    required this.remaining,
    required this.limit,
    required this.resetAt,
    required this.observedAt,
  });

  final int remaining;

  final int limit;

  final DateTime resetAt;

  final DateTime observedAt;

  bool get isExhausted => remaining <= 0;

  bool get isNearlyExhausted => remaining > 0 && remaining <= 5;
}

class RateLimitTracker extends ChangeNotifier {
  RateLimitSnapshot? _snapshot;

  RateLimitSnapshot? get snapshot => _snapshot;

  bool get isExhausted => _snapshot?.isExhausted ?? false;

  void update(RateLimitSnapshot snapshot) {
    _snapshot = snapshot;
    notifyListeners();
  }

  void reset() {
    _snapshot = null;
    notifyListeners();
  }
}
