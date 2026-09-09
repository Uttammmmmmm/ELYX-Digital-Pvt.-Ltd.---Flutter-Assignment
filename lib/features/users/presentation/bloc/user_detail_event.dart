/// Events accepted by [UserDetailBloc].
library;

import 'package:equatable/equatable.dart';

/// Base type for detail-screen events.
sealed class UserDetailEvent extends Equatable {
  const UserDetailEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// Load the profile for [login], cache-first.
final class UserDetailRequested extends UserDetailEvent {
  const UserDetailRequested(this.login);

  /// The handle to fetch. The detail endpoint keys on login, not numeric id.
  final String login;

  @override
  List<Object?> get props => <Object?>[login];
}

/// Retry after a failure.
///
/// Carries no login: the bloc already holds the seed, so the caller cannot
/// pass a mismatched one. Distinct from [UserDetailRequested] so the intent
/// reads correctly at the call site and so the two can diverge later
/// (a retry might, say, want to bypass the cache).
final class UserDetailRetried extends UserDetailEvent {
  const UserDetailRetried();
}
