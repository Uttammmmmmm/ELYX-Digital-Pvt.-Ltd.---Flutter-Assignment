/// A value plus where it came from.
library;

import 'package:equatable/equatable.dart';

/// Where a successfully-returned value was obtained.
enum DataOrigin {
  /// Fetched live from GitHub.
  network,

  /// Read from the local Hive cache.
  cache,
}

/// Wraps a result with its provenance.
///
/// WHY: "the request succeeded" and "the data is current" are different facts.
/// When the device is offline, or the rate limit is spent, the repository
/// serves cached data rather than an error screen -- but the UI must then say
/// "showing saved data from 20 minutes ago" instead of presenting it as live.
/// Folding that into `Either<Failure, T>` would lose it; a separate nullable
/// flag on every state would let callers forget it. Making it part of the
/// success type means they cannot.
class Sourced<T> extends Equatable {
  const Sourced._(this.value, this.origin, this.cachedAt);

  /// A live result.
  const Sourced.network(T value) : this._(value, DataOrigin.network, null);

  /// A cached result, stamped with when it was written.
  const Sourced.cache(T value, DateTime cachedAt)
      : this._(value, DataOrigin.cache, cachedAt);

  /// The payload.
  final T value;

  /// Network or cache.
  final DataOrigin origin;

  /// When the cached copy was written; null for [DataOrigin.network].
  final DateTime? cachedAt;

  /// True when the payload came off disk.
  bool get isFromCache => origin == DataOrigin.cache;

  /// Transforms the payload, preserving provenance.
  Sourced<R> map<R>(R Function(T value) transform) =>
      Sourced<R>._(transform(value), origin, cachedAt);

  @override
  List<Object?> get props => <Object?>[value, origin, cachedAt];
}
