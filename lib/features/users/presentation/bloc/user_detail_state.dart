/// State held by [UserDetailBloc].
library;

import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/user_detail.dart';

/// Detail-screen state.
///
/// WHY SEALED HERE BUT FLAT FOR THE LIST: this screen shows one object with
/// no incremental accumulation, so the states are genuinely mutually
/// exclusive and there is no partial data to carry across a transition.
/// Sealed subclasses make the UI's `switch` exhaustive.
sealed class UserDetailState extends Equatable {
  const UserDetailState();

  @override
  List<Object?> get props => const <Object?>[];
}

/// Nothing requested yet.
final class UserDetailInitial extends UserDetailState {
  const UserDetailInitial();
}

/// A load is in flight.
final class UserDetailLoading extends UserDetailState {
  const UserDetailLoading();
}

/// The profile is available.
final class UserDetailLoaded extends UserDetailState {
  const UserDetailLoaded(this.detail);

  /// The profile.
  final UserDetail detail;

  @override
  List<Object?> get props => <Object?>[detail];
}

/// The load failed and there is nothing to show.
final class UserDetailError extends UserDetailState {
  const UserDetailError(this.failure);

  /// What went wrong. `RateLimitFailure` carries the reset time.
  final Failure failure;

  /// The rate-limit failure, when that is what went wrong. Constraint (d).
  RateLimitFailure? get rateLimitFailure {
    final Failure f = failure;
    return f is RateLimitFailure ? f : null;
  }

  @override
  List<Object?> get props => <Object?>[failure];
}
