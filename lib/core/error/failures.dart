/// Domain-layer failures.
///
/// WHY THIS EXISTS SEPARATELY FROM [AppException]:
/// Exceptions are control flow -- they are thrown, they unwind the stack, and
/// nothing in the type system forces you to handle them. Failures are *values*
/// returned inside `Either<Failure, T>`, so the compiler makes handling them
/// mandatory and every use case's error surface is visible in its signature.
/// The second reason is dependency direction: exceptions are transport
/// concerns, and the domain layer must stay ignorant of Dio, HTTP and Hive.
library;

import 'package:equatable/equatable.dart';

import 'exceptions.dart';

/// Base type for anything the domain can fail with.
///
/// `sealed` so Blocs can switch exhaustively over failure kinds and the
/// compiler flags any state that forgets one.
sealed class Failure extends Equatable {
  const Failure(this.message);

  /// User-facing, already-localisable copy. Safe to render directly.
  final String message;

  @override
  List<Object?> get props => <Object?>[message];
}

/// The server responded, but not successfully (typically 5xx).
final class ServerFailure extends Failure {
  const ServerFailure([
    super.message = 'GitHub is having trouble right now. Please try again.',
  ]);
}

/// The device could not reach the network at all.
final class NetworkFailure extends Failure {
  const NetworkFailure([
    super.message = 'You appear to be offline. Check your connection.',
  ]);
}

/// The request exceeded a connect/send/receive timeout.
final class TimeoutFailure extends Failure {
  const TimeoutFailure([
    super.message = 'The request took too long. Please try again.',
  ]);
}

/// The GitHub rate limit is exhausted.
///
/// Exposes [resetAt] so the UI can render a countdown and disable Retry until
/// the quota actually returns -- offering a button guaranteed to fail is worse
/// than offering none. Constraint (d).
final class RateLimitFailure extends Failure {
  const RateLimitFailure({
    required this.resetAt,
    this.isSecondary = false,
    String message =
        'GitHub API rate limit reached. Unauthenticated '
        'requests are capped at 60 per hour.',
  }) : super(message);

  /// When the quota is restored.
  final DateTime resetAt;

  /// Secondary (abuse) limit rather than the primary hourly window.
  final bool isSecondary;

  /// Time left until reset, relative to [now]; never negative.
  Duration remainingFrom(DateTime now) {
    final Duration d = resetAt.difference(now);
    return d.isNegative ? Duration.zero : d;
  }

  @override
  List<Object?> get props => <Object?>[message, resetAt, isSecondary];
}

/// The requested resource does not exist.
final class NotFoundFailure extends Failure {
  const NotFoundFailure([
    super.message = 'That user could not be found on GitHub.',
  ]);
}

/// A use case rejected its own arguments before any I/O happened.
///
/// Not every failure comes from the network. Guarding at the use-case
/// boundary means a malformed request never reaches the repository, never
/// spends one of 60 hourly requests, and never depends on the server to
/// reject it.
final class ValidationFailure extends Failure {
  const ValidationFailure([super.message = 'That request is not valid.']);
}

/// Reading or writing the local cache failed, or nothing was cached.
final class CacheFailure extends Failure {
  const CacheFailure([super.message = 'No saved data available offline.']);
}

/// Translates a data-layer [AppException] into a domain [Failure].
///
/// Lives here rather than in each repository so the mapping exists exactly
/// once. The switch is exhaustive over the sealed [AppException] hierarchy, so
/// adding an exception without a failure will not compile.
Failure failureFromException(AppException exception) => switch (exception) {
  RateLimitException(:final DateTime resetAt, :final bool isSecondary) =>
    RateLimitFailure(resetAt: resetAt, isSecondary: isSecondary),
  NotFoundException() => const NotFoundFailure(),
  NetworkException() => const NetworkFailure(),
  TimeoutException() => const TimeoutFailure(),
  CacheException() => const CacheFailure(),
  ServerException() => const ServerFailure(),
};
