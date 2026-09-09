/// The use-case contract shared by every domain interactor.
library;

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../error/failures.dart';

/// A single unit of application behaviour: `Params` in, `Either` out.
///
/// Returning `Either<Failure, T>` rather than throwing makes every error
/// path part of the signature, so a Bloc cannot forget to handle one.
/// Declaring `call` means use cases are invoked as `await getUsers(params)`.
abstract interface class UseCase<T, Params> {
  Future<Either<Failure, T>> call(Params params);
}

/// A synchronous use case -- pure logic with no I/O (e.g. client-side search).
///
/// Kept separate so callers are not forced to `await` a computation that never
/// suspends, and so it can be tested without an async harness. Constraint (e).
abstract interface class SyncUseCase<T, Params> {
  T call(Params params);
}

/// Placeholder for use cases that take no arguments.
class NoParams extends Equatable {
  const NoParams();

  @override
  List<Object?> get props => const <Object?>[];
}
