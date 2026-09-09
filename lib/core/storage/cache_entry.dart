/// Cached value plus the timestamp that decides its freshness.
library;

/// A cached payload and when it was written.
///
/// Freshness and *usability* are deliberately separate questions. A stale entry
/// is still perfectly renderable, and serving it beside a "showing saved data"
/// banner beats an error screen -- especially when the alternative is blocked
/// by a rate limit. Only [isStale] is time-based; nothing here ever deletes.
class CacheEntry<T> {
  const CacheEntry({required this.value, required this.cachedAt});

  /// The decoded payload.
  final T value;

  /// When the payload was written to disk.
  final DateTime cachedAt;

  /// True once [cachedAt] is older than [ttl].
  bool isStale(Duration ttl, {DateTime? now}) =>
      (now ?? DateTime.now()).difference(cachedAt) > ttl;

  /// Age of the entry, for "updated 5 minutes ago" copy.
  Duration ageFrom(DateTime now) {
    final Duration d = now.difference(cachedAt);
    return d.isNegative ? Duration.zero : d;
  }

  /// Returns a copy with a different payload, keeping the original timestamp.
  CacheEntry<R> map<R>(R Function(T value) transform) =>
      CacheEntry<R>(value: transform(value), cachedAt: cachedAt);
}
