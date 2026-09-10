library;

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../error/failures.dart';

abstract interface class UseCase<T, Params> {
  Future<Either<Failure, T>> call(Params params);
}

abstract interface class SyncUseCase<T, Params> {
  T call(Params params);
}

/// A use case that cannot fail.
///
/// Reserved for reads that degrade to an empty result instead of an error.
/// Wrapping those in [Either] would force every call site to handle a [Left]
/// that is never constructed, which reads as caution but is really noise.
abstract interface class InfallibleUseCase<T, Params> {
  Future<T> call(Params params);
}

class NoParams extends Equatable {
  const NoParams();

  @override
  List<Object?> get props => const <Object?>[];
}
