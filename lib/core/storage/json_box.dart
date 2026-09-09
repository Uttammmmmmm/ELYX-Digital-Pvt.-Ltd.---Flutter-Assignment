/// A JSON-over-Hive key/value store.
library;

import 'dart:convert';

import 'package:hive/hive.dart';

import '../error/exceptions.dart';
import 'cache_entry.dart';

/// Thin wrapper over a `Box<String>` that stores JSON with a cache timestamp.
///
/// WHY NO TypeAdapters: `hive_generator` is unusable on this SDK (it pins
/// `analyzer <7.0.0`, which cannot coexist with `bloc_test`). More importantly,
/// the models already carry `toJson`/`fromJson` for Dio, so a generated adapter
/// would be a *second*, independently-maintained serialization path for the
/// same objects. One encoding, one place to get wrong.
///
/// Every read degrades to null rather than throwing: a cache that has been
/// corrupted, or written by an older app version, must never crash the app.
class JsonBox {
  const JsonBox(this._box);

  final Box<String> _box;

  static const String _kCachedAt = 'cachedAt';
  static const String _kPayload = 'payload';

  /// Writes [payload] under [key], stamping it with the current time.
  ///
  /// Throws [CacheException] -- a failed *write* is worth surfacing, unlike a
  /// failed read, because it means offline support is silently broken.
  Future<void> write(String key, Object? payload, {DateTime? now}) async {
    try {
      await _box.put(
        key,
        jsonEncode(<String, dynamic>{
          _kCachedAt: (now ?? DateTime.now()).toIso8601String(),
          _kPayload: payload,
        }),
      );
    } catch (e) {
      throw CacheException('Failed to write cache key "$key": $e');
    }
  }

  /// Reads [key], or null when absent, unparseable or written in an old shape.
  CacheEntry<Object?>? read(String key) {
    final String? raw = _box.get(key);
    if (raw == null) return null;

    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;

      final DateTime? cachedAt =
          DateTime.tryParse(decoded[_kCachedAt] as String? ?? '');
      if (cachedAt == null) return null;

      return CacheEntry<Object?>(
        value: decoded[_kPayload],
        cachedAt: cachedAt,
      );
    } catch (_) {
      // Corrupt entry: treat as a cache miss rather than a crash.
      return null;
    }
  }

  /// All keys currently present.
  Iterable<String> get keys => _box.keys.cast<String>();

  /// Removes a single entry.
  Future<void> delete(String key) => _box.delete(key);

  /// Empties the box (used by pull-to-refresh on the list).
  Future<void> clear() => _box.clear();
}
