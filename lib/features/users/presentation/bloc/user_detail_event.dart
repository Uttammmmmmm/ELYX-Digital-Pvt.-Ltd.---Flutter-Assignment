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
  const UserDetailRequested(this.detailId);

  /// The source-specific detail key, from `UserSummary.detailId`.
  final String detailId;

  @override
  List<Object?> get props => <Object?>[detailId];
}

/// Retry after a failure.
///
/// Carries no id: the bloc already holds the seed, so the caller cannot pass
/// a mismatched one. Distinct from [UserDetailRequested] so the intent
/// reads correctly at the call site and so the two can diverge later
/// (a retry might, say, want to bypass the cache).
final class UserDetailRetried extends UserDetailEvent {
  const UserDetailRetried();
}
