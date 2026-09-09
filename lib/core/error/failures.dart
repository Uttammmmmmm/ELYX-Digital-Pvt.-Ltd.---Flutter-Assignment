library;

import 'package:equatable/equatable.dart';

import 'exceptions.dart';

sealed class Failure extends Equatable {
  const Failure(this.message);

  final String message;

  @override
  List<Object?> get props => <Object?>[message];
}

final class ServerFailure extends Failure {
  const ServerFailure([
    super.message = 'GitHub is having trouble right now. Please try again.',
  ]);
}

final class NetworkFailure extends Failure {
  const NetworkFailure([
    super.message = 'You appear to be offline. Check your connection.',
  ]);
}

final class TimeoutFailure extends Failure {
  const TimeoutFailure([
    super.message = 'The request took too long. Please try again.',
  ]);
}

final class RateLimitFailure extends Failure {
  const RateLimitFailure({
    required this.resetAt,
    this.isSecondary = false,
    String message =
        'GitHub API rate limit reached. Unauthenticated '
        'requests are capped at 60 per hour.',
  }) : super(message);

  final DateTime resetAt;

  final bool isSecondary;

  Duration remainingFrom(DateTime now) {
    final Duration d = resetAt.difference(now);
    return d.isNegative ? Duration.zero : d;
  }

  @override
  List<Object?> get props => <Object?>[message, resetAt, isSecondary];
}

final class NotFoundFailure extends Failure {
  const NotFoundFailure([
    super.message = 'That user could not be found on GitHub.',
  ]);
}

final class ValidationFailure extends Failure {
  const ValidationFailure([super.message = 'That request is not valid.']);
}

final class CacheFailure extends Failure {
  const CacheFailure([super.message = 'No saved data available offline.']);
}

Failure failureFromException(AppException exception) => switch (exception) {
  RateLimitException(:final DateTime resetAt, :final bool isSecondary) =>
    RateLimitFailure(resetAt: resetAt, isSecondary: isSecondary),
  NotFoundException() => const NotFoundFailure(),
  NetworkException() => const NetworkFailure(),
  TimeoutException() => const TimeoutFailure(),
  CacheException() => const CacheFailure(),
  ServerException() => const ServerFailure(),
};
